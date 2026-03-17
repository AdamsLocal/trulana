# Trulana

Trulana turns your device into a private context server. Apps can query what they need — but raw data never leaves. Every response is filtered on-device before it’s returned.

## Status

**macOS MVP / technical preview**

- REST transport (localhost API) — verified
- MCP transport (Claude / Cursor) — verified
- Shared policy core across both — enforced and tested

117 tests passing. Full integration checks for both transports.

## What this proves

- Your device can act as the API instead of the client
- Third-party apps can request context without accessing raw data
- Privacy enforcement can happen locally, not in the cloud

## Key Features

- **Local Context Vault:** Encrypted on-device storage of user preferences, health data, and schedules. No cloud database.
- **Gatekeeper Protocol:** Real-time dashboard to view, approve, deny, or revoke third-party data access.
- **Auto-Redact Engine:** 3-stage PII sanitization pipeline (Regex -> NER AI -> Privacy Thresholds) ensuring personal data never leaks.
- **Data Monetization Hub:** Opt-in data leasing to verified brands via micro-transactions.
- **Local API Server:** Third-party apps query Trulana over localhost — no cloud round-trip.

## Architecture

Trulana is built on a strict edge-computing paradigm. There is no centralized cloud database.

| Layer | Technology |
|-------|-----------|
| Framework | Flutter (Dart 3.x, strict null safety) |
| State Management | Riverpod |
| Database | SQLite encrypted via `sqflite_sqlcipher` |
| Key Storage | `flutter_secure_storage` (Secure Enclave / KeyStore) |
| Biometrics | `local_auth` (Face ID / fingerprint) |
| Local Server | `shelf` + `shelf_router` on localhost |
| Routing | `go_router` with auth guards |
| Animation | `flutter_animate` + custom `BackdropFilter` glassmorphism |
| Typography | Inter (body) + JetBrains Mono (data/metrics) via `google_fonts` |

## Project Structure

```
lib/
├── core/
│   ├── database/        # Encrypted SQLite schema, migrations, helper singleton
│   ├── security/        # KeyManager (Secure Enclave) + BiometricAuth wrapper
│   ├── network/         # Local shelf HTTP server, routes, middleware, token manager
│   ├── theme/           # Dark palette, typography, color constants
│   ├── ui/              # GlassCard, PulseIndicator, MeshGradient, PrivacySlider, etc.
│   └── router/          # GoRouter config with auth redirect
├── features/
│   ├── onboarding/      # 5-step onboarding flow
│   ├── dashboard/       # Vault status, connections carousel, monetization hub
│   ├── gatekeeper/      # Activity log and granular permissions
│   ├── engine/          # Auto-Redact pipeline (regex, NER mock, privacy filter)
│   └── monetization/    # Ledger, micro-transactions, wallet UI
├── models/              # UserConfig, AuthorizedAgent, AuditLogEntry, LedgerEntry
├── providers/           # Riverpod providers for all data domains
└── main.dart            # App entry point with ProviderScope
```

## Prerequisites

- Flutter SDK >= 3.11.1
- Dart SDK >= 3.11.1
- Xcode 16+ (for iOS builds)
- Android Studio or Android SDK with API 21+ (for Android builds)
- A physical device for biometric testing (simulators have limited biometric support)

## Setup & Installation

```bash
# Clone the repository
git clone https://github.com/AdamsLocal/trulana.git
cd trulana

# Install dependencies
flutter pub get

# Verify your environment can target all platforms
flutter doctor
```

## Running Tests

```bash
# Run all 117 unit + integration tests
flutter test

# Run only the Auto-Redact Engine tests
flutter test test/engine/

# Run with verbose output
flutter test --reporter expanded
```

---

## Testing on Each Platform

### iOS (iPhone / iPad)

**Requirements:** macOS, Xcode 16+, an Apple Developer account (free works for device testing).

```bash
# List available iOS simulators
flutter emulators

# Launch the iPhone 16 Pro simulator
open -a Simulator

# Run on the simulator
flutter run -d iPhone

# Or run on a physical iPhone connected via USB
flutter run -d <your-device-id>
```

