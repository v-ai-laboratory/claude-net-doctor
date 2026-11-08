#!/usr/bin/env bash
# Functional tests for scripts/check-env.sh.
# Every case runs the checker against a throwaway HOME, so the real
# ~/.claude/settings.json is never read and no network request is sent.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/scripts/check-env.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASSED=0
FAILED=0
CASE_HOME=""
OUTPUT=""
STATUS=0

new_home() {
  CASE_HOME="$(mktemp -d "$TMP/home.XXXXXX")"
  mkdir -p "$CASE_HOME/.claude"
}

settings() {
  printf '%s\n' "$1" > "$CASE_HOME/.claude/settings.json"
}

# Run the checker with a clean network environment plus optional VAR=value pairs.
run_checker() {
  OUTPUT="$(env \
    -u https_proxy -u HTTPS_PROXY -u http_proxy -u HTTP_PROXY \
    -u all_proxy -u ALL_PROXY -u NO_PROXY -u no_proxy \
    -u NODE_EXTRA_CA_CERTS -u CLAUDE_CODE_CERT_STORE \
    -u CLAUDE_CODE_CLIENT_CERT -u CLAUDE_CODE_CLIENT_KEY \
    -u CLAUDE_CODE_CLIENT_KEY_PASSPHRASE \
    HOME="$CASE_HOME" "$@" bash "$SCRIPT" 2>&1)"
  STATUS=$?
}

assert() { # description, expected exit, must contain, must not contain
  local desc="$1" want="$2" must="$3" absent="$4" ok=1 reason=""
  [ "$STATUS" -eq "$want" ] || { ok=0; reason="exit $STATUS, expected $want"; }
  if [ -n "$must" ] && ! printf '%s' "$OUTPUT" | grep -qF -- "$must"; then
    ok=0; reason="${reason:+$reason; }missing: $must"
  fi
  if [ -n "$absent" ] && printf '%s' "$OUTPUT" | grep -qF -- "$absent"; then
    ok=0; reason="${reason:+$reason; }unexpected: $absent"
  fi
  if [ "$ok" -eq 1 ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$desc"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s (%s)\n' "$desc" "$reason"
    printf '%s\n' "$OUTPUT" | sed 's/^/     | /'
  fi
}

new_home
settings '{"env":{"HTTPS_PROXY":"http://proxy.example:8080"}}'
run_checker
assert "valid proxy URL passes" 0 "proxy URL has an http(s) scheme" "[FAIL]"

new_home
settings '{"env":{"HTTPS_PROXY":"proxy.example:8080"}}'
run_checker
assert "proxy without a scheme fails" 1 "has no http:// or https:// scheme" ""

new_home
settings '{"env":{"HTTPS_PROXY":"socks5://proxy.example:1080"}}'
run_checker
assert "SOCKS proxy fails" 1 "SOCKS proxies are not supported" "proxy URL has an http(s) scheme"

new_home
settings '{"env":{"HTTPS_PROXY":"http://alice:s3cr3t@proxy.example:8080"}}'
run_checker
assert "proxy credentials are masked" 0 "http://***@proxy.example:8080" "s3cr3t"
assert "embedded credentials raise a warning" 0 "proxy URL contains credentials" ""

new_home
settings '{"env":{"NODE_EXTRA_CA_CERTS":"/nonexistent/ca.pem"}}'
run_checker
assert "missing CA file fails" 1 "points to a missing file" ""

new_home
printf 'not a certificate\n' > "$CASE_HOME/empty.pem"
settings "{\"env\":{\"NODE_EXTRA_CA_CERTS\":\"$CASE_HOME/empty.pem\"}}"
run_checker
assert "CA file without PEM content fails" 1 "no PEM certificate" ""

new_home
printf -- '-----BEGIN CERTIFICATE-----\nMIIB\n-----END CERTIFICATE-----\n' > "$CASE_HOME/ca.pem"
settings "{\"env\":{\"NODE_EXTRA_CA_CERTS\":\"$CASE_HOME/ca.pem\"}}"
run_checker
assert "readable PEM CA file passes" 0 "NODE_EXTRA_CA_CERTS file exists" "[FAIL]"

new_home
settings '{"env":{'
run_checker
assert "invalid settings.json fails" 1 "is not valid JSON" ""

new_home
settings '{"env":{"CLAUDE_CODE_CERT_STORE":"mozilla"}}'
run_checker
assert "unknown certificate store value fails" 1 "unknown value" ""

new_home
settings '{"env":{"CLAUDE_CODE_CERT_STORE":"bundled,system"}}'
run_checker
assert "combined certificate stores pass" 0 "CLAUDE_CODE_CERT_STORE = bundled,system" "[FAIL]"

new_home
settings "{\"env\":{\"CLAUDE_CODE_CLIENT_KEY\":\"$CASE_HOME/key.pem\"}}"
printf 'key\n' > "$CASE_HOME/key.pem"
run_checker
assert "client key without certificate fails" 1 "CLAUDE_CODE_CLIENT_CERT is not" ""

new_home
printf 'cert\n' > "$CASE_HOME/client.pem"
printf 'key\n' > "$CASE_HOME/client.key"
settings "{\"env\":{\"CLAUDE_CODE_CLIENT_CERT\":\"$CASE_HOME/client.pem\",\"CLAUDE_CODE_CLIENT_KEY\":\"$CASE_HOME/client.key\"}}"
run_checker
assert "mTLS certificate and key pass" 0 "CLAUDE_CODE_CLIENT_CERT file exists" "[FAIL]"

new_home
settings '{}'
run_checker https_proxy=http://proxy.example:8080
assert "shell-only proxy warns about background agents" 0 "shell only" "[FAIL]"

new_home
run_checker
assert "no proxy reports a direct connection" 0 "no proxy variable set (direct connection)" "[FAIL]"

printf '\n%s passed, %s failed\n' "$PASSED" "$FAILED"
[ "$FAILED" -eq 0 ]
