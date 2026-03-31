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
- Access is gated by `AuthService` — agents must call `trulana_request_access` to obtain a token before calling `trulana_query_context`.
- Both calls flow through the same service singletons as REST. No bypass path exists.

### Current Trust Boundary (MVP)

- Any local process that can invoke the binary with `TRULANA_MCP=1` can start an MCP session.
- Access is still gated by token issuance: the agent must provide `app_id`, `app_name`, `scopes`, and `intent` to receive a token.
- Every access attempt (successful or rejected) is written to the encrypted audit log.
- Tokens are in-memory only (RAM), 15-minute TTL, and do not survive process restart.

### What Is Not Yet Enforced

- **User consent modal**: The MVP auto-approves token requests. Production will require explicit user approval before granting access.
- **Scope enforcement**: Scopes are recorded but not enforced at the query level. Any valid token can query any vault context.
- **Per-agent rate limiting on MCP**: The REST path has sliding-window rate limiting. The MCP path currently does not enforce per-agent rate limits (the service layer does not rate-limit; only the shelf middleware does).

## Encryption

### Database

- `sqflite_sqlcipher` provides AES-256 full-database encryption.
- The encryption key is a 256-bit value generated from `Random.secure()` (maps to `/dev/urandom`).
- The key is stored in macOS Keychain via `flutter_secure_storage` with:
  - `KeychainAccessibility.first_unlock_this_device` — key is non-migratable between devices.
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

Before distributing the Trulana binary:

- [x] **Code signing**: Sign the `.app` bundle with a valid Apple Developer ID. Unsigned binaries will be blocked by Gatekeeper.
- [x] **Hardened runtime**: Enable hardened runtime in Xcode build settings. Required for notarization and prevents code injection.
- [x] **Notarization**: Submit the signed binary to Apple's notarization service via `xcrun notarytool`. This is required for macOS 10.15+ distribution outside the App Store.
- [x] **Entitlements review**: Verify that only required entitlements are present:
  - `com.apple.security.app-sandbox` — required
  - `com.apple.security.network.server` — required for localhost binding
  - `com.apple.security.cs.allow-jit` — required for Dart VM (debug only)
- [x] **Do not distribute unsigned debug builds.** Debug builds emit the Dart VM service URL to stdout, include assert-enabled code paths (e.g. `debug_ttl_seconds`), and are not hardened.

## Acceptable Risks (MVP)

| Risk | Severity | Mitigation | Status |
|---|---|---|---|
| Auto-approve on token requests | Medium | Audit log captures all grants. Production adds consent modal. | Documented |
| Scopes recorded but not enforced | Low | Any valid token can query any context. Redaction still applies. | Documented |
| No per-agent rate limiting on MCP | Low | MCP is local subprocess, not network-exposed. | Documented |
| Mock NER (keyword-based, not AI) | Medium | Regex filter catches structured PII. Mock NER catches common names/cities/orgs. Real NER is a future phase. | Documented |
| Debug build stdout contamination | Low | Release builds are clean. `test_mcp.sh` validates. | Validated |
| TokenManager is in-memory | Low | By design — tokens don't survive restart. Limits blast radius. | By design |

## Test Coverage

| Area | Tests | What Is Asserted |
|---|---|---|
| Redaction pipeline | 89 unit tests | All PII types stripped at all privacy levels |
| REST API | 38 integration checks | Auth, rejection, redaction, PII leak detection, token expiry |
| MCP protocol | 18 checks (release) | Stdout cleanliness, tool discovery, auth, redaction, rejection |
| Service loop + models | 31 integration tests | Full auth → query → redact → audit E2E + preference model |
| Log hygiene | 6 tests | No tokens, PII, keys, or DB paths in log output |
| Auth consistency | 5 tests | Singleton identity, identical validation across transports |
