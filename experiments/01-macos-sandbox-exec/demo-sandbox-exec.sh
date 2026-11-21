#!/usr/bin/env bash
# Defensive acceptance check of a filesystem policy, using only disposable fixtures.
set -euo pipefail
if [[ $(uname -s) != Darwin ]] || ! command -v sandbox-exec >/dev/null; then
  echo 'Requires macOS and sandbox-exec.' >&2
  exit 1
fi
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
python3 - "$tmp" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
from time import perf_counter

root = Path(sys.argv[1]).resolve()
work = root / "workspace"
work.mkdir()
normal, protected, output = work/"app.log", work/".env", work/"ok.txt"
normal.write_text("public fixture\n")
protected.write_text("protected fixture\n")
profile = root/"policy.sb"
profile.write_text(r'''(version 1)
(allow default)
(deny file-write*)
(allow file-write* (subpath WORK))
(deny file-read* file-write* (regex #"/\.env(\.[^/]+)?$"))
'''.replace("WORK", json.dumps(str(work))))
wrapper = ["sandbox-exec", "-f", str(profile)]
env = dict(os.environ, LC_ALL="C")

def check(label, command, allowed):
    result = subprocess.run(wrapper + command, capture_output=True, env=env)
    if allowed:
        result.check_returncode()
    elif result.returncode == 0 or not any(msg in result.stderr for msg in
            (b"Operation not permitted", b"Permission denied")):
        raise SystemExit(f"FAIL {label}: expected a permission denial, got exit {result.returncode}")
    print(f"PASS {label}")
    return result.stdout

def write(path):
    return ["/bin/sh", "-c", 'printf "updated\\n" > "$1"', "fixture", str(path)]

if check("ordinary read", ["/bin/cat",str(normal)], True) != normal.read_bytes():
    raise SystemExit("ordinary read returned the wrong bytes")
check("protected read", ["/bin/cat",str(protected)], False)
check("protected write", write(protected), False)
check("outside write", write(root/"outside.txt"), False)
check("workspace write", write(output), True)
if output.read_text() != "updated\n" or protected.read_text() != "protected fixture\n" or (root/"outside.txt").exists():
    raise SystemExit("filesystem postconditions failed")

def mean_ms(prefix):
    start = perf_counter()
    for _ in range(50):
        subprocess.run(prefix + ["/bin/cat",str(normal)], check=True, stdout=subprocess.DEVNULL)
    return (perf_counter()-start)*1000/50

plain, isolated = mean_ms([]), mean_ms(wrapper)
print(f"Mean over 50 ordinary reads each: plain {plain:.2f} ms; confined {isolated:.2f} ms; delta {isolated-plain:+.2f} ms")
PY
