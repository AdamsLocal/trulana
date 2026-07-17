# Trulana

> **Your device is the API. Apps get answers, not your data.**

Trulana is a local-first private context system for AI tools. Apps and agents query your personal context over localhost (REST) or the Model Context Protocol (MCP). Every context response is redacted on-device before it leaves the machine — raw personal data never crosses the process boundary. The shipped artifact is a **macOS Desktop MVP**.

![Flutter](https://img.shields.io/badge/Flutter-Dart%203.x-3DFFD0?style=flat-square)
![License](https://img.shields.io/badge/license-BUSL--1.1-3DFFD0?style=flat-square)
![Public binary](https://img.shields.io/badge/public%20binary-macOS%20only-0A0820?style=flat-square&labelColor=1ABFA0)

---

## Current release

**v1.2.1 — macOS Desktop MVP** ([release notes](https://github.com/AdamsLocal/trulana/releases/tag/v1.2.1))

The current public binary is Developer ID signed, notarized, and stapled:

| Property | Value |
|----------|-------|
| Signing identity | `Developer ID Application: Adam Gurley (7S7QY5ND9Q)` |
| Notarization | Apple notarized, ticket stapled |
| Gatekeeper | `spctl --assess --type execute` → `accepted, source=Notarized Developer ID` |
| Architecture | Universal binary (x86_64 + arm64) |
| Runtime | Hardened runtime enabled |
| Bundle ID | `com.adamslocal.trulana` |

macOS is the only current public binary; other platforms are not shipped. Signing and notarization are currently performed **manually** on the built artifact — CI builds an unsigned bundle but does not yet sign or notarize (tracked in [SECURITY.md](SECURITY.md#macos-release-checklist)).

> After downloading a release, extract with Finder or `ditto -x -k` rather than `unzip`; `unzip` strips the extended attribute that holds the stapled notarization ticket.

---

## Why it exists

The default pattern for giving an AI tool context about you is to *copy your data into it* — into a prompt, a vector store, or a vendor's cloud. Once copied, you no longer control it.

Trulana inverts that. Your context stays in an encrypted vault on your device. Apps don't receive your data; they receive **redacted answers to scoped queries**, issued under a short-lived token you explicitly approved. The device is the API.

---

## How it works

| Step | What happens |
|------|--------------|
| 01 · App requests access | Over REST, or through MCP with requested scopes, intent, and an Ed25519 public key whose fingerprint is shown for approval. |
| 02 · You approve or reject | First-contact agents are persisted as **pending** and receive no token until you approve. You can narrow the requested scopes before approving. |
| 03 · Token issued | 15-minute TTL · in-memory only · never persisted · scopes enforced at query time. |
| 04 · Context queried | The app queries your local vault over localhost using the token. |
| **05 · Auto-Redact Engine** | **A 3-stage on-device PII pipeline runs on every context response.** |
| 06 · Sanitized answer returned | Redacted answers only — raw context never leaves the device. |
| 07 · Audit logged | Every grant, rejection, query, and offer is written to an encrypted audit trail. |

REST and MCP are thin transports over the **same** service layer, so token issuance, scope enforcement, redaction, and audit logging are identical regardless of how an agent connects.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│  Transports                                                    │
│   • REST   — shelf HTTP server, bound to 127.0.0.1:8432        │
│   • MCP    — stdio JSON-RPC adapter (TRULANA_MCP=1)            │
├──────────────────────────────────────────────────────────────┤
│  Shared services (single source of policy)                     │
│   • AuthService          — token issuance + audit              │
│   • ContextQueryService  — vault lookup + redaction + audit    │
│   • TokenManager         — in-memory, 15-min TTL, scoped       │
│   • AutoRedactEngine     — 3-stage PII pipeline                │
├──────────────────────────────────────────────────────────────┤
│  Encrypted storage                                             │
│   • sqflite_sqlcipher        — AES-256 encrypted SQLite        │
│   • flutter_secure_storage   — DB key in the macOS Keychain    │
└──────────────────────────────────────────────────────────────┘
```

| Layer | Technology |
|-------|-----------|
| Framework | Flutter · Dart 3.x |
| State | Riverpod |
| Database | SQLite encrypted via `sqflite_sqlcipher` (AES-256) |
| Key storage | `flutter_secure_storage` — the DB key is held as a generic macOS Keychain item (it is **not** generated or operated on inside the Secure Enclave) |
| Biometrics | `local_auth` · Touch ID |
| Local server | `shelf` / `shelf_router` · loopback only · rejects non-loopback at the socket and again in middleware |
| MCP | stdio JSON-RPC 2.0 adapter |

---

## REST API

The server binds to `127.0.0.1:8432`. Non-loopback connections are rejected at the socket level, and again by defense-in-depth middleware.

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/health` | GET | None | Server health check |
| `/api/v1/auth/request` | POST | None | Agent handshake → returns a scoped access token (or 403 + `pending` on first contact) |
| `/api/v1/context/query` | POST | Bearer + `context.read` | Query the vault · response redacted by the Auto-Redact Engine |
| `/api/v1/monetize/lease_offer` | POST | Bearer + `monetize.write` | Record an inbound data-lease offer for user review |

Protected routes sit behind token auth and a sliding-window rate limiter (60 requests/minute per agent). A success response from `/context/query` looks like:

```json
{
  "status": "success",
  "data": "...redacted answer...",
  "privacy_level": "strict",
  "redactions_applied": 7
}
```

> An experimental Context-as-a-Service escrow extends the monetize routes; it is **unreleased** and described under [Experimental](#experimental-context-as-a-service-escrow-unreleased) below.

---

## MCP integration (Claude / Cursor)

Add Trulana to your MCP client config:

```json
{
  "mcpServers": {
    "trulana": {
      "command": "/Applications/trulana.app/Contents/MacOS/trulana",
      "env": { "TRULANA_MCP": "1" }
    }
  }
}
```

Three tools are exposed (JSON-RPC `2024-11-05`):

- **`sovereign_auth_challenge`** — enroll a raw 32-byte Ed25519 public key (base64url) or request a fresh challenge for an approved key.
- **`sovereign_auth_prove`** — submit a raw 64-byte Ed25519 signature (base64url) over the decoded `signing_payload`; a valid proof returns the scoped token.
- **`sovereign_query_context`** — query the vault with that token; the response is automatically redacted.

First contact creates a pending approval containing the requested scopes and the SHA-256 fingerprint of the caller's public key. After approval, challenges expire after 60 seconds, are held only in memory, and are consumed before signature verification so failed proofs and successful proofs cannot be replayed. The legacy `sovereign_request_access` MCP call fails closed. A key-bound identity also cannot mint a token through the REST app-ID route without the MCP proof.

The proof authenticates possession of the approved private key; it does not attest the operating system or prove that the surrounding MCP client process is uncompromised. Existing approvals without a key must be revoked and re-enrolled for MCP use.

> This implementation is newer than the signed v1.2.1 binary. It becomes a shipped property only in a later signed release.

---

## Auto-Redact Engine

Every context response passes through three sequential, on-device stages before it is returned:

1. **Regex filter** — deterministic stripping of structured PII: SSNs, emails, phone numbers, credit-card numbers, IP addresses.
2. **NER processor** — named-entity recognition for person names, locations, and organizations. The shipped processor is a **deterministic keyword dictionary** (`MockNerProcessor`); the interface is dependency-injected and swap-ready for an on-device model (see [Limitations](#current-limitations)).
3. **Privacy filter** — privacy-level-dependent generalization layered on top of stages 1–2.

| Privacy level | Behavior |
|---------------|----------|
| **Standard** | Pass-through after stages 1 + 2 |
| **Strict** | Additionally generalizes times, currency amounts, and ages |
| **Paranoid** | All of strict, plus a proper-noun catch-all and an inserted noise disclaimer |

As defense in depth, a response-layer filter also scrubs structured PII (email / IP) from outbound JSON, so the loopback socket never emits an unfiltered structured identifier even if a future route forgets to redact.

---

## Privacy & security model

- **Local-only storage.** All data is encrypted at rest with AES-256. The DB key lives in the macOS Keychain and never leaves the device, never appears in logs, and is not stored in environment variables.
- **Biometric gate.** Touch ID via `local_auth`. No accounts, no cloud identity.
- **Explicit, scoped approval.** First-contact agents are persisted as `pending` and receive no token until you approve. MCP approvals display and bind an Ed25519 public-key fingerprint. Granted scopes are authoritative and cannot be silently broadened by re-auth.
- **TTL tokens.** 15-minute expiry, in-memory only, do not survive a restart. Scopes are enforced at query time (`context.read` for `/context/query`, `monetize.write` for `/monetize/lease_offer`).
- **Loopback only.** The server binds to `127.0.0.1`; non-loopback connections are rejected at the socket and re-checked in middleware. CORS is restricted to `http://localhost`.
- **Zero-PII logging.** `SafeLogger` enforces a strict allowlist; tokens, raw queries, response data, PII, DB paths, and keys are never logged. In MCP mode all logs go to stderr so stdout carries only JSON-RPC.
- **Encrypted audit trail.** Every grant, rejection, query, and offer is recorded. The trail is encrypted-at-rest but **not** tamper-evident (no hash chain) — see [Limitations](#current-limitations).

No regulatory certifications (HIPAA, SOC 2, FedRAMP, GDPR, etc.) are claimed. See **[SECURITY.md](SECURITY.md)** for the full trust model, threat boundaries, and release checklist.

---

## Experimental: Context-as-a-Service escrow (unreleased)

The repository contains an in-progress monetization layer that lets an agent pay to unlock specific context under a cryptographic-commitment-then-reveal scheme, with provenance watermarking. **This layer is not part of the signed v1.2.1 binary and must not be represented as production.** Current status:

- **`ZkCommitmentEngine`** — SHA-256 commitment (`salt + data → hash`) and a `verifyProof` reveal check. The primitive is unit-tested in isolation and is sound.
- **`WatermarkEngine`** — encodes a trace ID into zero-width characters and appends it to a payload, with a matching extractor. Unit-tested inject/extract round-trip.
- **Known gap:** the end-to-end HTTP flow (`/monetize/lease_offer` → `/monetize/settle`) does **not** yet persist the commitment salt between the two requests, so a hash issued at offer time cannot currently be verified at settlement. The unit tests exercise the engines directly and therefore pass, but the wired HTTP escrow is not functional end-to-end.

Treat this as a research preview. Maturing it (salt/commitment persistence keyed by offer, scope enforcement on settle, end-to-end tests) is tracked in [CONTRIBUTING.md](CONTRIBUTING.md#future-work).

---

## Tests

```bash
flutter test                  # full suite
flutter test test/engine/     # redaction pipeline (regex, NER, privacy filter, vault)
flutter test test/security/   # log hygiene, auth consistency, approval flow
flutter test test/integration/ # service loop + monetize route + preferences
```

CI (`.github/workflows/ci.yml`) runs `flutter analyze`, `dart format --set-exit-if-changed`, and `flutter test` on every push and pull request, plus an unsigned `flutter build macos`.

---

## Current limitations

- **MCP proof is key possession, not process attestation** — Ed25519 challenge-response identifies the approved key, but a compromised host or client that steals/uses the private key remains outside this boundary. REST-only identities remain app-ID based unless enrolled for MCP key binding.
- **MCP per-agent rate limiting is not enforced** — rate limiting lives in the REST/HTTP middleware layer, not the shared service layer.
- **NER is a keyword dictionary** — on-device LLM/SLM redaction is a future phase; the pipeline interface is already swap-ready.
- **Release signing + notarization are manual** — CI builds an unsigned bundle only.
- **The audit log is encrypted-at-rest but not tamper-evident** — no hash chain or external attestation; an attacker holding the DB key could modify rows undetected.
- **macOS is the only public binary** — Windows, Linux, iOS, and Android are not shipped.

---

## Prerequisites (development)

- macOS
- Flutter SDK ≥ 3.11.1
- Xcode 16+

```bash
git clone https://github.com/AdamsLocal/trulana.git
cd trulana
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates Riverpod / json_serializable code
flutter test
flutter run -d macos
```

---

## License

Business Source License 1.1. Copyright © 2026 AdamsLocal LLC. See [LICENSE](LICENSE).

Source-available, not MIT or Apache. Free for non-commercial, personal, research, and evaluation use. **Commercial production use requires a paid commercial license from AdamsLocal LLC.**
