#!/usr/bin/env bash
set -uo pipefail
#
# Trulana MCP — stdio verification gate
#
# Exercises the Ed25519 challenge/proof flow and asserts clean stdout. The
# first run enrolls a persistent test key and exits with instructions to
# approve its fingerprint in Trulana. Re-run after approval.
#
# Usage:
#   ./scripts/test_mcp.sh                    # Release, then Debug fallback
#   ./scripts/test_mcp.sh --debug            # force Debug binary
#   ./scripts/test_mcp.sh /path/to/trulana   # explicit binary
#
# Optional:
#   TRULANA_MCP_TEST_KEY=/secure/path/key.pem ./scripts/test_mcp.sh

RELEASE_BIN="build/macos/Build/Products/Release/trulana.app/Contents/MacOS/trulana"
DEBUG_BIN="build/macos/Build/Products/Debug/trulana.app/Contents/MacOS/trulana"
KEY_FILE="${TRULANA_MCP_TEST_KEY:-$HOME/.trulana/mcp-test-ed25519.pem}"
APP_ID="trulana-mcp-verification-v1"
PASS=0
FAIL=0
FIFO=""
STDOUT_LOG=""
PAYLOAD_FILE=""
SIGNATURE_FILE=""
TEMP_DIR=""
MCP_PID=""
BUILD_TYPE=""

pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m  %s\n" "$1"; }
section() { printf "\n\033[1m\033[36m--- %s\033[0m\n" "$1"; }
warn() { printf "  \033[33mWARN\033[0m  %s\n" "$1"; }

cleanup() {
  if [ -n "$MCP_PID" ]; then
    kill "$MCP_PID" 2>/dev/null || true
    wait "$MCP_PID" 2>/dev/null || true
  fi
  exec 3>&- 2>/dev/null || true
  if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}
trap cleanup EXIT

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf "\033[31mFATAL:\033[0m Required command not found: %s\n" "$1"
    exit 1
  fi
}

wait_for_id() {
  local id="$1"
  local attempts=0
  while [ "$attempts" -lt 50 ]; do
    if grep -q "\"id\":$id" "$STDOUT_LOG"; then
      return 0
    fi
    sleep 0.1
    attempts=$((attempts + 1))
  done
  return 1
}

response_for_id() {
  local id="$1"
  grep "\"id\":$id" "$STDOUT_LOG" | tail -1
}

tool_text_for_id() {
  local id="$1"
  python3 - "$STDOUT_LOG" "$id" <<'PY'
import json
import sys

path, wanted = sys.argv[1], int(sys.argv[2])
result = ""
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get("id") != wanted:
            continue
        content = message.get("result", {}).get("content", [])
        if content and isinstance(content[0], dict):
            result = content[0].get("text", "")
print(result)
PY
}

tool_is_error() {
  local id="$1"
  python3 - "$STDOUT_LOG" "$id" <<'PY'
import json
import sys

path, wanted = sys.argv[1], int(sys.argv[2])
with open(path, "r", encoding="utf-8") as handle:
    for line in handle:
        try:
            message = json.loads(line)
        except json.JSONDecodeError:
            continue
        if message.get("id") == wanted:
            print("true" if message.get("result", {}).get("isError") is True else "false")
            raise SystemExit
print("missing")
PY
}

base64url_file() {
  openssl base64 -A -in "$1" | tr '+/' '-_' | tr -d '='
}

require_command python3
require_command openssl
require_command mkfifo

# Resolve the application binary.
if [ "${1:-}" = "--debug" ]; then
  TRULANA_BIN="$DEBUG_BIN"
  BUILD_TYPE="debug"
elif [ -n "${1:-}" ]; then
  TRULANA_BIN="$1"
  BUILD_TYPE="custom"
elif [ -x "$RELEASE_BIN" ]; then
  TRULANA_BIN="$RELEASE_BIN"
  BUILD_TYPE="release"
elif [ -x "$DEBUG_BIN" ]; then
  TRULANA_BIN="$DEBUG_BIN"
  BUILD_TYPE="debug"
else
  printf "\033[31mFATAL:\033[0m No binary found. Build Trulana first.\n"
  exit 1
fi

if [ ! -x "$TRULANA_BIN" ]; then
  printf "\033[31mFATAL:\033[0m Binary not executable: %s\n" "$TRULANA_BIN"
  exit 1
fi

# The test identity must survive the first enrollment run so the user can
# approve exactly the key used by the second verification run.
umask 077
KEY_DIR=$(dirname "$KEY_FILE")
if [ "$KEY_DIR" != "." ]; then
  mkdir -p "$KEY_DIR"
  chmod 700 "$KEY_DIR"
fi
if [ ! -f "$KEY_FILE" ]; then
  if ! openssl genpkey -algorithm ED25519 -out "$KEY_FILE" >/dev/null 2>&1; then
    printf "\033[31mFATAL:\033[0m OpenSSL with Ed25519 support is required.\n"
    exit 1
  fi
fi
chmod 600 "$KEY_FILE"

