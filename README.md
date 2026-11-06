# claude-net-doctor

Diagnose and configure Claude Code network settings: HTTP(S) proxy, `NO_PROXY`, custom CA certificates, TLS-inspection proxies, mTLS client certificates, firewall allowlists and streaming timeouts.

## What's inside

| Component | Purpose |
| - | - |
| `skills/network-diagnostics` | Symptom-to-cause table, setup rules, verification steps, host allowlist |
| `/net-check` | Runs the bundled checker and explains every warning and failure |
| `scripts/check-env.sh` | Offline checks of proxy URLs, certificate files and the `env` block of `~/.claude/settings.json`; optional `--net` reachability test |

No MCP servers, no network calls by default, no data leaves your machine. Proxy credentials are masked in output.

## Try it locally

```bash
git clone https://github.com/v-ai-laboratory/claude-net-doctor
claude --plugin-dir ./claude-net-doctor
```

Then run `/net-check`, or `/net-check --net` to also test reachability of the required hosts.

## Source of truth

The skill summarizes the official page https://code.claude.com/docs/en/corporate-proxy. If the two disagree, the documentation wins.

## License

MIT
