# 01. AI Agent Kernel Sandboxing on macOS (`sandbox-exec`)

Prompt-level rules like *"never read `.env`"* are not a security boundary. String-based path filters inside an agent loop are trivially bypassed via symlinks (`ln -s .env innocent.txt`) or child processes (`python3 -c "open('.env')"`).

This 1-minute script verifies that a minimal macOS Seatbelt (`sandbox-exec`) profile blocks all of those attempts at the OS kernel layer with negligible overhead.

## Quick Run (macOS)

```bash
chmod +x demo-sandbox-exec.sh
./demo-sandbox-exec.sh
```

- Creates a temporary directory under `/tmp` (resolved to `/private/tmp` via `realpath` for Seatbelt compatibility).
- Automatically deletes all temporary files on exit.

## Measured Results (Apple M3 / macOS 27.2.1)

| # | Test Case | Result | Exit Code |
|---:|---|---|---:|
| 1 | Plain `cat workspace/.env` (no sandbox) | Leaks secret value | `0` |
| 2 | Sandboxed `cat workspace/app.log` | Allowed (normal log read) | `0` |
| 3 | Sandboxed `cat workspace/.env` | `Operation not permitted` | `1` |
| 4 | Symlink bypass (`ln -sf .env innocent.txt` → `cat innocent.txt`) | `Operation not permitted` | `1` |
| 5 | Child-process bypass (`python3 -c "open('.env')"`) | `PermissionError: Operation not permitted` | `1` |
| 6 | Out-of-workspace write (`outside/pwned.txt`) & `.env` append | `Operation not permitted` (while `workspace/ok.txt` succeeds) | `1` / `0` |
| 7 | 50-run average overhead (`plain cat` vs `sandbox-exec cat`) | `16.23 ms` vs `34.27 ms` (**`+18.04 ms`**) | `0` |

## Gotcha Worth Remembering

On macOS, `/tmp` is a symlink to `/private/tmp` and `/var` is a symlink to `/private/var`. Seatbelt matches against resolved real paths, so always resolve paths with `realpath` before generating `.sb` profiles.
