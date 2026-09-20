import { createHash, timingSafeEqual } from "node:crypto";
import { NextResponse } from "next/server";
import {
  APIError,
  TypeSafeClient,
  type ChoiceCriteria,
  type ChoiceResponse,
} from "@typesafe-ai/sdk";
import { logEvent } from "@/lib/log";

// The TypeSafe SDK requires Node 20+; the edge runtime has no node:crypto.
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** Upper bounds that keep a malformed or hostile request cheap to reject. */
const MAX_MERCHANT_LENGTH = 200;
const MAX_CATEGORIES = 100;
const MAX_CATEGORY_NAME_LENGTH = 120;
const MAX_HINT_LENGTH = 200;

/** Per-attempt budget. The iOS client gives up after 4s, so retrying here would be wasted work. */
const JEV_TIMEOUT_MS = 6_000;

/** A candidate category after validation: the hint is normalised to a string or `null`. */
interface CategoryInput {
  name: string;
  hint: string | null;
}

interface CategorizeRequest {
  merchant: string;
  categories: CategoryInput[];
  amount?: number | null;
  currency?: string | null;
  cardName?: string | null;
}

function jsonError(status: number, error: string, detail?: string) {
  return NextResponse.json(detail ? { error, detail } : { error }, { status });
}

/**
 * Constant-time comparison of two secrets. Both sides are hashed first so that
 * unequal lengths don't throw and don't leak the expected length via timing.
 */
function secretsMatch(provided: string, expected: string): boolean {
  const a = createHash("sha256").update(provided).digest();
  const b = createHash("sha256").update(expected).digest();
  return timingSafeEqual(a, b);
}

function parseBody(raw: unknown): CategorizeRequest | string {
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return "body must be a JSON object";
  }
  const body = raw as Record<string, unknown>;

  const merchant = typeof body.merchant === "string" ? body.merchant.trim() : "";
  if (!merchant) return "`merchant` is required and must be a non-empty string";
  if (merchant.length > MAX_MERCHANT_LENGTH) {
    return `\`merchant\` must be at most ${MAX_MERCHANT_LENGTH} characters`;
  }

  if (!Array.isArray(body.categories)) return "`categories` is required and must be an array";
  if (body.categories.length > MAX_CATEGORIES) {
    return `\`categories\` must contain at most ${MAX_CATEGORIES} entries`;
  }

  // Dedupe case-insensitively, keeping the first spelling the client sent — that
  // spelling is what we echo back, and the client matches it against its own records.
  const seen = new Set<string>();
  const categories: CategoryInput[] = [];
  for (const entry of body.categories) {
    if (typeof entry !== "object" || entry === null) {
      return "each entry in `categories` must be an object with a `name`";
    }
    const { name, hint } = entry as Record<string, unknown>;
    if (typeof name !== "string" || !name.trim()) {
      return "each entry in `categories` must have a non-empty `name`";
    }
    const trimmed = name.trim();
    if (trimmed.length > MAX_CATEGORY_NAME_LENGTH) {
      return `category names must be at most ${MAX_CATEGORY_NAME_LENGTH} characters`;
    }
    const key = trimmed.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    categories.push({
      name: trimmed,
      hint: typeof hint === "string" && hint.trim() ? hint.trim().slice(0, MAX_HINT_LENGTH) : null,
    });
  }
  if (categories.length === 0) return "`categories` must contain at least one named category";

  const amount = typeof body.amount === "number" && Number.isFinite(body.amount) ? body.amount : null;
  const currency = typeof body.currency === "string" && body.currency.trim() ? body.currency.trim() : null;
  const cardName = typeof body.cardName === "string" && body.cardName.trim() ? body.cardName.trim() : null;

  return { merchant, categories, amount, currency, cardName };
}

