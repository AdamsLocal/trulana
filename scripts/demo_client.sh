#!/usr/bin/env bash
set -euo pipefail
#
# Sovereign MVP — Verification Gate
#
# Proves the full API loop and exits non-zero on any failure.
# No python3, no jq — only curl, grep, and sed.
#
# Usage:
#   flutter run -d macos          # terminal 1
#   ./scripts/demo_client.sh      # terminal 2
#
# CI usage:
#   ./scripts/demo_client.sh || exit 1

BASE="http://localhost:8432"
TIMEOUT=5
PASS=0
FAIL=0

# ── helpers ──────────────────────────────────────────────────────────

pass() {
  PASS=$((PASS + 1))
  printf "  \033[32mPASS\033[0m  %s\n" "$1"
}

fail() {
  FAIL=$((FAIL + 1))
  printf "  \033[31mFAIL\033[0m  %s\n" "$1"
}

section() {
  printf "\n\033[1m\033[36m─── %s\033[0m\n" "$1"
}

# Extract a top-level JSON string value using grep+sed.
# Works for simple flat JSON — not a general parser.
json_str() {
  local body="$1" key="$2"
  echo "$body" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*\"//" | sed 's/"$//'
}

# Extract a top-level JSON number value.
json_num() {
  local body="$1" key="$2"
  echo "$body" | grep -o "\"${key}\"[[:space:]]*:[[:space:]]*[0-9]*" \
    | sed "s/\"${key}\"[[:space:]]*:[[:space:]]*//"
}

assert_eq() {
  local actual="$1" expected="$2" label="$3"
  if [ "$actual" = "$expected" ]; then
    pass "$label"
  else
    fail "$label (expected '$expected', got '$actual')"
  fi
}

assert_gt() {
  local actual="$1" threshold="$2" label="$3"
  if [ "$actual" -gt "$threshold" ] 2>/dev/null; then
    pass "$label ($actual)"
  else
    fail "$label (expected > $threshold, got '$actual')"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    pass "$label"
  else
    fail "$label ('$needle' not found)"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  if echo "$haystack" | grep -qF "$needle"; then
    fail "$label (leaked: '$needle')"
  else
    pass "$label"
  fi
}

# ── pre-flight ───────────────────────────────────────────────────────

printf "\033[1mSovereign Verification Gate\033[0m\n"
printf "\033[2mTarget: %s\033[0m\n" "$BASE"

if ! curl -sf --max-time 3 "$BASE/api/v1/health" >/dev/null 2>&1; then
  printf "\n\033[31m\033[1mFATAL:\033[0m Server not reachable at %s\n" "$BASE"
  printf "Start the app first:  flutter run -d macos\n\n"
  exit 1
fi

# ═════════════════════════════════════════════════════════════════════
# 1. Health
# ═════════════════════════════════════════════════════════════════════
section "Health check"

HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$BASE/api/v1/health")
assert_eq "$HEALTH_CODE" "200" "GET /health returns 200"

HEALTH_BODY=$(curl -s --max-time "$TIMEOUT" "$BASE/api/v1/health")
assert_contains "$HEALTH_BODY" '"status":"ok"' "Health body contains status ok"

# ═════════════════════════════════════════════════════════════════════
# 2. Auth — valid request
# ═════════════════════════════════════════════════════════════════════
section "Authenticate agent"

AUTH_BODY=$(curl -s --max-time "$TIMEOUT" -X POST "$BASE/api/v1/auth/request" \
  -H "Content-Type: application/json" \
  -d '{"app_id":"gate-agent","app_name":"Gate Agent","requested_scopes":["context.read"],"intent":"verification gate"}')

assert_contains "$AUTH_BODY" '"status":"success"' "Auth response is success"

TOKEN=$(json_str "$AUTH_BODY" "access_token")
if [ -n "$TOKEN" ]; then
  pass "Token received (${TOKEN:0:8}…)"
