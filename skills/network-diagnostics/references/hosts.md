# Hosts, allowlists and timeouts

Allowlist these in the proxy and firewall. Always check the live page for the current list: https://code.claude.com/docs/en/corporate-proxy

## Core

| Host | Used for |
| - | - |
| `api.anthropic.com` | API requests, WebFetch domain safety check, feature flags |
| `claude.ai`, `claude.com` | claude.ai sign-in |
| `platform.claude.com` | Console sign-in; OAuth token exchange and refresh for claude.ai accounts too |
| `sso.claude.com` | Browser sign-in flow for SSO organizations |

## Optional or feature-specific

| Host | Used for |
| - | - |
| `mcp-proxy.anthropic.com` | MCP connectors from claude.ai |
| `downloads.claude.ai` | Plugin executables, native installer and updater |
| `storage.googleapis.com` | Plugin install counts and metadata |
| `registry.npmjs.org` | Plugin installs, npx-launched MCP servers, npm installs of Claude Code |
| `github.com` | Cloning plugin marketplaces and plugins |
| `bridge.claudeusercontent.com` | Claude in Chrome bridge |
| `raw.githubusercontent.com` | Changelog feed |
| `code.claude.com` | Documentation lookups |
| Telemetry hosts | Optional; disabled by `DISABLE_TELEMETRY` or `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` |

On Bedrock, Google Cloud's Agent Platform, Microsoft Foundry or an LLM gateway, model traffic goes to the provider or gateway instead of the Anthropic hosts.

With organization IP allowlisting, route `bridge.claudeusercontent.com` through the same proxy egress as `claude.ai` and `api.anthropic.com`.

## Streaming timeouts

Four timers abort a silent stream so it retries instead of hanging: a first-byte deadline, an event-level watchdog, a byte-level watchdog and a body idle timeout.

| Variable | Effect |
| - | - |
| `CLAUDE_STREAM_FIRST_BYTE_TIMEOUT_MS` | First-byte deadline |
| `CLAUDE_STREAM_IDLE_TIMEOUT_MS` | Both watchdogs (raised to at least 5 min; byte-level capped at 30 min) |
| `CLAUDE_BYTE_STREAM_IDLE_TIMEOUT_MS` | Byte-level watchdog only (10 s to 30 min) |
| `API_TIMEOUT_MS` | Wait for response headers |
| `API_FORCE_IDLE_TIMEOUT` | `0` turns the body idle timeout off, `1` turns it on for every provider |

Raise timeouts only after ruling out a blocked host or a proxy that buffers streaming responses.