export async function POST(request: Request) {
  const apiKey = process.env.TYPESAFE_API_KEY;
  const sharedToken = process.env.CATEGORIZE_API_TOKEN;
  if (!apiKey || !sharedToken) {
    // Fail loudly rather than silently serving an unauthenticated endpoint.
    console.error(
      "Missing required environment variables: TYPESAFE_API_KEY and CATEGORIZE_API_TOKEN must both be set.",
    );
    return jsonError(500, "server_misconfigured");
  }

  const authHeader = request.headers.get("authorization") ?? "";
  const presented = authHeader.startsWith("Bearer ") ? authHeader.slice(7).trim() : "";
  if (!presented || !secretsMatch(presented, sharedToken)) {
    return jsonError(401, "unauthorized");
  }

  let raw: unknown;
  try {
    raw = await request.json();
  } catch {
    return jsonError(400, "invalid_request", "body must be valid JSON");
  }

  const parsed = parseBody(raw);
  if (typeof parsed === "string") {
    return jsonError(400, "invalid_request", parsed);
  }
  const { merchant, categories, amount, currency, cardName } = parsed;

  const client = new TypeSafeClient({
    apiKey,
    defaultModel: process.env.TYPESAFE_MODEL || undefined,
    timeout: JEV_TIMEOUT_MS,
    retry: { maxRetries: 0 },
  });

  // Labels are the user's own category names; the hint (derived from the
  // category's SF Symbol on the client) describes what belongs in each one.
  const criteria: ChoiceCriteria = Object.fromEntries(
    categories.map((c) => [c.name, c.hint]),
  );

  // Named so the same object can be logged and sent — what we record is
  // literally what went over the wire, not a reconstruction of it.
  const systemOneRequest = {
    state: {
      transaction: {
        merchant_name: merchant,
        ...(amount !== null ? { amount } : {}),
        ...(currency !== null ? { currency } : {}),
        ...(cardName !== null ? { card_name: cardName } : {}),
      },
    },
    questions: {
      category: {
        type: "choice",
        instructions: [
          "A card payment was made at the merchant named in `transaction.merchant_name`.",
          "Which of the user's spending categories does this purchase belong to?",
          "Judge by what the merchant sells, not by how much was spent.",
          'Pick a catch-all category such as "Other" only when no other category plausibly fits.',
        ].join(" "),
        criteria,
      },
    },
  } as const;

  // Logged before the call, so a request that hangs or times out still leaves
  // its params behind.
  logEvent("info", "systemone.request", { params: systemOneRequest });

  const startedAt = Date.now();

  try {
    // `.withResponse()` for the `x-typesafe-request-id` header — the one thing
    // TypeSafe support can look a call up by. It still rejects with `APIError`
    // on a non-2xx, so the catch below is unchanged.
    const { data, requestId } = await client.systemOne(systemOneRequest).withResponse();
    const { answers, model, usage } = data;

    logEvent("info", "systemone.response", {
      requestId,
      durationMs: Date.now() - startedAt,
      model,
      usage,
      result: data,
    });

    const answer = answers.category as ChoiceResponse;
    return NextResponse.json({
      category: answer.choice,
      confidence: answer.confidence,
      probabilities: answer.probabilities,
      model,
    });
  } catch (error) {
    // Field by field, never the error object: `APIError` carries a `Headers`
    // instance, and the rule that `TYPESAFE_API_KEY` never reaches a log is
    // easier to keep by naming what goes in than by trusting what doesn't.
    logEvent("error", "systemone.error", {
      durationMs: Date.now() - startedAt,
      params: systemOneRequest,
      errorType: error instanceof Error ? error.constructor.name : typeof error,
      errorMessage: error instanceof Error ? error.message : String(error),
      status: error instanceof APIError ? error.status : undefined,
      requestId: error instanceof APIError ? error.requestId : undefined,
      body: error instanceof APIError ? error.body : undefined,
    });
    // Never forward upstream bodies or credentials to the caller.
    return jsonError(502, "upstream");
  }
}

export async function GET() {
  return jsonError(405, "method_not_allowed", "use POST");
}