else
  fail "No access_token in response"
  printf "\n\033[31mCannot continue without a token. Aborting.\033[0m\n"
  exit 1
fi

# ═════════════════════════════════════════════════════════════════════
# 3. Context query — morning routine
# ═════════════════════════════════════════════════════════════════════
section "Context query — morning routine"

MORNING_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"morning routine"}')
assert_eq "$MORNING_CODE" "200" "HTTP 200"

MORNING=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"morning routine"}')

MORNING_DATA=$(json_str "$MORNING" "data")
MORNING_REDACTIONS=$(json_num "$MORNING" "redactions_applied")

assert_gt "$MORNING_REDACTIONS" 0 "Redactions applied"
assert_contains "$MORNING" '"privacy_level":"strict"' "Privacy level is strict"
assert_contains "$MORNING_DATA" "[EMAIL REDACTED]" "Email was redacted"
assert_contains "$MORNING_DATA" "[PHONE REDACTED]" "Phone was redacted"
assert_contains "$MORNING_DATA" "[LOCATION]" "Location was redacted"
assert_not_contains "$MORNING_DATA" "michael.fit@gmail.com" "Raw email not leaked"
assert_not_contains "$MORNING_DATA" "415-555-0192" "Raw phone not leaked"
assert_not_contains "$MORNING_DATA" "San Francisco" "Raw city not leaked"
assert_not_contains "$MORNING_DATA" "6:30 AM" "Raw time not leaked"

# ═════════════════════════════════════════════════════════════════════
# 4. Context query — work (SSN + multiple entities)
# ═════════════════════════════════════════════════════════════════════
section "Context query — work colleagues"

WORK=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"work colleagues"}')

WORK_DATA=$(json_str "$WORK" "data")
WORK_REDACTIONS=$(json_num "$WORK" "redactions_applied")

assert_gt "$WORK_REDACTIONS" 0 "Redactions applied"
assert_contains "$WORK_DATA" "[SSN REDACTED]" "SSN was redacted"
assert_contains "$WORK_DATA" "[ORGANIZATION]" "Org was redacted"
assert_not_contains "$WORK_DATA" "478-33-9182" "Raw SSN not leaked"
assert_not_contains "$WORK_DATA" "sarah.chen@google.com" "Raw email not leaked"

# ═════════════════════════════════════════════════════════════════════
# 5. Context query — finance (cards + amounts)
# ═════════════════════════════════════════════════════════════════════
section "Context query — financial info"

FIN=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"financial info"}')

FIN_DATA=$(json_str "$FIN" "data")
FIN_REDACTIONS=$(json_num "$FIN" "redactions_applied")

assert_gt "$FIN_REDACTIONS" 0 "Redactions applied"
assert_contains "$FIN_DATA" "[CARD REDACTED]" "Card was redacted"
assert_contains "$FIN_DATA" "[AMOUNT GENERALIZED]" "Amount was generalized"
assert_not_contains "$FIN_DATA" "4111 1111 1111 1234" "Raw card not leaked"
assert_not_contains "$FIN_DATA" "robert.wealth@schwab.com" "Raw email not leaked"

# ═════════════════════════════════════════════════════════════════════
# 6. Context query — health (IP + age)
# ═════════════════════════════════════════════════════════════════════
section "Context query — health"

HEALTH_Q=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"doctor medical"}')

HQ_DATA=$(json_str "$HEALTH_Q" "data")
HQ_REDACTIONS=$(json_num "$HEALTH_Q" "redactions_applied")

assert_gt "$HQ_REDACTIONS" 0 "Redactions applied"
assert_contains "$HQ_DATA" "[IP REDACTED]" "IP was redacted"
assert_contains "$HQ_DATA" "[AGE REDACTED]" "Age was redacted"
assert_not_contains "$HQ_DATA" "192.168.1.42" "Raw IP not leaked"
assert_not_contains "$HQ_DATA" "emily.patient@kaiser.org" "Raw email not leaked"

