# Sovereign Privacy Policy

**Effective Date:** March 2026
**App Name:** Sovereign
**Developer:** Adams Local
**Bundle ID:** com.adamslocal.sovereign

---

## Our Core Principle

Sovereign is built on a single, non-negotiable premise: **your data never leaves your device unless you explicitly approve it.** There is no cloud database, no analytics backend, no telemetry server. Every piece of data Sovereign manages is encrypted and stored locally on your phone's hardware.

---

## 1. Data We Store

All data is stored **exclusively on your device** in an encrypted SQLite database. Encryption keys are held in your device's hardware-level Secure Enclave (iOS) or Android KeyStore and are never transmitted.

| Data Category | Purpose | Storage Location |
|---|---|---|
| Biometric authentication status | Unlock the app vault | Device Secure Enclave / KeyStore (never read by our code) |
| Privacy preferences | Control the Auto-Redact Engine behavior | Local encrypted SQLite |
| Authorized agent list | Track which third-party apps have access | Local encrypted SQLite |
| Audit log | Show you every data request made by external apps | Local encrypted SQLite |
| Ledger / earnings | Track micro-payments from data leasing | Local encrypted SQLite |
| Wallet address (if provided) | Route data leasing payouts | Local encrypted SQLite |

## 2. Data We Collect From You

**None.** Sovereign does not collect, transmit, or store any data on external servers. We do not operate a backend. We do not use analytics SDKs. We do not track app usage, crashes, or behavior.

## 3. Data Shared With Third Parties

Sovereign shares data with third-party apps **only when you explicitly approve a request** through the Gatekeeper interface. Before any data leaves the device:

1. The Auto-Redact Engine strips Personally Identifiable Information (PII) based on your chosen privacy level (Standard, Strict, or Paranoid).
2. You see exactly what data will be shared and to whom.
3. You tap Approve or Deny. There is no default approval.

If you opt into the Data Monetization Hub, anonymized data may be shared with verified brands **only after your explicit approval of each individual lease offer.** You are shown the buyer, the data category, and the price before any data moves.

## 4. Biometric Data

Sovereign uses your device's biometric authentication (Face ID, Touch ID, or fingerprint) solely to unlock the app. We use the platform's `local_auth` API, which means:

- Biometric data is processed entirely by the operating system.
- Sovereign never reads, stores, or transmits biometric data.
- We only receive a boolean "authenticated" or "not authenticated" response.

## 5. Local Network Usage

Sovereign runs a lightweight local HTTP server on `localhost` to allow authorized third-party apps on your device to query your data vault. This server:

- Binds exclusively to the loopback interface (127.0.0.1).
- Rejects any connection from non-localhost sources.
- Requires token-based authentication for every request.
- Rate-limits requests per authorized agent.

No data is transmitted over the internet through this server.

## 6. Health Data

If you choose to connect Apple Health or Google Health Connect, Sovereign reads health metrics locally and stores them in your encrypted on-device vault. This data is:

- Never uploaded to any server.
- Never shared with third parties unless you explicitly approve a specific request.
- Always processed through the Auto-Redact Engine before any external sharing.

## 7. Children's Privacy

Sovereign is not directed at children under 13. We do not knowingly process data from children.

## 8. Data Deletion

Since all data lives on your device, you have complete control:

- **Delete individual records:** Remove specific agents, audit entries, or ledger records from within the app.
- **Full reset:** The app provides a "Delete All Data" option that destroys the encrypted database and its encryption key, making all stored data irrecoverable.
- **Uninstall:** Removing the app from your device deletes all Sovereign data, including the encryption key in the Secure Enclave / KeyStore.

## 9. Changes to This Policy

If we update this privacy policy, the new version will be bundled with the app update. Since we have no server-side user accounts, we cannot send email notifications — the updated policy will be visible in the app and on the App Store listing.

## 10. Contact

For privacy-related questions or concerns:

- **Email:** privacy@adamslocal.com
- **GitHub:** github.com/AdamsLocal/trulana

---

**Summary:** Trulana stores everything locally, encrypts everything, shares nothing without your tap-by-tap approval, and has no backend servers. Your data is sovereign.
