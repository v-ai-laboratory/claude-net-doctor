---
name: network-diagnostics
description: Diagnose and configure Claude Code network settings - HTTP/HTTPS proxy, NO_PROXY, custom CA certificates, TLS-inspection proxies, mTLS client certificates, firewall allowlists, and stream timeouts. Use this skill whenever the user mentions proxy, corporate network, VPN, firewall, certificate errors, "unable to connect", SSL/TLS or handshake errors, NODE_EXTRA_CA_CERTS, HTTPS_PROXY, mTLS, SOCKS, or Claude Code hanging or timing out on requests, even if they do not name these settings explicitly.
---

# Claude Code network diagnostics

Help the user find and fix network problems in Claude Code, or set up a proxy / CA / mTLS configuration correctly the first time.

## Workflow

1. **Collect facts before guessing.** Ask for (or run `/net-check` to get) the exact error text, the install method (native installer or npm), the surface (terminal, Desktop Code tab, Cowork, cloud session), and whether a proxy or TLS-inspection appliance is in the path.
2. **Run the static check.** `/net-check` runs `scripts/check-env.sh`, which validates proxy URLs, certificate files and the `~/.claude/settings.json` `env` block without sending anything.
3. **Confirm with Claude Code itself.** Start with `claude --debug` (log goes to `~/.claude/debug/<session-id>.txt`, or a path given with `--debug-file`) and use `/status` in a session. See `references/verify.md`.
4. **Map the symptom to a cause** with the table below, then give the smallest fix. Prefer settings over shell exports (see "Where to set variables").
5. **Never print secrets.** Mask credentials in proxy URLs and never echo key passphrases.

## Symptom to cause

| Symptom | Likely cause | Fix |
| - | - | - |
| Launch stops with an error naming a proxy variable | Proxy URL cannot be parsed, e.g. missing `http://` scheme | Add the scheme: `http://host:port` |
| Connection errors through a proxy that works for other tools | Proxy is SOCKS (not supported) or needs NTLM/Kerberos | Use an HTTP(S) proxy, or an LLM gateway that supports the auth method |
| Certificate / TLS errors behind a TLS-inspection proxy | Corporate root CA not trusted | Install the root in the OS trust store, or set `NODE_EXTRA_CA_CERTS=/path/ca.pem` |
| Same, on an npm install | Runtime cannot read the OS store | Use Node 22.15+ or the native installer; otherwise use `NODE_EXTRA_CA_CERTS` |
| Requests fail only with gzip bodies through an inspection proxy | Proxy mishandles compressed request bodies | `CLAUDE_CODE_GZIP_REQUEST_BODIES=0` |
| Connection reset / handshake errors with mTLS | Cert or key path wrong, mismatched pair, expired pair | Check `--debug` for `mTLS: Loaded client certificate` lines; fix paths; rotate before expiry |
| Works in terminal, fails in background agents | Variables exported in the shell only | Put them in the `env` block of `~/.claude/settings.json` or managed settings |
| Variables ignored in Desktop/Cowork or cloud sessions | Those sessions read them only from managed settings and `~/.claude/settings.json` (or ignore them entirely in cloud sessions) | Move them to user or managed settings |
| Sign-in or plugin install fails | A required host is blocked | Check `references/hosts.md` |
| Response stalls then retries | Streaming watchdog fired | See `references/hosts.md` (timeouts section) |

## Where to set variables

- Variables exported in a shell are read once at startup; a running session does not pick up later changes.
- Every network variable can also go in the `env` block of `~/.claude/settings.json` (or managed settings). This is the only place that reliably reaches background agents, because they run under a shared supervisor process that inherits the environment of whichever shell started it first.
- `CLAUDE_CODE_CERT_STORE` has no dedicated schema key; set it via the `env` block or the process environment.

## Core rules (from the official docs)

- Proxy variables: `HTTPS_PROXY`, `HTTP_PROXY`, `NO_PROXY`. Lowercase variants work; the first one set wins in the order `https_proxy`, `HTTPS_PROXY`, `http_proxy`, `HTTP_PROXY`.
- `NO_PROXY` accepts space- or comma-separated lists, or `*` to bypass the proxy entirely.
- Basic auth goes in the URL (`http://user:pass@host:port`). Do not hardcode passwords in scripts.
- SOCKS proxies are not supported.
- Default CA trust is `bundled,system` (Mozilla set plus the OS store); narrow it with `CLAUDE_CODE_CERT_STORE=bundled` or `system`.
- mTLS: `CLAUDE_CODE_CLIENT_CERT`, `CLAUDE_CODE_CLIENT_KEY`, optional `CLAUDE_CODE_CLIENT_KEY_PASSPHRASE`. Replacing the files at the same paths rotates the pair; Claude Code re-reads after a connection-level failure.

The docs change over time. When a detail matters (a version number, a host list, a variable name), check the live page: https://code.claude.com/docs/en/corporate-proxy
