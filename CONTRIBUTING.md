# Contributing to Trulana

## Where the project stands

Trulana is a working macOS Desktop MVP with two verified transports:

- **REST** — verification gate at `scripts/demo_client.sh`
- **MCP** — verification gate at `scripts/test_mcp.sh`

The full request → approval → token → vault query → redact → response → audit log loop works end-to-end on both transports. The current public binary is **v1.2.1** (Developer ID signed, notarized, stapled, Gatekeeper accepted).

## What to work on next

These are ordered by impact. Each one maps to a "Current limits" entry in the README.

### 1. MCP per-agent rate limiting

**Why it matters:** The REST transport enforces a sliding-window rate limit (60 req/min per agent) via shelf middleware. The MCP transport has no rate limiting because rate limiting lives in the HTTP middleware layer, not in the shared service layer. A local process using MCP could issue unlimited queries.

**Where to start:**
- Extract rate-limiting logic from `lib/core/network/middleware/rate_limiter.dart` into a shared service under `lib/core/services/`
- Call the shared rate limiter from both `lib/core/network/routes/context_routes.dart` (REST) and `lib/mcp/mcp_server.dart` (MCP)
- Add tests in `test/security/` verifying rate limiting applies to MCP queries

### 2. Replace mock NER with on-device LLM

**Why it matters:** `NerProcessor` in `lib/features/engine/stages/ner_processor.dart` is a deterministic keyword-matching mock. The interface is swap-ready, but real coverage of names/locations/orgs needs a small on-device model.

**Where to start:**
- Pick a small on-device runtime (llama.cpp / MLC LLM / Apple MLX)
- Implement a new `NerProcessor` subclass behind the existing interface
- Keep the mock as a fallback for tests

### 3. Tamper-evident audit log

**Why it matters:** The audit table is encrypted-at-rest in the SQLCipher database, but rows have no hash chain or external attestation. An attacker with the DB key could modify rows undetected.

**Where to start:**
- Add a `prev_hash` column to `audit_log` and chain entries on insert
- Add a verification routine that walks the chain and reports the first break
- Document the residual risk (an attacker who can also rewrite the verification routine can still hide modifications without external attestation)

### 4. Automate signing + notarization in CI

**Why it matters:** Release signing is currently manual. CI builds the bundle but does not codesign, notarize, or staple. This is a release-hygiene gap.

**Where to start:**
- Extend `.github/workflows/ci.yml` with a release job gated on a tag push
- Use `codesign --timestamp --options runtime`, `xcrun notarytool submit --wait`, `xcrun stapler staple`
- Store the Developer ID and notarytool credentials in GitHub Actions secrets

## Future work

These are larger efforts that build on top of the MVP:

- **Replace keyword vault with vector search.** `ContextVault` uses hardcoded keyword matching. Production should use a local vector store.
- **Finish the experimental Context-as-a-Service escrow.** `ZkCommitmentEngine`, `WatermarkEngine`, and the `/api/v1/monetize/settle` route exist but the escrow is not functional end-to-end. To make it real and production-defensible:
  - Persist the commitment (`offer_id → {hash, salt}`) when `/monetize/lease_offer` is called, and look it up on `/monetize/settle` so `verifyProof` can actually validate the originally-issued hash. Today `settle` regenerates a fresh salt and can never match.
  - Enforce the `monetize.write` scope on `/monetize/settle` (it currently checks only token presence, unlike `lease_offer`).
  - Replace the `bountyToken.startsWith('caas_tk_')` placeholder with real settlement-token validation.
  - Add an end-to-end route test (`test/integration/`) covering offer → settle → verify, not just the engines in isolation.
  - Add real payment settlement (Stripe Connect and/or on-chain); the `Ledger` table records offers but no value moves yet.
- **MCP caller identity verification.** Currently any local process can start an MCP session by invoking the binary with `TRULANA_MCP=1`. Consider cryptographic verification of caller identity.
- **Other platforms.** macOS is the only current public binary. Windows, Linux, iOS, Android are not shipped.

## Development setup

```bash
git clone https://github.com/AdamsLocal/trulana.git
cd trulana
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Riverpod / json_serializable code
flutter test
```

> The `dart run build_runner build` step is required: several providers and models use code generation (`@riverpod`, `json_serializable`) and reference generated `*.g.dart` part files that are not committed. Skipping it will produce missing-part analyzer errors.

## Running the verification gates

```bash
# Terminal 1: start the app (launches REST server on :8432)
flutter run -d macos

# Terminal 2: REST verification
./scripts/demo_client.sh

# MCP verification — build release first
flutter build macos --release
./scripts/test_mcp.sh
```

## Code conventions

- **Zero PII logging.** Never use `print()` or `debugPrint()` with user context, prompts, or database queries. Use `SafeLogger` from `lib/core/logging/safe_logger.dart`.
- **Strong typing.** Always declare return types. Do not use `dynamic` unless parsing unknown JSON, and cast immediately.
- **Business logic stays out of widgets.** UI widgets consume state and dispatch events. Logic lives in services and providers.
- **Document the why, not the what.** Use `///` for class and method docs.

## Test structure

```
test/
├── engine/                 # Auto-Redact pipeline (regex, NER, privacy filter, full pipeline, vault)
├── security/               # log hygiene, auth consistency, approval flow
├── integration/            # full service loop + monetize route + preference model
├── caas_pipeline_test.dart # experimental CaaS engines (ZK commitment + watermark) — see note below
└── widget_test.dart        # model round-trip smoke tests
```

> `caas_pipeline_test.dart` exercises the experimental `ZkCommitmentEngine` and `WatermarkEngine` **in isolation**. It does not exercise the wired `/monetize/lease_offer → /monetize/settle` HTTP flow, which is why it passes even though that flow is not yet functional end-to-end. Adding an end-to-end route test is part of the future work below.

When adding a feature, add tests in the matching directory. Engine changes go in `test/engine/`, auth/security changes go in `test/security/`, and end-to-end flows go in `test/integration/`.

## License

Trulana is source-available under the Business Source License 1.1 (not MIT, not Apache). Contributions are accepted under the same license. Commercial production use requires a paid commercial license from AdamsLocal LLC. See [LICENSE](LICENSE).
