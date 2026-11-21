#!/usr/bin/env bash
# Case 01: BPE Tokenizer Blindspot & EN/JP Token Multiplier Benchmark
# Purpose: Inspect exact token IDs produced by Llama 3.1 8B (via llama-tokenize + Ollama GGUF)
#          to see why character counting fails, why Japanese logs consume ~2x tokens,
#          and how Byte-level BPE splits rare Kanji mid-UTF8-character without [UNK].
# Requirements: macOS / Linux, llama.cpp (llama-tokenize), ollama (with meta-llama-3.1-8b-instruct-q4_k_m)
#               or pass GGUF_PATH=/path/to/model.gguf directly.

set -euo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"

MODEL_TAG="${MODEL_TAG:-meta-llama-3.1-8b-instruct-q4_k_m}"
GGUF_PATH="${GGUF_PATH:-}"

if ! command -v llama-tokenize >/dev/null 2>&1; then
  echo "Error: llama-tokenize not found. Install via: brew install llama.cpp" >&2
  exit 1
fi

if [[ -z "$GGUF_PATH" ]]; then
  if ! command -v ollama >/dev/null 2>&1; then
    echo "Error: set GGUF_PATH=/path/to/model.gguf or install ollama." >&2
    exit 1
  fi
  GGUF_PATH="$(ollama show --modelfile "$MODEL_TAG" | awk '/^FROM /{print $2; exit}')"
fi

if [[ ! -f "$GGUF_PATH" ]]; then
  echo "Error: GGUF file not found at '$GGUF_PATH' (MODEL_TAG=$MODEL_TAG)" >&2
  exit 1
fi

echo "=== Environment ==="
echo "Model tag : $MODEL_TAG"
echo "GGUF blob : $GGUF_PATH"
echo

echo "=== [1] 'strawberry' standalone vs inside an actual question ==="
echo "--- Standalone: \"strawberry\" ---"
llama-tokenize -m "$GGUF_PATH" -p "strawberry" --log-disable
echo "--- Actual question: \"How many r's are in strawberry?\" (note leading space -> single ID 73700!) ---"
llama-tokenize -m "$GGUF_PATH" -p "How many r's are in strawberry?" --log-disable
echo

echo "=== [2] Same incident log in English (6 tokens) vs Japanese (12 tokens = 2.0x) ==="
echo "--- EN: \"DB server crashed on OOM\" ---"
llama-tokenize -m "$GGUF_PATH" -p "DB server crashed on OOM" --log-disable
echo "--- JP: \"DBサーバーはメモリ不足で落ちた\" ---"
llama-tokenize -m "$GGUF_PATH" -p "DBサーバーはメモリ不足で落ちた" --log-disable
echo

echo "=== [3] Byte-level BPE fallback: splitting a single Kanji ('嵐') across UTF-8 bytes ==="
echo "--- Input: \"リトライ嵐\" ---"
llama-tokenize -m "$GGUF_PATH" -p "リトライ嵐" --log-disable
echo

echo "=== [4] Realistic 3-line incident ticket: token count & KV memory ratio ==="
EN_INC="2026-11-21 09:12:03 ERROR [payment-db-01] PostgreSQL process killed by OOM killer. Active connections spiked from 120 to 980 after retry storm. Temporary mitigation: increased connection pool timeout and restarted replica."
JP_INC="2026-11-21 09:12:03 ERROR [payment-db-01] PostgreSQLプロセスがOOM Killerにより強制終了しました。リトライ嵐の発生後、アクティブ接続数が120から980へ急増しています。暫定対処として接続プールのタイムアウトを引き上げ、レプリカを再起動しました。"

EN_IDS="$(llama-tokenize -m "$GGUF_PATH" -p "$EN_INC" --ids --log-disable)"
JP_IDS="$(llama-tokenize -m "$GGUF_PATH" -p "$JP_INC" --ids --log-disable)"
EN_CNT="$(echo "$EN_IDS" | tr ',' '\n' | wc -l | tr -d ' ')"
JP_CNT="$(echo "$JP_IDS" | tr ',' '\n' | wc -l | tr -d ' ')"

python3 - "$EN_CNT" "$JP_CNT" <<'PY'
import sys
en, jp = int(sys.argv[1]), int(sys.argv[2])
ascii_prefix = 21  # shared timestamp + [payment-db-01] + PostgreSQL tokens
en_body, jp_body = en - ascii_prefix, jp - ascii_prefix
print(f"Total tokens (incl. shared log header) : EN={en} vs JP={jp} ({jp/en:.2f}x)")
print(f"Natural-language body tokens only      : EN={en_body} vs JP={jp_body} ({jp_body/en_body:.2f}x)")
print(f"1,000 tickets KV cache (@128 KiB/tok)  : EN={en*1000*128/1024:.1f} MiB vs JP={jp*1000*128/1024:.1f} MiB")
PY