**Biometric testing on simulator:** Open the Simulator app, go to **Features > Face ID** (or Touch ID) and select **Enrolled**. Use **Features > Face ID > Matching Face** to simulate a successful biometric scan during onboarding.

**Biometric testing on device:** Just use your real Face ID or fingerprint — it works natively.

```bash
# Build for device testing (debug)
flutter run --release -d <your-device-id>

# Build for App Store / TestFlight
flutter build ios --release
open ios/Runner.xcworkspace
# In Xcode: Product > Archive > Distribute App
```

### Android (Phone / Tablet)

**Requirements:** Android Studio (or just the Android SDK), a device or emulator with API 21+.

```bash
# List connected devices and running emulators
flutter devices

# Launch an Android emulator
flutter emulators --launch Pixel_8_API_35

# Run on the emulator
flutter run -d emulator-5554

# Or run on a physical Android device connected via USB
# (Enable Developer Options > USB Debugging on the device first)
flutter run -d <your-device-id>
```

**Biometric testing on emulator:** In Android Studio's emulator, open **Extended Controls** (three dots) > **Fingerprint** and tap "Touch Sensor" to simulate a fingerprint scan.

**Biometric testing on device:** Uses your real fingerprint or face unlock natively.

```bash
# Build a debug APK for sideloading
flutter build apk --debug
# Output: build/app/outputs/flutter-apk/app-debug.apk

# Build a release APK
flutter build apk --release

# Build an App Bundle for Google Play
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

> **Note:** Release builds require a signing keystore. See the [Flutter Android deployment guide](https://docs.flutter.dev/deployment/android) for keystore setup.

### Web (Chrome / any browser)

**Requirements:** Chrome (or any modern browser). No additional setup needed.

```bash
# Run in Chrome with hot reload
flutter run -d chrome

# Run on a specific port
flutter run -d chrome --web-port=8080

# Build for production deployment
flutter build web --release
# Output: build/web/ (deploy this folder to any static host)
```

**Notes:** Biometric auth is not available on web — the onboarding biometric step will auto-advance. The local shelf server runs in the same browser context. The encrypted SQLite database falls back to an in-memory implementation on web.

### macOS (Desktop)

**Requirements:** macOS, Xcode 16+ (for compilation).

```bash
# Enable macOS desktop support (one-time)
flutter config --enable-macos-desktop

# Run the macOS app
flutter run -d macos

# Build a release .app bundle
flutter build macos --release
# Output: build/macos/Build/Products/Release/trulana.app
```

**Notes:** Biometric auth uses Touch ID on MacBooks with Touch ID, or falls back gracefully on Macs without it. The app runs in a native Cocoa window with the full glassmorphism UI.

### Linux (Desktop)

**Requirements:** A Linux distribution with GTK 3, `clang`, `cmake`, `ninja-build`, `pkg-config`, and `libgtk-3-dev`.

```bash
# Install Linux build dependencies (Ubuntu/Debian)
sudo apt update
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev

# Enable Linux desktop support (one-time)
flutter config --enable-linux-desktop

# Run the Linux app
flutter run -d linux

# Build a release binary
flutter build linux --release
# Output: build/linux/x64/release/bundle/
```

**Notes:** Biometric auth is not available on Linux — the onboarding step will auto-advance. Secure storage uses libsecret (GNOME Keyring / KWallet).

### Windows (Desktop)

**Requirements:** Windows 10/11, Visual Studio 2022 with the "Desktop development with C++" workload.

```bash
# Enable Windows desktop support (one-time)
flutter config --enable-windows-desktop

# Run the Windows app
flutter run -d windows

# Build a release executable
flutter build windows --release
# Output: build/windows/x64/runner/Release/
```

**Notes:** Biometric auth uses Windows Hello if available. Secure storage uses the Windows Credential Manager. The app runs as a native Win32 window.

---

## Quick Reference: Run on All Platforms

```bash
# See every device/emulator available right now
flutter devices

# Run on a specific device by name or ID
flutter run -d <device>

