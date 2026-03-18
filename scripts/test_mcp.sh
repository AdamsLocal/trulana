#!/usr/bin/env bash
set -uo pipefail
#
# Trulana MCP — stdio verification gate
#
# Validates the full MCP loop and asserts clean stdout (no non-JSON
# contamination). Exits non-zero on any failure.
#
# Usage:
#   ./scripts/test_mcp.sh                     # uses Release, falls back to Debug
#   ./scripts/test_mcp.sh --debug             # forces Debug binary
#   ./scripts/test_mcp.sh /path/to/trulana  # explicit binary

RELEASE_BIN="build/macos/Build/Products/Release/trulana.app/Contents/MacOS/trulana"
DEBUG_BIN="build/macos/Build/Products/Debug/trulana.app/Contents/MacOS/trulana"
PASS=0
FAIL=0
FIFO=""
STDOUT_LOG=""
MCP_PID=""
BUILD_TYPE=""

pass() { PASS=$((PASS + 1)); printf "  \033[32mPASS\033[0m  %s\n" "$1"; }
fail() { FAIL=$((FAIL + 1)); printf "  \033[31mFAIL\033[0m  %s\n" "$1"; }
section() { printf "\n\033[1m\033[36m─── %s\033[0m\n" "$1"; }
warn() { printf "  \033[33mWARN\033[0m  %s\n" "$1"; }

cleanup() {
  [ -n "$MCP_PID" ] && kill "$MCP_PID" 2>/dev/null && wait "$MCP_PID" 2>/dev/null
  exec 3>&- 2>/dev/null
  rm -f "$FIFO" "$STDOUT_LOG"
}
trap cleanup EXIT

# ── Resolve binary ───────────────────────────────────────────────

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
  printf "\033[31mFATAL:\033[0m No binary found.\n"
  printf "Run:  flutter build macos --release\n"
  printf " or:  flutter build macos --debug\n"
  exit 1
fi

if [ ! -x "$TRULANA_BIN" ]; then
  printf "\033[31mFATAL:\033[0m Binary not executable: %s\n" "$TRULANA_BIN"
  exit 1
fi

printf "\033[1mTrulana MCP Verification Gate\033[0m\n"
printf "\033[2mBinary: %s (%s)\033[0m\n" "$TRULANA_BIN" "$BUILD_TYPE"

# ── Start MCP process ────────────────────────────────────────────

FIFO=$(mktemp -u)
STDOUT_LOG=$(mktemp)
mkfifo "$FIFO"
TRULANA_MCP=1 "$TRULANA_BIN" < "$FIFO" > "$STDOUT_LOG" 2>/dev/null &
MCP_PID=$!
exec 3>"$FIFO"
sleep 3

# ═══════════════════════════════════════════════════════════════
section "Stdout cleanliness (pre-flight)"

# Before sending any message, check if the process already wrote
# non-JSON garbage to stdout during startup.
PRE_LINES=$(wc -l < "$STDOUT_LOG" | tr -d ' ')

if [ "$PRE_LINES" -eq 0 ]; then
  pass "No stdout output before first message"
else
  # Check if every pre-message line is valid JSON
  DIRTY=0
  while IFS= read -r line; do
    if ! echo "$line" | grep -q '^{.*}$'; then
      DIRTY=1
      break
    fi
  done < "$STDOUT_LOG"

  if [ "$DIRTY" -eq 1 ]; then
    if [ "$BUILD_TYPE" = "debug" ]; then
      warn "Debug build emitted $PRE_LINES line(s) to stdout before first message (expected in debug)"
    else
      fail "Non-JSON output on stdout before first message ($PRE_LINES lines)"
      head -3 "$STDOUT_LOG" | while IFS= read -r l; do printf "    > %s\n" "$l"; done
    fi
  else
    pass "Pre-message stdout lines are valid JSON ($PRE_LINES)"
  fi
fi

# ═══════════════════════════════════════════════════════════════
section "Initialize"
echo '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' >&3
sleep 1

INIT_LINE=$(grep '"id":1' "$STDOUT_LOG" | tail -1)
if echo "$INIT_LINE" | grep -q '"trulana"'; then
  pass "Server identified as trulana"
else
  fail "Server name not found in initialize response"
fi

if echo "$INIT_LINE" | grep -q '"protocolVersion"'; then
  pass "Protocol version present"
else
  fail "Protocol version missing"
fi

# ═══════════════════════════════════════════════════════════════
section "tools/list"
echo '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' >&3
sleep 1

LIST_LINE=$(grep '"id":2' "$STDOUT_LOG" | tail -1)
if echo "$LIST_LINE" | grep -q 'sovereign_request_access'; then
  pass "sovereign_request_access listed"
else
  fail "sovereign_request_access not found"
fi

if echo "$LIST_LINE" | grep -q 'sovereign_query_context'; then
  pass "sovereign_query_context listed"
else
  fail "sovereign_query_context not found"
fi

if echo "$LIST_LINE" | grep -q '"inputSchema"'; then
  pass "Tool schemas included"
else
  fail "Tool schemas missing"
fi

# ═══════════════════════════════════════════════════════════════
section "sovereign_request_access"
echo '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"sovereign_request_access","arguments":{"app_id":"mcp-test","app_name":"MCP Test","scopes":["context.read"],"intent":"verification"}}}' >&3
sleep 2

AUTH_LINE=$(grep '"id":3' "$STDOUT_LOG" | tail -1)
TOKEN=$(echo "$AUTH_LINE" | grep -oE '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' | head -1)

