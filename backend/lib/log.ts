// Structured server logs, in the one shape Vercel Runtime Logs can work with:
// a single JSON object per `console.*` call. The whole line lands in the
// `message` field, which is what the Logs tab's free-text search matches — so
// `systemone` in the search box finds every line this writes.

type Level = "info" | "error";

/**
 * One structured line. `error` goes to stderr because Vercel derives its
 * Error level from the stream, not from anything inside the payload — that's
 * what makes failed calls filterable without a text search.
 */
export function logEvent(level: Level, event: string, data: Record<string, unknown>): void {
  const line = JSON.stringify({
    level: level.toUpperCase(),
    event,
    timestamp: new Date().toISOString(),
    ...data,
  });

  if (level === "error") console.error(line);
  else console.log(line);
}
