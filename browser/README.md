# Trulana browser edition — early release

Contact: adam@adamslocal.net. Copyright 2026 AdamsLocal LLC. MIT License (dist/LICENSE.txt).

This independent, dependency-free browser app provides an encrypted local context vault, text search, deletion, manual redaction review, and encrypted backup/restore. It is not the Flutter macOS app and does not claim desktop feature parity.

## Run and host

Serve `dist/` over HTTPS with any static host. For local development, `python3 -m http.server 8080 --directory dist` and open `http://localhost:8080` (localhost is a secure-context exception). Run `node --test vault.test.mjs` to test encryption and redaction. No install or build step, environment variables, API keys, or backend database is needed.

The `.openai/hosting.json` file belongs to the Sites deployment only. It is not required for other hosts. Keep the site origin stable: browser storage belongs to its origin. Export and restore a backup when changing domains.

## Security and limits

- The saved localStorage envelope contains AES-256-GCM ciphertext, a random 16-byte salt and fresh 12-byte IV, version and KDF metadata. Titles and note contents are encrypted together. PBKDF2-SHA-256 uses 600,000 iterations. The non-extractable encryption key is only retained in memory while unlocked.
- The app locks after five minutes of inactivity; a Web Lock prevents two tabs from concurrently editing the same vault. Locking clears rendered notes, input fields, and the retained key reference, but is not a guarantee of physical memory erasure.
- There are no application network calls or third-party assets. The CSP disables connections. Hosting/authentication infrastructure still receives page request metadata. Compromised hosting can serve changed JavaScript; encryption does not protect an unlocked session against that, malicious extensions, or a compromised browser/device.
- No passphrase recovery. Browser storage can be cleared, evicted, or unavailable in private browsing. Back up regularly. Restore validates and decrypts the backup before replacing anything and asks for confirmation if a vault exists.
- Early limits: 500 entries, 20,000 characters per entry, 120 per title, and 4 MB backup import. Browser quotas can be lower. Storage failures are reported without replacing the in-memory saved state.
- Pattern redaction is a limited aid, not a privacy guarantee. It can miss names, addresses and other sensitive details and can produce false positives. Review/edit before copying. Copying puts plaintext on the system clipboard; the app does not clear other apps' clipboards.
- No native REST or stdio MCP server, external agent connections, semantic search, local AI model, Touch ID, payments, or import from desktop SQLCipher vaults. No service worker/offline restart promise. The vault works while the loaded page remains open, but loading it requires connectivity.
- This is an early implementation, not an independently audited production security product. Automated crypto/redaction tests pass; visual browser inspection is separate from full HTTPS interaction testing.

## Next milestones

1. HTTPS end-to-end tests across Safari/iOS and Chromium, including restore, quota errors and cross-tab locking.
2. Authenticated agent transport design that preserves explicit consent and local custody, rather than exposing the native loopback API publicly.
3. Desktop export interoperability, optional install/offline lifecycle and versioned migrations.
