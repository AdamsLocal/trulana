# Contributing to Trulana

## Where the project stands

Trulana is a working macOS MVP with two verified transports:

- **REST** — 38 verification checks passing (`scripts/demo_client.sh`)
- **MCP** — 18 verification checks passing (`scripts/test_mcp.sh`)
- **134 unit + integration tests** passing (`flutter test`)

The full auth → token → vault query → redact → response → audit log loop works end-to-end on both transports. The three items below are the documented gaps between the current MVP and a production-ready release.

## What to work on next

These are ordered by impact. Each one maps directly to a "Current Limits" entry in the README.

### 1. Scope enforcement at query time

**Why it matters:** Agents request scopes (e.g. `context.read`) during auth, and scopes are stored in the token and database. But `ContextQueryService.queryContext()` never checks whether the token's granted scopes authorize the specific query. Any valid token can query any vault context. The redaction engine still runs, so data is never returned unfiltered — but the policy layer can't distinguish a `context.read` token from a `health.read` token.

**Where to start:**
- `lib/core/services/context_query_service.dart` — add scope checking after token validation (around line 73)
- `lib/core/network/token_manager.dart` — `AccessToken` already stores `scopes`; use them
- `lib/features/engine/context_vault.dart` — vault entries may need scope tags so queries can be matched to required scopes
- Add tests in `test/security/` or `test/integration/` to verify that a token with `health.read` scope cannot query finance context

### 2. MCP per-agent rate limiting

**Why it matters:** The REST transport enforces a sliding-window rate limit (60 req/min per agent) via shelf middleware. The MCP transport has no rate limiting at all because rate limiting lives in the HTTP middleware layer, not in the shared service layer. A local process using MCP could issue unlimited queries.

**Where to start:**
- Extract rate limiting logic from `lib/core/network/middleware/rate_limiter.dart` into a shared service in `lib/core/services/`
- Call the shared rate limiter from both `lib/core/network/routes/context_routes.dart` (REST) and `lib/mcp/mcp_server.dart` (MCP)
- Add tests in `test/security/` to verify rate limiting applies to MCP queries

### 3. Wire monetization approval/denial buttons

**Why it matters:** The dashboard shows pending lease requests and the backend logs them, but the two action buttons in the UI are stubbed out.

**Where to start:**
- `lib/features/dashboard/widgets/monetization_card.dart` — the Approve/Deny buttons have TODO comments
- Wire the "Approve" button to accept the lease and record it in the Ledger table
- Wire the "Deny" button to reject the lease and log the denial in the Audit Log
- Add tests to verify the approve/deny flow updates the database correctly

## Future work (not blocking MVP)

These are larger efforts that build on top of the MVP:

- **Replace the mock NER processor** with an on-device quantized model (Llama 3 8B / Gemma 3 via llama.cpp or MLC LLM). The current `NerProcessor` in `lib/features/engine/stages/ner_processor.dart` is a deterministic mock with a swappable interface ready for this.
- **Replace keyword vault with vector search.** The `ContextVault` in `lib/features/engine/context_vault.dart` uses hardcoded keyword matching. Production should use ObjectBox Vector Search or Chroma/Milvus Lite for semantic context retrieval.
- **Web3 / Stripe payment settlement.** The `Ledger` table and `lease_offer` endpoint exist but there's no on-chain settlement (Solana/USDC) or Stripe Connect integration yet.
- **MCP caller identity verification.** Currently any local process can start an MCP session by invoking the binary with `TRULANA_MCP=1`. Consider adding cryptographic verification of the calling process identity.

## Development setup

```bash
git clone https://github.com/AdamsLocal/trulana.git
cd trulana
flutter pub get
flutter test                    # run all 134 tests
flutter test --reporter expanded  # verbose output
```

## Running the verification gates

```bash
# Terminal 1: start the app (launches REST server on :8432)
flutter run -d macos

# Terminal 2: REST verification (38 checks)
./scripts/demo_client.sh

# MCP verification (18 checks) — build release first
flutter build macos --release
./scripts/test_mcp.sh
```

## Code conventions

- **Zero PII logging.** Never use `print()` or `debugPrint()` with user context, prompts, or database queries. Use `SafeLogger` from `lib/core/logging/safe_logger.dart`.
- **Strong typing.** Always declare return types. Do not use `dynamic` unless parsing unknown JSON, and cast immediately.
- **Business logic stays out of widgets.** UI widgets consume state and dispatch events. Logic lives in services and providers.
- **Document the why, not the what.** Use `///` for class and method docs.
- See `.cursorrules` for the full style guide.

## Test structure

```
test/
├── engine/              # 89 tests — Auto-Redact pipeline (regex, NER, privacy filter, full pipeline, vault)
├── security/            # 11 tests — log hygiene, auth consistency across transports
├── integration/         # 31 tests — full service loop E2E + preference model (auth → query → redact → audit)
└── widget_test.dart     # 3 tests — model round-trip smoke tests
```

When adding a new feature, add tests in the matching directory. Engine changes go in `test/engine/`, auth/security changes go in `test/security/`, and end-to-end flows go in `test/integration/`.