# ═════════════════════════════════════════════════════════════════════
# 7. No match — fallback
# ═════════════════════════════════════════════════════════════════════
section "No vault match — fallback"

NOMATCH=$(curl -s --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"query":"random weather question"}')

NOMATCH_REDACTIONS=$(json_num "$NOMATCH" "redactions_applied")
assert_eq "$NOMATCH_REDACTIONS" "0" "Zero redactions on clean text"
assert_contains "$NOMATCH" "random weather question" "Query echoed back"

# ═════════════════════════════════════════════════════════════════════
# 8. Rejection — missing token
# ═════════════════════════════════════════════════════════════════════
section "Rejection — missing token"

NO_TOKEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -d '{"query":"test"}')
assert_eq "$NO_TOKEN_CODE" "401" "Returns 401"

# ═════════════════════════════════════════════════════════════════════
# 9. Rejection — invalid token
# ═════════════════════════════════════════════════════════════════════
section "Rejection — invalid token"

BAD_TOKEN_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer not-a-real-token" \
  -d '{"query":"test"}')
assert_eq "$BAD_TOKEN_CODE" "401" "Returns 401"

# ═════════════════════════════════════════════════════════════════════
# 10. Rejection — incomplete auth
# ═════════════════════════════════════════════════════════════════════
section "Rejection — incomplete auth"

BAD_AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/auth/request" \
  -H "Content-Type: application/json" \
  -d '{"app_id":"incomplete"}')
assert_eq "$BAD_AUTH_CODE" "400" "Returns 400"

# ═════════════════════════════════════════════════════════════════════
# 11. Rejection — wrong content type
# ═════════════════════════════════════════════════════════════════════
section "Rejection — wrong content type"

CONTENT_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/auth/request" \
  -H "Content-Type: text/plain" \
  -d 'not json')
assert_eq "$CONTENT_CODE" "415" "Returns 415"

# ═════════════════════════════════════════════════════════════════════
# 12. Token expiry (debug TTL) — optional
# ═════════════════════════════════════════════════════════════════════
section "Token expiry (3-second debug TTL)"

SHORT_AUTH=$(curl -s --max-time "$TIMEOUT" -X POST "$BASE/api/v1/auth/request" \
  -H "Content-Type: application/json" \
  -d '{"app_id":"expiry-gate","app_name":"Expiry Gate","requested_scopes":["context.read"],"intent":"TTL test","debug_ttl_seconds":3}')

SHORT_TOKEN=$(json_str "$SHORT_AUTH" "access_token")
SHORT_TTL=$(json_num "$SHORT_AUTH" "expires_in")
assert_eq "$SHORT_TTL" "3" "Token issued with 3s TTL"

LIVE_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SHORT_TOKEN" \
  -d '{"query":"quick"}')
assert_eq "$LIVE_CODE" "200" "Immediate use returns 200"

printf "  ....  waiting 4s for token to expire\n"
sleep 4

DEAD_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" \
  -X POST "$BASE/api/v1/context/query" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $SHORT_TOKEN" \
  -d '{"query":"too late"}')
assert_eq "$DEAD_CODE" "401" "Expired token returns 401"

# ═════════════════════════════════════════════════════════════════════
# Summary
# ═════════════════════════════════════════════════════════════════════

TOTAL=$((PASS + FAIL))
printf "\n\033[1m══════════════════════════════════════\033[0m\n"
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32m\033[1mALL %d CHECKS PASSED\033[0m\n" "$TOTAL"
else
  printf "\033[32m%d passed\033[0m, \033[31m\033[1m%d FAILED\033[0m out of %d\n" "$PASS" "$FAIL" "$TOTAL"
fi
printf "\033[1m══════════════════════════════════════\033[0m\n\n"

[ "$FAIL" -eq 0 ]