PUBLIC_DER=$(mktemp)
if ! openssl pkey -in "$KEY_FILE" -pubout -outform DER -out "$PUBLIC_DER" >/dev/null 2>&1; then
  printf "\033[31mFATAL:\033[0m Could not read Ed25519 test key: %s\n" "$KEY_FILE"
  rm -f "$PUBLIC_DER"
  exit 1
fi
PUBLIC_KEY=$(tail -c 32 "$PUBLIC_DER" | openssl base64 -A | tr '+/' '-_' | tr -d '=')
rm -f "$PUBLIC_DER"
if [ "${#PUBLIC_KEY}" -ne 43 ]; then
  printf "\033[31mFATAL:\033[0m Could not derive a raw Ed25519 public key.\n"
  exit 1
fi

printf "\033[1mTrulana MCP Verification Gate\033[0m\n"
printf "\033[2mBinary: %s (%s)\033[0m\n" "$TRULANA_BIN" "$BUILD_TYPE"
printf "\033[2mTest key: %s\033[0m\n" "$KEY_FILE"

# Start the MCP process.
TEMP_DIR=$(mktemp -d)
FIFO="$TEMP_DIR/mcp.stdin"
STDOUT_LOG="$TEMP_DIR/mcp.stdout"
PAYLOAD_FILE="$TEMP_DIR/signing-payload.bin"
SIGNATURE_FILE="$TEMP_DIR/signature.bin"
: > "$STDOUT_LOG"
: > "$PAYLOAD_FILE"
: > "$SIGNATURE_FILE"
mkfifo "$FIFO"
TRULANA_MCP=1 "$TRULANA_BIN" < "$FIFO" > "$STDOUT_LOG" 2>/dev/null &
MCP_PID=$!
exec 3>"$FIFO"
sleep 3

section "Stdout cleanliness (pre-flight)"
PRE_LINES=$(wc -l < "$STDOUT_LOG" | tr -d ' ')
if [ "$PRE_LINES" -eq 0 ]; then
  pass "No stdout output before first message"
elif [ "$BUILD_TYPE" = "debug" ]; then
  warn "Debug build emitted $PRE_LINES pre-message line(s)"
else
  fail "Release stdout was not empty before the first message"
fi

section "Initialize and tools/list"
printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"security-gate","version":"2.0"}}}' >&3
wait_for_id 1 || fail "Initialize response timed out"
INIT_LINE=$(response_for_id 1)
if printf '%s' "$INIT_LINE" | grep -q '"trulana"'; then
  pass "Server identified as trulana"
else
  fail "Server identity missing"
fi

printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' >&3
wait_for_id 2 || fail "tools/list response timed out"
LIST_LINE=$(response_for_id 2)
for tool in sovereign_auth_challenge sovereign_auth_prove sovereign_query_context; do
  if printf '%s' "$LIST_LINE" | grep -q "$tool"; then
    pass "$tool listed"
  else
    fail "$tool missing"
  fi
done
if printf '%s' "$LIST_LINE" | grep -q 'sovereign_request_access'; then
  fail "Legacy app-ID-only authentication is still advertised"
else
  pass "Legacy app-ID-only authentication is not advertised"
fi

