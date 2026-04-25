# Trulana

> **Your device is the API. Apps get answers, not your data.**

Trulana is a local-first private context system for AI tools. Apps query over localhost (REST) or MCP — every context response is redacted on-device before it leaves. The current shipped artifact is a **macOS Desktop MVP**.

![Flutter](https://img.shields.io/badge/Flutter-Dart%203.x-3DFFD0?style=flat-square) ![License](https://img.shields.io/badge/license-BUSL--1.1-3DFFD0?style=flat-square) ![Platform](https://img.shields.io/badge/public%20binary-macOS%20only-0A0820?style=flat-square&labelColor=1ABFA0)

---

## Current release

**v1.2.1 — macOS Desktop MVP**

- Developer ID signed (`Adam Gurley · 7S7QY5ND9Q`)
- Apple notarized
- Notarization ticket stapled
- Gatekeeper accepted (`spctl --assess --type execute` → `accepted, source=Notarized Developer ID`)
- Universal binary (x86_64 + arm64)
- Hardened runtime enabled

macOS is the only current public binary. Other platforms are not shipped.

Signing and notarization are currently performed manually. CI builds the bundle but does not yet sign or notarize.

---

## How it works

| Step | What happens |
|------|-------------|
| 01 · App requests access | Via REST or MCP stdio adapter; provides requested scopes and intent |
| 02 · You approve or reject | First-contact agents are pending until you approve. You can narrow the requested scopes before approval. |
| 03 · Token issued | 15-min TTL · in-memory only · never persisted · scopes enforced at query time |
| 04 · Context queried | App queries your local vault over localhost using the token |
| **05 · Auto-Redact Engine** | **3-stage PII pipeline runs on every context response** |
| 06 · Sanitized data returned | Answers only — no raw context ever leaves |
| 07 · Audit logged | Encrypted trail for grants, rejections, queries, and offers |

---

## MCP Integration (Claude / Cursor)

Add to your MCP client config:

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

Two tools exposed:

- `sovereign_request_access` — request a scoped access token
- `sovereign_query_context` — query context vault (response automatically redacted)

---

## REST API

Server binds to `127.0.0.1:8432`. Non-loopback connections rejected at the socket level.

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/health` | GET | None | Server health check |
| `/api/v1/auth/request` | POST | None | Agent handshake · returns access token (or 403 + pending if first contact) |
| `/api/v1/context/query` | POST | Bearer token + `context.read` scope | Query vault · response redacted by Auto-Redact Engine |
| `/api/v1/monetize/lease_offer` | POST | Bearer token + `monetize.write` scope | Submit a lease offer |

---

## Architecture

| Layer | Technology |
|-------|-----------|
| Framework | Flutter · Dart 3.x |
| Database | SQLite encrypted via `sqflite_sqlcipher` (AES-256) |
| Key storage | `flutter_secure_storage` — macOS Keychain (the DB key is held as a generic Keychain item; it is **not** generated or operated on inside the Secure Enclave) |
| Biometrics | `local_auth` · Touch ID |
| Local server | `shelf` · localhost only · rejects non-loopback |
| MCP | stdio adapter |
| State | Riverpod |

---

## Privacy & Security

**Local-only storage** — All data encrypted locally. The DB encryption key is held in the macOS Keychain and never leaves the device.

**Biometric gate** — Touch ID. No accounts.

**User-approved agent access** — First-contact agents are persisted as pending. You approve or reject explicitly and can narrow the requested scopes before approval. No silent activation.

**Auto-Redact Engine** — 3-stage pipeline on every **context response**: regex PII stripping → entity recognition → privacy-level generalization. (The auth and monetize routes do not emit context data, so they bypass the engine by design.)

**TTL tokens** — 15-minute expiry. In-memory only. Don't survive a restart. Scopes are enforced at query time — `context.read` for `/context/query`, `monetize.write` for `/monetize/lease_offer`.

**Localhost only** — Server binds to `127.0.0.1`. Non-loopback connections rejected at the socket level.

**Encrypted audit trail** — Every grant, rejection, query, and offer is written to the encrypted audit table. The trail is encrypted-at-rest but not tamper-evident (no hash chain).

No regulatory certifications (HIPAA, SOC 2, FedRAMP, GDPR, etc.) are claimed.

See [SECURITY.md](SECURITY.md) for the full security model and trust boundaries.

---

## Tests

```bash
flutter test                        # full suite
flutter test test/engine/           # redaction pipeline
flutter test test/security/         # log hygiene, auth consistency, approval flow
flutter test test/integration/      # service loop + monetize route
```

---

## Current limits

- MCP uses a local-process trust model — no cryptographic caller verification
- MCP per-agent rate limiting not yet enforced
- NER uses keyword dictionaries — on-device LLM redaction is a future phase
- Release signing + notarization are performed manually — CI builds but does not sign
- Audit log is encrypted-at-rest but not tamper-evident (no hash chain)
- macOS is the only current public binary

---

## Prerequisites (development)

- macOS
- Flutter SDK >= 3.11.1
- Xcode 16+

---

## License

Business Source License 1.1. Copyright © 2026 AdamsLocal LLC. See [LICENSE](LICENSE).

Source-available, not MIT or Apache. Free for non-commercial, personal, research, and evaluation use. **Commercial production use requires a paid commercial license from AdamsLocal LLC.**
