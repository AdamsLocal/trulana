# Trulana Security Model

## Architecture Overview

Trulana is a local-first personal data broker. All data stays on-device in an encrypted database. Third-party agents access user context through two transport layers — REST (localhost HTTP) and MCP (stdio) — both of which are gated by the same shared services.

```
┌────────────────────────────────────────────────────────┐
│  Transport: REST (shelf, 127.0.0.1:8432)               │
│  Transport: MCP  (stdio, TRULANA_MCP=1)              │
├────────────────────────────────────────────────────────┤
│  Shared Services (policy enforcement)                  │
│  ├── AuthService       → token issuance + audit        │
│  ├── ContextQueryService → vault + redaction + audit   │
│  ├── TokenManager      → in-memory, 15-min TTL         │
│  └── AutoRedactEngine  → 3-stage PII stripping         │
├────────────────────────────────────────────────────────┤
│  Encrypted Storage                                     │
│  ├── sqflite_sqlcipher  → AES-256 encrypted SQLite     │
│  └── flutter_secure_storage → Keychain (macOS)         │
└────────────────────────────────────────────────────────┘
```

## Trust Model

### REST Transport

- Bound to `127.0.0.1` only — kernel-level rejection of non-localhost traffic.
- Defense-in-depth middleware double-checks remote address.
- CORS restricted to `http://localhost`.
- Agents must call `POST /api/v1/auth/request` to receive a scoped, time-limited token before any data access.

### MCP Transport

- Runs as a subprocess launched by the MCP client (Claude Desktop, Cursor, etc.).
- The MCP client controls which binary is launched and what environment variables are set.
- Access is gated by `AuthService` — agents must call `sovereign_request_access` to obtain a token before calling `sovereign_query_context`.
- Both calls flow through the same service singletons as REST. No bypass path exists.

### Current Trust Boundary (MVP)

- Any local process that can invoke the binary with `TRULANA_MCP=1` can start an MCP session.
- Access is gated by an explicit user approval step: first-contact agents are persisted as `pending` and receive no token until the user approves them from the Gatekeeper UI. The user may narrow the requested scopes before approval.
- Approved tokens carry only the scopes the user confirmed; re-auth cannot broaden the grant.
- `/api/v1/context/query` and MCP `sovereign_query_context` require the `context.read` scope.
- `/api/v1/monetize/lease_offer` requires the `monetize.write` scope.
- Every access attempt (successful, rejected, or pending) is written to the encrypted audit log.
- Tokens are in-memory only (RAM), 15-minute TTL, and do not survive process restart.

### What Is Not Yet Enforced

- **Per-agent rate limiting on MCP**: The REST path has sliding-window rate limiting. The MCP stdio transport currently does not enforce per-agent rate limits.
- **Tamper-evidence on the audit log**: The audit table lives in the encrypted database. An attacker who obtained the database key could modify rows without detection (no hash chain, no append-only journal, no external attestation).
- **Cryptographic caller verification on MCP**: MCP uses a local-process trust model. Any process that can spawn the binary with `TRULANA_MCP=1` can start a session — approval still gates data access, but the caller identity is not cryptographically attested.

## Encryption

### Database

- `sqflite_sqlcipher` provides AES-256 full-database encryption.
- The encryption key is a 256-bit value generated from `Random.secure()` (maps to `/dev/urandom` on POSIX).
- The key is stored via `flutter_secure_storage`:
  - iOS: Keychain with `KeychainAccessibility.first_unlock_this_device` (non-migratable between devices; items stored by iOS under hardware-protected storage on supported devices). The key itself is a symmetric AES key held as a generic Keychain item — it is **not** generated or operated on inside the Secure Enclave. The Secure Enclave is only engaged by `SecKeyCreateRandomKey` with `kSecAttrTokenIDSecureEnclave`, which this code does not use.
  - Android: `EncryptedSharedPreferences`.
  - macOS: default Keychain options (no explicit hardware-key binding).
- The key never appears in logs, environment variables, or application memory beyond the initial retrieval.

### Key Lifecycle

- Generated once on first launch.
- Retrieved from Keychain on each subsequent session.
- `KeyManager.deleteKey()` makes the database permanently irrecoverable (account reset only).

## Auto-Redact Engine

Every outbound response passes through three sequential stages:

1. **Regex Filter** — Deterministic stripping of SSNs, emails, phones, credit cards, IP addresses.
2. **NER Processor** — Named-entity recognition for person names, locations, organizations (mock keyword matching in MVP; abstract interface ready for on-device LLM).
3. **Privacy Filter** — Level-dependent generalization:
   - Standard: pass-through after stages 1+2.
   - Strict: additionally generalizes times, currency amounts, ages.
   - Paranoid: all of strict plus proper-noun catch-all and noise disclaimer.

## Logging Policy

`SafeLogger` enforces a strict output contract:

- **Logged**: route, HTTP method, status code, agent ID, action type, redaction count, privacy level, vault hit count, TTL.
- **Never logged**: token values, raw query text, response data, PII, database paths, encryption keys, error stack traces containing user data.
- **MCP mode**: all log output goes to stderr. stdout is reserved exclusively for JSON-RPC protocol messages.
- **Test coverage**: `test/security/log_hygiene_test.dart` asserts that no SafeLogger method can emit tokens, PII, keys, or database paths.

## Audit Trail

Every agent interaction produces an `AuditLogEntry` in the encrypted database:

- `log_id` — UUID
- `agent_id` — which agent made the request
- `request_intent` — structural description of the action
- `action_taken` — approved, blocked, redacted, or negotiated
- `timestamp` — ISO 8601

Both REST and MCP paths write audit entries through the same `AuthService` and `ContextQueryService`. There is no path that bypasses audit logging.

## macOS Release Checklist