section "Ed25519 challenge"
printf '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"sovereign_auth_challenge","arguments":{"app_id":"%s","app_name":"MCP Verification Gate","scopes":["context.read"],"intent":"security verification","public_key":"%s"}}}\n' "$APP_ID" "$PUBLIC_KEY" >&3
wait_for_id 3 || fail "Challenge response timed out"
CHALLENGE_TEXT=$(tool_text_for_id 3)
CHALLENGE_ID=$(printf '%s' "$CHALLENGE_TEXT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("challenge_id", ""))' 2>/dev/null || true)
SIGNING_PAYLOAD=$(printf '%s' "$CHALLENGE_TEXT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("signing_payload", ""))' 2>/dev/null || true)

if [ -z "$CHALLENGE_ID" ] || [ -z "$SIGNING_PAYLOAD" ]; then
  FINGERPRINT=$(printf '%s' "$CHALLENGE_TEXT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("public_key_fingerprint", ""))' 2>/dev/null || true)
  printf "\n\033[33mEnrollment is not active yet.\033[0m\n"
  if [ -n "$FINGERPRINT" ]; then
    printf "Approve this exact fingerprint in Trulana Gatekeeper:\n  %s\n" "$FINGERPRINT"
  else
    printf "Open Trulana Gatekeeper and approve '%s', then rerun.\n" "$APP_ID"
    printf "Server response: %s\n" "$CHALLENGE_TEXT"
  fi
  printf "The test key is retained at: %s\n" "$KEY_FILE"
  exit 2
fi
pass "Fresh challenge returned"

python3 - "$SIGNING_PAYLOAD" "$PAYLOAD_FILE" <<'PY'
import base64
import sys

encoded, output = sys.argv[1], sys.argv[2]
encoded += "=" * ((4 - len(encoded) % 4) % 4)
with open(output, "wb") as handle:
    handle.write(base64.urlsafe_b64decode(encoded))
PY

if ! openssl pkeyutl -sign -rawin -inkey "$KEY_FILE" -in "$PAYLOAD_FILE" -out "$SIGNATURE_FILE" 2>/dev/null; then
  printf "\033[31mFATAL:\033[0m OpenSSL could not create a raw Ed25519 signature.\n"
  exit 1
fi
SIGNATURE=$(base64url_file "$SIGNATURE_FILE")

section "Ed25519 proof and replay rejection"
printf '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"sovereign_auth_prove","arguments":{"challenge_id":"%s","signature":"%s"}}}\n' "$CHALLENGE_ID" "$SIGNATURE" >&3
wait_for_id 4 || fail "Proof response timed out"
PROOF_TEXT=$(tool_text_for_id 4)
TOKEN=$(printf '%s' "$PROOF_TEXT" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("access_token", ""))' 2>/dev/null || true)
if [ -n "$TOKEN" ] && [ "$(tool_is_error 4)" = "false" ]; then
  pass "Valid key proof minted a token"
else
  fail "Valid key proof did not mint a token"
  printf "    Response: %s\n" "$PROOF_TEXT"
  exit 1
fi

printf '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"sovereign_auth_prove","arguments":{"challenge_id":"%s","signature":"%s"}}}\n' "$CHALLENGE_ID" "$SIGNATURE" >&3
wait_for_id 5 || fail "Replay response timed out"
if [ "$(tool_is_error 5)" = "true" ]; then
  pass "Consumed challenge replay rejected"
else
  fail "Consumed challenge replay accepted"
fi

section "Legacy path fails closed"
printf '%s\n' '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"sovereign_request_access","arguments":{"app_id":"trulana-mcp-verification-v1","app_name":"MCP Verification Gate","scopes":["context.read"],"intent":"legacy bypass test"}}}' >&3
wait_for_id 6 || fail "Legacy-path response timed out"
if [ "$(tool_is_error 6)" = "true" ]; then
  pass "Legacy app-ID-only token request rejected"
else
  fail "Legacy app-ID-only token request accepted"
fi

section "Authorized context query"
printf '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"sovereign_query_context","arguments":{"access_token":"%s","query":"morning routine"}}}\n' "$TOKEN" >&3
wait_for_id 7 || fail "Context query response timed out"
QUERY_TEXT=$(tool_text_for_id 7)
if [ "$(tool_is_error 7)" = "false" ]; then
  pass "Proof-derived token authorized a context query"
else
  fail "Proof-derived token was rejected"
fi
if printf '%s' "$QUERY_TEXT" | grep -q 'REDACTED\|GENERALIZED\|LOCATION\|PERSON\|ORGANIZATION'; then
  pass "Redaction markers present"
else
  fail "No redaction markers found"
fi
for secret in 'michael.fit@gmail.com' 'San Francisco' '6:30 AM' '478-33-9182'; do
  if printf '%s' "$QUERY_TEXT" | grep -qF "$secret"; then
    fail "Raw fixture value leaked: $secret"
  else
    pass "Raw fixture value withheld: $secret"
  fi
done

section "Invalid token and malformed enrollment"
printf '%s\n' '{"jsonrpc":"2.0","id":8,"method":"tools/call","params":{"name":"sovereign_query_context","arguments":{"access_token":"bad-token","query":"test"}}}' >&3
wait_for_id 8 || fail "Invalid-token response timed out"
if [ "$(tool_is_error 8)" = "true" ]; then
  pass "Invalid token rejected"
else
  fail "Invalid token accepted"
fi

printf '%s\n' '{"jsonrpc":"2.0","id":9,"method":"tools/call","params":{"name":"sovereign_auth_challenge","arguments":{"app_id":"incomplete"}}}' >&3
wait_for_id 9 || fail "Malformed-enrollment response timed out"
if [ "$(tool_is_error 9)" = "true" ]; then
  pass "Incomplete key enrollment rejected"
else
  fail "Incomplete key enrollment accepted"
fi

section "Stdout integrity (post-flight)"
TOTAL_LINES=$(wc -l < "$STDOUT_LOG" | tr -d ' ')
BAD_LINES=$(python3 - "$STDOUT_LOG" <<'PY'
import json
import sys

bad = 0
with open(sys.argv[1], "r", encoding="utf-8") as handle:
    for line in handle:
        if not line.strip():
            continue
        try:
            json.loads(line)
        except json.JSONDecodeError:
            bad += 1
print(bad)
PY
)
if [ "$BAD_LINES" -eq 0 ]; then
  pass "All $TOTAL_LINES stdout lines are valid JSON"
elif [ "$BUILD_TYPE" = "debug" ]; then
  warn "$BAD_LINES debug stdout line(s) were non-JSON"
else
  fail "$BAD_LINES release stdout line(s) were non-JSON"
fi

TOTAL=$((PASS + FAIL))
printf "\n\033[1m======================================\033[0m\n"
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32m\033[1mALL %d MCP CHECKS PASSED\033[0m\n" "$TOTAL"
else
  printf "\033[32m%d passed\033[0m, \033[31m\033[1m%d FAILED\033[0m out of %d\n" "$PASS" "$FAIL" "$TOTAL"
fi
printf "\033[1m======================================\033[0m\n\n"

[ "$FAIL" -eq 0 ]
