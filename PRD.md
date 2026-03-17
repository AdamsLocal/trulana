# Product Requirements Document (PRD)
**App Name:** Sovereign
**Concept:** Autonomous Personal API and Data Broker
**Date:** March 2026

## 1. Vision & Core Problem
Users suffer from "Context Fragmentation" across dozens of specialized AI agents and are anxious about data privacy and unauthorized scraping. Sovereign solves this by acting as a highly secure, localized Personal API. It holds the user's life context on-device. Third-party apps query Sovereign, which answers on the user's behalf, blocks invasive tracking, and negotiates micro-payments for anonymized data leasing.

## 2. Target Audience
* Millennials and Gen Z "AI Power Users."
* Privacy-conscious professionals.
* Early adopters of spatial computing/wearables who generate massive amounts of personal telemetry.

## 3. Core Features (MVP)
* **The Local Context Vault:** Highly encrypted, edge-computed database syncing locally with wearables, emails, and phone activity.
* **The Gatekeeper Protocol:** Dashboard to view, grant, revoke, or restrict third-party access in real-time.
* **Auto-Redact Engine:** Multi-stage pipeline that automatically strips/obfuscates Personally Identifiable Information (PII) before passing context to external apps.
* **Data Monetization Hub:** Opt-in feature to lease anonymized data to verified brands for fiat/crypto micro-payments.

## 4. Tech Stack & Dependencies
* **Framework:** Flutter or React Native (Cross-platform mobile).
* **Local AI:** Quantized Llama 3 8B or Google Gemma 3 running on-device via Apple CoreML or Android AICore.
* **Execution:** llama.cpp or MLC LLM.
* **Relational DB:** SQLite (highly encrypted via Secure Enclave/KeyStore).
* **Vector DB:** ObjectBox Vector Search or Chroma/Milvus Lite (for local context embeddings).
* **Payments:** Solana/USDC web3 infrastructure or Stripe Connect.

## 5. Relational Database Schema (SQLite)

### `User_Config`
* `id` (UUID, PK)
* `privacy_level` (INTEGER) - 1 (Standard), 2 (Strict), 3 (Paranoid)
* `auto_monetize` (BOOLEAN)
* `wallet_address` (VARCHAR)
* `vault_status` (TIMESTAMP)

### `Authorized_Agents`
* `agent_id` (VARCHAR, PK)
* `agent_name` (VARCHAR)
* `granted_scopes` (JSON)
* `status` (VARCHAR) - ACTIVE, REVOKED, PAUSED
* `expiration_date` (TIMESTAMP)

### `Audit_Log`
* `log_id` (UUID, PK)
* `agent_id` (VARCHAR, FK)
* `request_intent` (VARCHAR)
* `action_taken` (VARCHAR) - APPROVED, BLOCKED, REDACTED, NEGOTIATED
* `timestamp` (TIMESTAMP)

### `Ledger`
* `tx_id` (VARCHAR, PK)
* `buyer_name` (VARCHAR)
* `data_leased` (VARCHAR)
* `amount_usd` (DECIMAL 10,4)
* `timestamp` (TIMESTAMP)

## 6. The Auto-Redact Engine Logic
A 3-step pipeline processing all outbound data:
1. **Regex Filter:** Hardcoded stripping of SSNs, emails, phone numbers.
2. **Local SLM (NER):** Named Entity Recognition to identify context-specific identifiers.
3. **Privacy Filter Application:**
   * *Standard:* Masks exact PII, allows accurate context.
   * *Strict:* Generalizes locations, brands, and specific times.
   * *Paranoid:* Active obfuscation; injects slight noise.

## 7. Local Server API Endpoints
Sovereign runs a local background server to bridge external apps:
* `POST /api/v1/auth/request`: External app requests permission/scopes. Triggers UI modal. Returns temporary Access Token.
* `POST /api/v1/context/query`: Requires Token. Takes query, searches local Vector DB, runs through Auto-Redact Engine, returns sanitized answer.
* `POST /api/v1/monetize/lease_offer`: Brand proposes micro-transaction for data. Logs to Ledger, flags UI for user approval.