# Run on ALL connected devices simultaneously
flutter run -d all
```

---

## Building for Release (All Platforms)

| Platform | Command | Output |
|----------|---------|--------|
| iOS | `flutter build ios --release` | Xcode archive |
| Android APK | `flutter build apk --release` | `build/app/outputs/flutter-apk/` |
| Android Bundle | `flutter build appbundle --release` | `build/app/outputs/bundle/release/` |
| Web | `flutter build web --release` | `build/web/` |
| macOS | `flutter build macos --release` | `build/macos/.../trulana.app` |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/` |

## Local API Server

When running, Trulana starts a local HTTP server on `localhost:8432`. Third-party apps interact via three endpoints:

| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/api/v1/auth/request` | POST | None | Agent handshake, returns scoped access token |
| `/api/v1/context/query` | POST | Bearer token | Query the vault, response sanitized by Auto-Redact Engine |
| `/api/v1/monetize/lease_offer` | POST | Bearer token | Propose a data lease, logged for user approval |

## Running the MVP Demo

The MVP proves the full loop: auth -> token -> vault query -> redact -> response -> audit log.

```bash
# Terminal 1: start the app (launches REST server on :8432)
flutter run -d macos

# Terminal 2: run the 38-check REST verification gate
./scripts/demo_client.sh

# MCP mode (build release first)
flutter build macos --release
./scripts/test_mcp.sh          # 18-check MCP verification against release binary
./scripts/test_mcp.sh --debug  # against debug binary (warns on expected stdout noise)
```

MCP client config (Claude Desktop / Cursor):
```json
{
  "mcpServers": {
    "trulana": {
      "command": "/absolute/path/to/trulana.app/Contents/MacOS/trulana",
      "env": {"SOVEREIGN_MCP": "1"}
    }
  }
}
```

## Running Tests

```bash
# Run all 117 unit + integration tests
flutter test

# Subsets
flutter test test/engine/          # redaction pipeline (72 tests)
flutter test test/security/        # log hygiene + auth consistency (11 tests)
flutter test test/integration/     # full service loop E2E (14 tests)
```

## Current Limits

These are known, documented, and scoped for future work. None are bugs.

**Scope enforcement is not yet complete.** Agents request scopes (e.g. `context.read`) during auth, and scopes are recorded in the token grant and database. But query-time enforcement does not check whether the token's granted scopes authorize the specific query being made. Any valid token can query any vault context. The redaction engine still applies regardless, so data is never returned unfiltered — but a `context.read` token is not currently distinguishable from a hypothetical `health.read` token at the policy layer.

**MCP uses a local-process trust model.** The MCP adapter runs as a subprocess launched by the MCP client (Claude Desktop, Cursor, etc.). Any process on the local machine that can invoke the Trulana binary with `SOVEREIGN_MCP=1` can start an MCP session. Access is still gated by `AuthService` — the agent must call `trulana_request_access` with valid fields to receive a token before any query is accepted. Every access attempt is written to the encrypted audit log. But there is no cryptographic verification of the calling process identity. This is consistent with how all MCP servers operate today, but it means local process isolation is the trust boundary, not application-level authentication.

**MCP per-agent rate limiting is not yet enforced.** The REST transport applies a sliding-window rate limiter (60 requests/minute per agent) via shelf middleware. The MCP transport does not enforce per-agent rate limits because rate limiting currently lives in the HTTP middleware layer, not in the shared services. A malicious MCP caller could issue unlimited queries within a session. Mitigating factor: MCP is local-process only (not network-exposed), and every query is still audited and redacted.

## Privacy & Security

- **Zero cloud storage:** All data encrypted locally. Encryption keys live in hardware Secure Enclave / KeyStore.
- **Biometric-only access:** No passwords, no accounts. The app unlocks via Face ID or fingerprint.
- **Auto-Redact Engine:** Every outbound response passes through a 3-stage PII stripping pipeline.
- **Localhost-only API:** The shelf server binds exclusively to 127.0.0.1 and rejects non-loopback connections.
- **Token-scoped access:** Each authorized agent receives a 15-minute TTL token limited to approved scopes.

See [SECURITY.md](SECURITY.md) for the full security model, trust boundaries, and release checklist.

See [PRIVACY_POLICY.md](PRIVACY_POLICY.md) for the full privacy policy.

## License

MIT License. See [LICENSE](LICENSE) for details.
