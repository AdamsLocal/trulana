# Changelog

All notable changes to Trulana will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-03-07

### Added

- **Local Context Vault** — Encrypted SQLite database with hardware-backed key storage (Secure Enclave on iOS, KeyStore on Android).
- **5-step onboarding flow** — Biometric lock, engine initialization, data stream toggles, privacy threshold slider, and monetization opt-in.
- **Main Dashboard** — Vault status with sonar pulse animation, horizontal active connections carousel, and monetization hub with earnings display.
- **Gatekeeper Protocol** — Real-time audit log of all third-party data requests with approve/deny/revoke controls.
- **Auto-Redact Engine** — 3-stage PII sanitization pipeline:
  - Stage 1: Regex filter for SSNs, emails, phone numbers, credit cards, IP addresses.
  - Stage 2: Mock NER processor with swappable interface for future on-device AI (llama.cpp / AICore).
  - Stage 3: Privacy filter with Standard, Strict, and Paranoid levels.
- **Local API Server** — Shelf-based HTTP server on localhost:8432 with three endpoints:
  - `POST /api/v1/auth/request` — Agent handshake and scoped token generation.
  - `POST /api/v1/context/query` — Queries processed through the Auto-Redact Engine.
  - `POST /api/v1/monetize/lease_offer` — Data lease proposals logged for user approval.
- **Security middleware** — Bearer token authentication, content-type validation, sliding-window rate limiter (60 req/min per agent), localhost-only binding.
- **Token management** — In-memory token store with 15-minute TTL, scope validation, and per-agent revocation.
- **Anamorphic glassmorphism UI** — Frosted glass cards with backdrop blur, animated mesh gradient backgrounds, sonar pulse indicators, staggered card entrance animations.
- **72 unit tests** covering the Auto-Redact Engine (regex filter, NER processor, privacy filter, full pipeline integration).
- Privacy policy, MIT license, and app store metadata.
