# Trulana™

> **Your device is the API. Apps get answers, not your data.**

Trulana turns any device into a private context server for AI tools. Apps query over localhost or MCP — every response is redacted on-device before it leaves. MCP-native. Cross-platform. Zero cloud.

![Tests](https://img.shields.io/badge/tests-117%20passing-3DFFD0?style=flat-square) ![Flutter](https://img.shields.io/badge/Flutter-Dart%203.x-3DFFD0?style=flat-square) ![License](https://img.shields.io/badge/license-BUSL--1.1-3DFFD0?style=flat-square) ![Platform](https://img.shields.io/badge/platform-macOS%20·%20Windows%20·%20Linux%20·%20iOS%20·%20Android-0A0820?style=flat-square&labelColor=1ABFA0)

---

## How it works — six steps, zero leaks

| Step | What happens |
|------|-------------|
| 01 · App requests access | Via REST or MCP stdio adapter |
| 02 · Token issued | 15-min TTL · in-memory only · never persisted |
| 03 · Context queried | App queries your local vault over localhost |
| **04 · Auto-Redact Engine** | **3-stage PII pipeline fires on every response** |
| 05 · Sanitized data returned | Answers only — no raw context ever leaves |
| 06 · Audit logged | Encrypted trail · every request · tamper-evident |

---

## Quickstart (macOS)

```bash
git clone https://github.com/AdamsLocal/trulana.git
cd trulana
flutter pub get
flutter run -d macos
```

Then in a second terminal:

```bash
./scripts/demo_client.sh
```

---

## MCP Integration (Claude / Cursor)

Build release:

```bash
flutter build macos --release
```

Add to your MCP client config:

```json
{
  "mcpServers": {
    "trulana": {
      "command": "/absolute/path/to/trulana.app/Contents/MacOS/trulana",
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

Server binds to `localhost:8432`. Non-loopback connections rejected.

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/health` | GET | None | Server health check |
| `/api/v1/auth/request` | POST | None | Agent handshake · returns access token |
| `/api/v1/context/query` | POST | Bearer token | Query vault · response redacted by Auto-Redact Engine |

---

## Architecture

| Layer | Technology |
|-------|-----------|
| Framework | Flutter · Dart 3.x · every OS |
| Database | SQLite encrypted via `sqflite_sqlcipher` |
| Key storage | macOS Keychain · Secure Enclave backed |
| Biometrics | `local_auth` · Touch ID · no passwords · no accounts |
| Local server | `shelf` · localhost only · rejects non-loopback |
| MCP | stdio adapter · works with Claude + Cursor today |
| State | Riverpod |

---

## Privacy & Security

**Zero cloud storage** — All data encrypted locally. Keys in OS Keychain, Secure Enclave backed. Nothing leaves the device unredacted.

**Biometric gate** — Touch ID. No passwords, no accounts, no recovery email.

**Auto-Redact Engine** — 3-stage pipeline on every outbound response: regex PII stripping → entity recognition → privacy-level generalization.

**TTL tokens** — 15-minute expiry. In-memory only. Don't survive a restart. Scope recorded per token.

**Localhost only** — Server binds to `127.0.0.1`. Non-loopback connections rejected at the socket level.

**Encrypted audit trail** — Every request logged. Tamper-evident. You own the log and the key.

See [SECURITY.md](SECURITY.md) for the full security model and trust boundaries.

---

## Tests

```bash
flutter test                        # all 117 tests
flutter test test/engine/           # redaction pipeline
flutter test test/security/         # log hygiene + auth consistency
flutter test test/integration/      # full service loop E2E
```

---

## Current limits

- Scope enforcement records scopes but does not yet gate queries by scope
- MCP uses local-process trust model — no cryptographic caller verification yet
- MCP per-agent rate limiting not yet enforced
- NER uses keyword dictionaries — on-device LLM redaction is a future phase

---

## Prerequisites

- macOS (other platforms via Flutter)
- Flutter SDK >= 3.11.1
- Xcode 16+

---

## License

MIT License. Copyright © 2026 AdamsLocal LLC. See [LICENSE](LICENSE).
