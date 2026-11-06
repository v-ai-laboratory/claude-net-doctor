# Verifying a configuration

## Debug log

```bash
claude --debug
# log: ~/.claude/debug/<session-id>.txt   (or --debug-file <path>)
```

Lines that confirm success:

```text
CA certs: Appended extra certificates from NODE_EXTRA_CA_CERTS (/path/ca.pem)
mTLS: Loaded client certificate from CLAUDE_CODE_CLIENT_CERT
mTLS: Loaded client key from CLAUDE_CODE_CLIENT_KEY
```

A `Failed to read` or `Failed to load` line means a file could not be read; the line includes the reason.

After an mTLS rotation, `Stale connection - reloaded rotated mTLS client material` confirms the re-read. Its absence does not prove failure: the pair may have been picked up while applying settings instead.

## /status rows

- **Proxy**: active proxy URL; unparseable values are marked invalid and ignored.
- **mTLS client cert / key**: shown only when the files loaded. A missing row means the load failed.
- **Additional CA cert(s)**: shows the path without checking it loaded; confirm in the debug log.

## Background agents

After changing the launcher setting for background agents, run `claude daemon stop --any` so the next background session starts a supervisor that honors it.
