# claude-net-doctor

A Claude Code plugin that finds and fixes network problems: HTTP(S) proxies, `NO_PROXY`, custom CA certificates, TLS-inspection appliances, mTLS client certificates, firewall allowlists, and streaming timeouts.

It runs a local checker, explains every failure in plain language, and hands back the exact variable and value to change. No MCP servers, no telemetry, no network requests unless you ask for them.

## Install

Add the marketplace once, then install the plugin:

```bash
claude plugin marketplace add v-ai-laboratory/claude-net-doctor
claude plugin install claude-net-doctor@v-ai-laboratory
```

Or from inside a session:

```text
/plugin marketplace add v-ai-laboratory/claude-net-doctor
/plugin install claude-net-doctor@v-ai-laboratory
```

To try a local checkout without installing:

```bash
git clone https://github.com/v-ai-laboratory/claude-net-doctor
claude --plugin-dir ./claude-net-doctor
```

## Use

```text
/claude-net-doctor:net-check
```

The checker reads the shell environment and the `env` block of `~/.claude/settings.json`, then reports every setting as `OK`, `INFO`, `WARN`, or `FAIL`. Claude reads the output with the bundled `network-diagnostics` skill, so each warning comes with the cause and the fix.

Add `--net` to also test reachability of the hosts Claude Code needs:

```text
/claude-net-doctor:net-check --net
```

Without `--net` nothing leaves the machine.

You can also just describe the symptom ("TLS handshake fails behind our proxy", "Claude Code hangs after sign-in"); the skill activates on proxy, VPN, certificate, `NODE_EXTRA_CA_CERTS`, `HTTPS_PROXY`, mTLS, SOCKS and timeout questions.

## What it checks

| Area | Checks |
| - | - |
| Settings file | `~/.claude/settings.json` exists and parses as JSON |
| Proxy | Active variable and its source; missing `http://`/`https://` scheme; SOCKS (unsupported); embedded credentials |
| `NO_PROXY` | Presence, space- or comma-separated lists |
| Custom CA | `NODE_EXTRA_CA_CERTS` file exists, is readable, and contains a PEM certificate |
| Trust store | `CLAUDE_CODE_CERT_STORE` accepts only `bundled` and `system` |
| mTLS | `CLAUDE_CODE_CLIENT_CERT` / `CLAUDE_CODE_CLIENT_KEY` set as a pair, files readable, encrypted key without passphrase |
| Background agents | Network variables set in the shell only, where background agents may not inherit them |

Example output:

```text
claude-net-doctor
-----------------
Settings file
  [ OK ] ~/.claude/settings.json is valid JSON
Proxy
  [INFO] active variable: HTTPS_PROXY = http://***@proxy.corp.example:8080 [settings.json]
  [ OK ] proxy URL has an http(s) scheme
  [WARN] proxy URL contains credentials; avoid hardcoding passwords in scripts
Certificates
  [FAIL] NODE_EXTRA_CA_CERTS points to a missing file: /etc/ssl/certs/corp-root.pem
mTLS
  [INFO] mTLS not configured
-----------------
Summary: 2 ok, 1 warnings, 1 failures
```

## What's inside

| Path | Purpose |
| - | - |
| `skills/network-diagnostics/` | Symptom-to-cause table, setup rules, verification steps, host allowlist, timeout variables |
| `commands/net-check.md` | `/claude-net-doctor:net-check` command |
| `scripts/check-env.sh` | The checker: offline by default, `--net` for reachability |
| `.claude-plugin/marketplace.json` | Makes this repository installable as a marketplace |
| `tests/check-env.test.sh` | Functional tests for the checker |

## Privacy and safety

- Reads `~/.claude/settings.json` and the environment. Nothing else.
- Sends no network requests unless called with `--net`.
- Masks credentials in proxy URLs (`http://***@host:port`) and never prints key passphrases.
- The script is plain Bash and easy to audit before running.

## Limits

- The reachability test uses `curl` and the system trust store, which can differ from what Claude Code trusts. A `[FAIL]` there is a strong hint, not a verdict.
- The checker cannot see variables that only a running background agent inherited, or policy enforced by managed settings. It warns when the shell is the only source.
- Claude Code does not support SOCKS proxies; the checker flags them instead of suggesting workarounds.

## Development

```bash
bash tests/check-env.test.sh     # 15 functional tests, no network, temporary HOME
shellcheck scripts/check-env.sh  # CI runs this on Linux
```

CI runs the tests on Linux and macOS and validates both JSON manifests.

## Source of truth

The skill summarizes the official page <https://code.claude.com/docs/en/corporate-proxy>. If the two disagree, the documentation wins; open an issue or a PR when it drifts.

## License

MIT
