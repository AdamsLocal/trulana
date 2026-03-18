# Trulana

**Your device is the API. Apps get answers, not your data.**

Trulana turns your Mac into a private context server for AI tools. Apps query over localhost or MCP — every response is redacted on-device before it leaves.

## Quickstart (macOS)

```bash
git clone https://github.com/AdamsLocal/trulana.git
cd trulana
flutter pub get
flutter run -d macos
```

Then in another terminal:

```bash
./scripts/demo_client.sh
```

## What it does

1. An app requests access via REST or MCP
2. Trulana issues a short-lived token (15-min TTL, in-memory)
3. The app queries your local context
4. The response passes through a 3-stage redaction pipeline (regex PII stripping, entity recognition, privacy-level generalization)
5. Only sanitized data is returned
6. Every request is logged to an encrypted audit trail

## MCP Integration (Cursor / Claude)

Build and configure:

```bash
flutter build macos --release
```

Add to your MCP client config:

```json
{
  "mcpServers": {
    "trulana": {
      "command": "/absolute/path/to/trulana.app/Contents/MacOS/trulana",
      "env": {"TRULANA_MCP": "1"}
    }
  }
}
```

Two tools are exposed:
- `sovereign_request_access` — request a scoped access token
- `sovereign_query_context` — query context (response is automatically redacted)

## REST API

When running, Trulana serves on `localhost:8432`:

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/health` | GET | None | Server health check |
| `/api/v1/auth/request` | POST | None | Agent handshake, returns access token |
| `/api/v1/context/query` | POST | Bearer token | Query the vault, response redacted by Auto-Redact Engine |

## Architecture

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart 3.x) |
| Database | SQLite encrypted via `sqflite_sqlcipher` |
| Key Storage | macOS Keychain via `flutter_secure_storage` |
| Biometrics | `local_auth` (Touch ID) |
| Local Server | `shelf` on localhost |
| MCP | stdio adapter |
| State | Riverpod |

## Tests

```bash
flutter test                       # all 117 tests
flutter test test/engine/          # redaction pipeline
flutter test test/security/        # log hygiene + auth consistency
flutter test test/integration/     # full service loop E2E
```

## Privacy & Security

- **Zero cloud storage.** All data encrypted locally. Keys in macOS Keychain (Secure Enclave backed).
- **Biometric gate.** Touch ID, no passwords, no accounts.
- **Auto-Redact Engine.** 3-stage PII stripping on every outbound response.
- **Localhost only.** Server binds to 127.0.0.1, rejects non-loopback connections.
- **TTL tokens.** 15-minute expiry, in-memory only, don't survive restart.
- **Scope recording.** Scopes are recorded per token (enforcement in progress; redaction always applies).

See [SECURITY.md](SECURITY.md) for the full security model and trust boundaries.

## Current Limits

- Scope enforcement records scopes but does not yet gate queries by scope
- MCP uses local-process trust model (no cryptographic caller verification)
- MCP per-agent rate limiting not yet enforced
- NER uses keyword dictionaries (on-device LLM is a future phase)

## Prerequisites

- macOS
- Flutter SDK >= 3.11.1
- Xcode 16+

## License

MIT License. Copyright (c) 2026 AdamsLocal LLC. See [LICENSE](LICENSE).
