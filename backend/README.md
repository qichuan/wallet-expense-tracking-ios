# CardPulse Category API

A single-endpoint Next.js service that decides which spending category a new transaction
belongs to. The CardPulse iOS app calls it from `WalletTransactionIntent` when a Wallet
tap-to-pay is logged, sending the merchant name plus the user's own category list; the
service asks [TypeSafe Jev](https://docs.typesafe.ai) a `choice` question and returns the
selected category with a calibrated confidence.

The app treats this service as optional. If it is unreachable, unconfigured, or unsure, the
app falls back to matching against past transactions and a local keyword heuristic.

## Why a server at all

The TypeSafe API key must never ship inside an iOS binary. Keeping the call server-side also
means the prompt can be improved without releasing a new app version.

## Setup

Requires Node 20+.

```bash
npm install
cp .env.example .env.local   # then fill in the two required values
npm run dev
```

| Variable | Required | Purpose |
| --- | --- | --- |
| `TYPESAFE_API_KEY` | yes | Credential for the TypeSafe API. Never leaves the server. |
| `CATEGORIZE_API_TOKEN` | yes | Shared bearer token the iOS app must present. Generate with `openssl rand -hex 32`. |
| `TYPESAFE_MODEL` | no | Model override. Defaults to `jev-latest`. |

If either required variable is missing the endpoint returns `500 server_misconfigured` rather
than serving unauthenticated traffic.

## Endpoint

### `POST /api/categorize`

Header: `Authorization: Bearer <CATEGORIZE_API_TOKEN>`

```jsonc
{
  "merchant": "NTUC FAIRPRICE",              // required, max 200 chars
  "categories": [                             // required, 1-100 entries, deduped case-insensitively, names up to 120 chars
    { "name": "Food & Drinks", "hint": "food restaurant dining" },
    { "name": "Shopping", "hint": "shopping bag" },
    { "name": "Other" }                       // hint is optional
  ],
  "amount": 24.8,                             // optional
  "currency": "SGD",                          // optional
  "cardName": "Amex Platinum"                 // optional
}
```

`hint` describes what belongs in a category. The iOS app derives it from the category's SF
Symbol, which is what lets user-created custom categories be classified as well as built-ins.

Response:

```json
{
  "category": "Food & Drinks",
  "confidence": 0.93,
  "probabilities": { "Food & Drinks": 0.91, "Shopping": 0.06, "Other": 0.03 },
  "model": "jev-1.13.0"
}
```

`category` is always one of the names that were sent, echoed back with the client's own
spelling. The threshold policy lives in the app, not here — the raw confidence is passed
through so the client can decide whether to trust it.

| Status | Body | Meaning |
| --- | --- | --- |
| 200 | judgment | OK |
| 400 | `invalid_request` + `detail` | Malformed body |
| 401 | `unauthorized` | Missing or wrong bearer token |
| 405 | `method_not_allowed` | Anything other than POST |
| 500 | `server_misconfigured` | A required environment variable is unset |
| 502 | `upstream` | TypeSafe call failed or timed out |

### Try it

```bash
curl -s localhost:3000/api/categorize \
  -H 'Authorization: Bearer dev-token' \
  -H 'Content-Type: application/json' \
  -d '{
    "merchant": "NTUC FAIRPRICE",
    "currency": "SGD",
    "amount": 24.8,
    "categories": [
      { "name": "Food & Drinks", "hint": "food restaurant dining" },
      { "name": "Shopping", "hint": "shopping bag" },
      { "name": "Other" }
    ]
  }' | jq
```

## Deploying to Vercel

```bash
npm i -g vercel
vercel            # set the project's Root Directory to `backend`
vercel --prod
```

Then, in the Vercel project settings:

1. Add `TYPESAFE_API_KEY` and `CATEGORIZE_API_TOKEN` as Environment Variables for Production
   (and Preview, if you use preview deployments).
2. Enable a Firewall rate-limit rule on `/api/categorize`. The bearer token is the first line
   of defence, but it ships inside the app binary and is therefore extractable — a rate limit
   is what actually caps the damage. No in-process limiter is included here because
   serverless instances don't share memory, so per-instance counters can't be relied on.

Finally, point the iOS app at the deployment by putting the **host only** (no `https://`) in
`Config/Secrets.xcconfig` at the repo root, along with the same bearer token. See the root
`README.md` for details.
