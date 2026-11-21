#!/usr/bin/env bash
# Count tokens, not runtime memory. No weights are downloaded by this script.
set -euo pipefail
command -v llama-tokenize >/dev/null || { echo 'Install llama.cpp first.' >&2; exit 1; }
gguf=${GGUF_PATH:-}
if [[ -z "$gguf" ]]; then
  tag=${MODEL_TAG:-llama3.1:8b}
  if ! command -v ollama >/dev/null || ! modelfile=$(ollama show --modelfile "$tag"); then
    echo 'Set GGUF_PATH to a local model or one of the small vocabulary fixtures in README.md.' >&2
    exit 1
  fi
  gguf=$(sed -n 's/^FROM //p' <<<"$modelfile" | head -n 1)
  printf 'Ollama source: %s\n' "$tag"
fi
[[ -f "$gguf" ]] || { echo "Not a local GGUF: $gguf" >&2; exit 1; }
python3 - "$gguf" <<'PY'
import ast
from itertools import takewhile
from pathlib import Path
import subprocess
import sys

model = Path(sys.argv[1]).resolve()
print(f"Tokenizer input: {model.name}")

def ids(text, *, no_bos=False):
    cmd = ["llama-tokenize", "-m", str(model), "-p", text, "--ids", "--log-disable"]
    if no_bos:
        cmd.append("--no-bos")
    result = ast.literal_eval(subprocess.check_output(cmd, text=True).strip())
    if not isinstance(result, list) or not result or not all(type(n) is int for n in result):
        raise ValueError("Expected a nonempty list of token IDs")
    return result

for text in ("strawberry", " strawberry", "How many r's are in strawberry?",
             "DB server crashed on OOM", "DBサーバーはメモリ不足で落ちた", "リトライ嵐"):
    tokens = ids(text, no_bos=True)
    print(f"{text!r}: {len(tokens)} tokens (no BOS) {tokens}")

header = "2026-11-21 09:12:03 ERROR [payment-db-01] PostgreSQL"
en = ids(header + " process killed by OOM killer. Active connections spiked from 120 to 980 after retry storm. Temporary mitigation: increased connection pool timeout and restarted replica.")
jp = ids(header + "プロセスがOOM Killerにより強制終了しました。リトライ嵐の発生後、アクティブ接続数が120から980へ急増しています。暫定対処として接続プールのタイムアウトを引き上げ、レプリカを再起動しました。")
prefix = sum(1 for _ in takewhile(lambda pair: pair[0] == pair[1], zip(en, jp)))
a, b = len(en) - prefix, len(jp) - prefix
print(f"Full ticket EN/JP (tokenizer defaults): {len(en)}/{len(jp)}")
print(f"Shared leading IDs: {prefix}; remaining EN/JP: {a}/{b} ({b/a:.2f}x)")
PY
