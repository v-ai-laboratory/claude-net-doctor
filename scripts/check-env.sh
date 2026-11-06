#!/usr/bin/env bash
# claude-net-doctor: static checks of Claude Code network settings.
# Reads shell environment and the "env" block of ~/.claude/settings.json.
# Sends no network requests unless called with --net.
# Credentials in proxy URLs are masked; passphrases are never printed.

set -u
DO_NET=0
[ "${1:-}" = "--net" ] && DO_NET=1

OK=0; WARN=0; FAIL=0
pass() { printf '  [ OK ] %s\n' "$1"; OK=$((OK+1)); }
warn() { printf '  [WARN] %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  [FAIL] %s\n' "$1"; FAIL=$((FAIL+1)); }
info() { printf '  [INFO] %s\n' "$1"; }
mask() { printf '%s' "$1" | sed -E 's#(://)[^/@]*@#\1***@#'; }

SETTINGS="$HOME/.claude/settings.json"

# Read env.<NAME> from settings.json (jq, else python3). Empty if unavailable.
setting() {
  [ -f "$SETTINGS" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$1" '.env[$k] // empty' "$SETTINGS" 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    python3 - "$SETTINGS" "$1" <<'PY' 2>/dev/null
import json, sys
try:
    v = json.load(open(sys.argv[1])).get("env", {}).get(sys.argv[2], "")
    print(v if v is not None else "")
except Exception:
    pass
PY
  fi
}

# Effective value: shell env first, then settings.json.
val() {
  local v; v="$(printenv "$1" 2>/dev/null || true)"
  [ -n "$v" ] && { printf '%s' "$v"; return; }
  setting "$1"
}
src() {
  if [ -n "$(printenv "$1" 2>/dev/null || true)" ]; then
    if [ -n "$(setting "$1")" ]; then echo "shell + settings.json"; else echo "shell only"; fi
  elif [ -n "$(setting "$1")" ]; then echo "settings.json"
  fi
}

echo "claude-net-doctor"
echo "-----------------"

echo "Settings file"
if [ -f "$SETTINGS" ]; then
  if command -v jq >/dev/null 2>&1; then
    if jq -e . "$SETTINGS" >/dev/null 2>&1; then pass "$SETTINGS is valid JSON"; else bad "$SETTINGS is not valid JSON"; fi
  elif command -v python3 >/dev/null 2>&1; then
    info "jq not found; using python3 to read settings.json"
  else
    warn "neither jq nor python3 found; settings.json env block was not checked"
  fi
else
  info "$SETTINGS not found (only the shell environment is checked)"
fi

echo "Proxy"
PROXY=""; PROXY_VAR=""
for n in https_proxy HTTPS_PROXY http_proxy HTTP_PROXY; do
  v="$(val "$n")"
  if [ -n "$v" ]; then PROXY="$v"; PROXY_VAR="$n"; break; fi
done
if [ -z "$PROXY" ]; then
  info "no proxy variable set (direct connection)"
else
  info "active variable: $PROXY_VAR = $(mask "$PROXY") [$(src "$PROXY_VAR")]"
  case "$PROXY" in
    socks*://*) bad "SOCKS proxies are not supported by Claude Code; use an HTTP(S) proxy" ;;
    http://*|https://*) pass "proxy URL has an http(s) scheme" ;;
    *) bad "proxy URL has no http:// or https:// scheme (Claude Code stops at launch on this)" ;;
  esac
  case "$PROXY" in
    *://*:*@*|*://*@*) warn "proxy URL contains credentials; avoid hardcoding passwords in scripts" ;;
  esac
  [ "$(src "$PROXY_VAR")" = "shell only" ] && \
    warn "$PROXY_VAR is set in the shell only; background agents may not see it. Add it to the env block of ~/.claude/settings.json"
fi
NP="$(val NO_PROXY)"; [ -z "$NP" ] && NP="$(val no_proxy)"
[ -n "$NP" ] && info "NO_PROXY = $NP"

echo "Certificates"
check_file() { # name, label
  local v; v="$(val "$1")"
  [ -z "$v" ] && return 1
  if [ ! -e "$v" ]; then bad "$1 points to a missing file: $v"
  elif [ ! -r "$v" ]; then bad "$1 file is not readable: $v"
  else pass "$1 file exists and is readable [$(src "$1")]"; fi
  return 0
}
if check_file NODE_EXTRA_CA_CERTS; then
  f="$(val NODE_EXTRA_CA_CERTS)"
  if [ -r "$f" ] && ! grep -q 'BEGIN CERTIFICATE' "$f" 2>/dev/null; then
    bad "NODE_EXTRA_CA_CERTS file has no PEM certificate (expected 'BEGIN CERTIFICATE')"
  fi
fi

STORE="$(val CLAUDE_CODE_CERT_STORE)"
if [ -n "$STORE" ]; then
  okstore=1
  IFS=',' read -r -a parts <<< "$STORE"
  for p in "${parts[@]}"; do
    case "$(printf '%s' "$p" | tr -d ' ')" in bundled|system) ;; *) okstore=0 ;; esac
  done
  if [ "$okstore" = 1 ]; then pass "CLAUDE_CODE_CERT_STORE = $STORE"; else bad "CLAUDE_CODE_CERT_STORE has an unknown value '$STORE' (use bundled and/or system)"; fi
fi

echo "mTLS"
C="$(val CLAUDE_CODE_CLIENT_CERT)"; K="$(val CLAUDE_CODE_CLIENT_KEY)"; P="$(val CLAUDE_CODE_CLIENT_KEY_PASSPHRASE)"
if [ -z "$C" ] && [ -z "$K" ]; then
  info "mTLS not configured"
  [ -n "$P" ] && warn "CLAUDE_CODE_CLIENT_KEY_PASSPHRASE is set but no client key is configured"
else
  [ -z "$C" ] && bad "CLAUDE_CODE_CLIENT_KEY is set but CLAUDE_CODE_CLIENT_CERT is not"
  [ -z "$K" ] && bad "CLAUDE_CODE_CLIENT_CERT is set but CLAUDE_CODE_CLIENT_KEY is not"
  check_file CLAUDE_CODE_CLIENT_CERT || true
  check_file CLAUDE_CODE_CLIENT_KEY || true
  if [ -n "$K" ] && [ -r "$K" ] && grep -q 'ENCRYPTED' "$K" 2>/dev/null && [ -z "$P" ]; then
    warn "client key looks encrypted but CLAUDE_CODE_CLIENT_KEY_PASSPHRASE is not set"
  fi
fi

if [ "$DO_NET" = 1 ]; then
  echo "Reachability (curl; follows proxy variables; uses the system trust store, which can differ from Claude Code)"
  if ! command -v curl >/dev/null 2>&1; then
    warn "curl not found; skipping reachability test"
  else
    for h in api.anthropic.com claude.ai platform.claude.com downloads.claude.ai github.com registry.npmjs.org; do
      code="$(curl -sS -o /dev/null -m 10 -w '%{http_code}' "https://$h" 2>/tmp/net-doctor.err || true)"
      if [ -n "$code" ] && [ "$code" != "000" ]; then
        pass "$h reachable (HTTP $code)"
      else
        bad "$h unreachable: $(head -c 120 /tmp/net-doctor.err 2>/dev/null | tr '\n' ' ')"
      fi
    done
    rm -f /tmp/net-doctor.err
  fi
fi

echo "-----------------"
echo "Summary: $OK ok, $WARN warnings, $FAIL failures"
[ "$FAIL" -eq 0 ]
