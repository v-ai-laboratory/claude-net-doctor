---
description: Check Claude Code proxy, CA and mTLS configuration and explain any problems
argument-hint: "[--net]"
---

Run a network configuration check for Claude Code.

1. Run the bundled checker with Bash: `bash "${CLAUDE_PLUGIN_ROOT}/scripts/check-env.sh" $ARGUMENTS`
   Pass `--net` only if the user asked for a reachability test; without it the script sends no network requests.
2. Read the output with the `network-diagnostics` skill. For every `[FAIL]` and `[WARN]`, explain in one or two sentences what it means and give the exact fix (variable, value, where to set it).
3. If everything passes but the user still has a problem, ask for the exact error text, then suggest `claude --debug` and `/status` as the next step.
4. Never print proxy passwords or key passphrases. The script already masks credentials; keep them masked in your reply.

Finish with a short summary: what is fine, what must be fixed, and what to try next.