if [ -n "$TOKEN" ]; then
  pass "Token received (${TOKEN:0:8}…)"
else
  fail "No access_token in auth response"
  printf "    Response: %s\n" "$AUTH_LINE"
  printf "\n\033[31mCannot continue without a token.\033[0m\n"
  exit 1
fi

if echo "$AUTH_LINE" | grep -q '"isError":false'; then
  pass "isError is false"
else
  fail "isError not false in success response"
fi

# ═══════════════════════════════════════════════════════════════
section "sovereign_query_context — morning routine"
echo "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"sovereign_query_context\",\"arguments\":{\"access_token\":\"$TOKEN\",\"query\":\"morning routine\"}}}" >&3
sleep 2

QUERY_LINE=$(grep '"id":4' "$STDOUT_LOG" | tail -1)
QUERY_UNESC=$(echo "$QUERY_LINE" | sed 's/\\"/"/g; s/\\\\/\\/g')

if echo "$QUERY_UNESC" | grep -q 'REDACTED\|GENERALIZED\|LOCATION\|PERSON\|ORGANIZATION'; then
  pass "Redaction markers present"
else
  fail "No redaction markers found"
  printf "    Response: %s\n" "$QUERY_LINE"
fi

if echo "$QUERY_UNESC" | grep -qF 'michael.fit@gmail.com'; then
  fail "Raw email leaked"
else
  pass "Raw email not leaked"
fi

if echo "$QUERY_UNESC" | grep -qF 'San Francisco'; then
  fail "Raw city leaked"
else
  pass "Raw city not leaked"
fi

if echo "$QUERY_UNESC" | grep -qF '6:30 AM'; then
  fail "Raw time leaked"
else
  pass "Raw time not leaked"
fi

if echo "$QUERY_UNESC" | grep -q 'redactions_applied'; then
  pass "Redaction count present"
else
  fail "Redaction count missing"
fi

# ═══════════════════════════════════════════════════════════════
section "sovereign_query_context — work (SSN + org)"
echo "{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"tools/call\",\"params\":{\"name\":\"sovereign_query_context\",\"arguments\":{\"access_token\":\"$TOKEN\",\"query\":\"work colleagues\"}}}" >&3
sleep 2

WORK_LINE=$(grep '"id":7' "$STDOUT_LOG" | tail -1)
WORK_UNESC=$(echo "$WORK_LINE" | sed 's/\\"/"/g; s/\\\\/\\/g')

if echo "$WORK_UNESC" | grep -q 'SSN REDACTED'; then
  pass "SSN was redacted"
else
  fail "SSN not redacted"
fi

if echo "$WORK_UNESC" | grep -qF '478-33-9182'; then
  fail "Raw SSN leaked"
else
  pass "Raw SSN not leaked"
fi

# ═══════════════════════════════════════════════════════════════
section "sovereign_query_context — invalid token"
echo '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"sovereign_query_context","arguments":{"access_token":"bad-token","query":"test"}}}' >&3
sleep 1

BAD_LINE=$(grep '"id":5' "$STDOUT_LOG" | tail -1)
if echo "$BAD_LINE" | grep -q '"isError":true'; then
  pass "Invalid token rejected"
else
  fail "Invalid token not rejected"
fi

# ═══════════════════════════════════════════════════════════════
section "sovereign_request_access — missing fields"
echo '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"sovereign_request_access","arguments":{"app_id":"incomplete"}}}' >&3
sleep 1

BAD_AUTH_LINE=$(grep '"id":6' "$STDOUT_LOG" | tail -1)
if echo "$BAD_AUTH_LINE" | grep -q '"isError":true'; then
  pass "Incomplete auth rejected"
else
  fail "Incomplete auth not rejected"
fi

# ═══════════════════════════════════════════════════════════════
section "Stdout integrity (post-flight)"

# Every line in stdout must be valid JSON (starts with { ends with })
TOTAL_LINES=$(wc -l < "$STDOUT_LOG" | tr -d ' ')
BAD_LINES=0
while IFS= read -r line; do
  if [ -n "$line" ] && ! echo "$line" | grep -q '^{.*}$'; then
    BAD_LINES=$((BAD_LINES + 1))
  fi
done < "$STDOUT_LOG"

if [ "$BAD_LINES" -eq 0 ]; then
  pass "All $TOTAL_LINES stdout lines are valid JSON"
else
  if [ "$BUILD_TYPE" = "debug" ]; then
    warn "$BAD_LINES of $TOTAL_LINES stdout lines are non-JSON (debug build)"
  else
    fail "$BAD_LINES of $TOTAL_LINES stdout lines are non-JSON"
  fi
fi

# ═══════════════════════════════════════════════════════════════
TOTAL=$((PASS + FAIL))
printf "\n\033[1m══════════════════════════════════════\033[0m\n"
if [ "$FAIL" -eq 0 ]; then
  printf "\033[32m\033[1mALL %d MCP CHECKS PASSED\033[0m" "$TOTAL"
  [ "$BUILD_TYPE" = "release" ] && printf " \033[32m(release)\033[0m"
  printf "\n"
else
  printf "\033[32m%d passed\033[0m, \033[31m\033[1m%d FAILED\033[0m out of %d" "$PASS" "$FAIL" "$TOTAL"
  [ "$BUILD_TYPE" = "release" ] && printf " \033[31m(release)\033[0m"
  printf "\n"
fi
printf "\033[1m══════════════════════════════════════\033[0m\n\n"

[ "$FAIL" -eq 0 ]
