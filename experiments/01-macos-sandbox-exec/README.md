# Day 0 · Does this macOS policy enforce its filesystem rules?

Run `./demo-sandbox-exec.sh` on macOS with `sandbox-exec` and Python 3. It creates a disposable directory, generates a profile for its resolved path and deletes the fixture on exit.

| Fixture operation | Required outcome |
|---|---|
| Read the ordinary log | Return the exact fixture bytes |
| Read or write the protected `.env` fixture | Permission denial; original contents unchanged |
| Write outside the workspace | Permission denial; no file created |
| Write the ordinary workspace output | Success; expected contents present |

A mismatch stops the run before benchmarking. The profile describes these filesystem rules, not network isolation or the policy of a separate agent wrapper.

**Historical sample:** on an Apple M3, macOS 27.2.1, 50 ordinary `cat` launches averaged 16.23 ms without and 34.27 ms with a profile (difference **18.04 ms**). The script reports a new sample on each run. Relative to a one-second baseline, 18.04 ms is 1.804%; no inference latency was measured.