Release signing is performed **manually on the built artifact**, not inside the Xcode project. The local project uses `CODE_SIGN_IDENTITY = "-"` (ad-hoc) for developer iteration; release binaries are re-signed with a Developer ID and notarized as a separate step. Status below reflects the **current public release, v1.2.1** ([release notes](https://github.com/AdamsLocal/trulana/releases/tag/v1.2.1)):

- [x] **Code signing** — signed with `Developer ID Application: Adam Gurley (7S7QY5ND9Q)`. Verified via `codesign -dvvv` (Authority chain ends at Apple Root CA; `TeamIdentifier=7S7QY5ND9Q`).
- [x] **Hardened runtime** — `flags=0x10000(runtime)`. Required for notarization.
- [x] **Notarization** — stapled notarization ticket. Verified via `xcrun stapler validate` ("The validate action worked!") and `spctl --assess --type execute` ("accepted, source=Notarized Developer ID").
- [x] **Universal binary** — Mach-O universal (x86_64 + arm64).
- [x] **Entitlements review** — Only the following are present on release:
  - `com.apple.security.app-sandbox` — required
  - `com.apple.security.network.server` — required for localhost binding
  - `com.apple.security.cs.allow-jit` — required for Dart VM (debug only)
- [x] **Do not distribute unsigned debug builds.** Debug builds emit the Dart VM service URL to stdout, include assert-enabled code paths (e.g. `debug_ttl_seconds`), and are not hardened. Policy stands.

**Release lineage** (for provenance during diligence): v1.0.0 was the first notarized release but predates the hardened approval / scope-enforcement model. v1.1.0 was a UI milestone with no attached binary. v1.2.0 shipped the correct security model but mislabeled its bundle/UI version as `1.0.0` due to a stale Flutter version-config cache. **v1.2.1 is the current correct baseline** and is the version all other documentation refers to.

**Open release-hygiene items** (not code-signing, but related):

- [ ] **Automate signing + notarization in CI.** `.github/workflows/ci.yml` now runs analyze + test and builds an **unsigned** macOS bundle; it does not codesign, notarize, or staple. Signing is performed manually by the maintainer holding the Developer ID key. A future tag-gated release workflow should invoke `codesign --timestamp --options runtime`, `xcrun notarytool submit --wait`, and `xcrun stapler staple` so releases are reproducible and auditable.
- [ ] **Developer ID is personal (`Adam Gurley`), not organizational (`AdamsLocal LLC`).** The landing page and LICENSE assert trademark/ownership by AdamsLocal LLC; the signing identity on shipped binaries is personal. Transfer to an org Developer ID is recommended before any paid commercial release.

## Out of Scope: Experimental CaaS Escrow

The development branch contains an in-progress Context-as-a-Service monetization layer (`ZkCommitmentEngine`, `WatermarkEngine`, and the `/api/v1/monetize/settle` route). **It is not part of the signed v1.2.1 binary and is excluded from the trust model above.** Security-relevant caveats for anyone reviewing that code:

- The SHA-256 commitment primitive and the zero-width watermark round-trip are unit-tested in isolation and behave correctly there.
- The wired HTTP flow is **not** functional end-to-end: `/monetize/lease_offer` returns a commitment hash but does not persist the salt, so `/monetize/settle` regenerates a fresh salt and the original hash cannot be verified.
- `/monetize/settle` currently checks only for a valid token, not for the `monetize.write` scope that `/monetize/lease_offer` requires.
- The zero-width "watermark" is steganographic provenance tagging, not an access control. It is trivially strippable by any normalizer and must not be relied on as a security boundary.

Do not represent this layer as production until commitment persistence, scope enforcement on settlement, and end-to-end tests land.

## Acceptable Risks (MVP)

| Risk | Severity | Mitigation | Status |
|---|---|---|---|
| No per-agent rate limiting on MCP | Low | MCP is a local subprocess, not network-exposed. User approval still gates data access. | Documented |
| Mock NER (keyword-based, not AI) | Medium | Regex filter catches structured PII. Mock NER catches common names/cities/orgs. Real on-device NER is a future phase. | Documented |
| Audit log is not tamper-evident | Medium | Audit rows are encrypted-at-rest inside the SQLCipher database but have no hash chain or external attestation. An attacker with the DB key could modify rows without detection. | Documented |
| Debug build stdout contamination | Low | Release builds are clean. `test_mcp.sh` validates. | Validated |
| TokenManager is in-memory | Low | By design — tokens don't survive restart. Limits blast radius. | By design |
| No CI signing pipeline | Medium | Release signing + notarization is performed manually by the maintainer holding the Developer ID key. Human-dependent; no audit trail of the signing step. Future CI workflow should automate it. | Open |
| Experimental CaaS escrow wired into routes | Medium | The `/monetize/settle` route and ZK/watermark engines exist on the development branch but are not in the signed v1.2.1 binary and are not functional end-to-end (commitment salt not persisted across requests). Settlement also does not currently enforce a `monetize.write` scope check. Must not be presented as production. | Open / out of scope |

## Test Coverage

Test counts are not pinned here. Run `flutter test` for the current number. The suite covers:

| Area | What Is Asserted |
|---|---|
| Redaction pipeline | All supported PII types are stripped at each privacy level |
| Service loop | Token minted with `context.read` → query → redact → audit, end-to-end, for multiple content flavors |
| Scope enforcement | Tokens without `context.read` are rejected; tokens without `monetize.write` cannot submit lease offers |
| Approval flow | Defensive paths: empty scopes, not-found, not-pending, non-pending rejection does not revoke tokens |
| Log hygiene | No tokens, PII, keys, or DB paths appear in log output |
| Auth consistency | Singleton identity, identical validation across transports, identical rejection codes |
