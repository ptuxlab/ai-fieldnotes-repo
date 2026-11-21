# Case 01 · One word, two contexts

With the Llama BPE vocabulary, `strawberry` at the start of a string yields `[496, 675, 15717]`, while ` strawberry` (leading space) yields `[73700]`. A token ID indexes a learned representation. This experiment observes segmentation; it neither runs a generation model nor establishes why a particular answer was wrong.

## Reproduce without downloading model weights

Install `llama-tokenize` (`brew install llama.cpp` on macOS), Python 3 and curl. From this directory:

```bash
base=https://raw.githubusercontent.com/ggml-org/llama.cpp/b1b770d90/models
tmp=$(mktemp -d)
for vocab in llama-bpe gemma-4; do
  curl -fLsS "$base/ggml-vocab-$vocab.gguf" -o "$tmp/$vocab.gguf" || exit 1
  GGUF_PATH="$tmp/$vocab.gguf" ./demo-tokenizer.sh || exit 1
done
```

Tested with llama.cpp build 12359 (`b1b770d90`). SHA-256 of the fixtures: `llama-bpe` = `97272e430d53bc7688f52d5e0ad8ea8f163ede9f1bbd1694feaa504797d5d96e`; `gemma-4` = `58b1ba0b57f3b4d7c468ba4ffd91ad85190346a3d7ad7e71d1cabaae8a14bb65`. For an already installed Ollama GGUF, unset `GGUF_PATH` and set `MODEL_TAG` to its exact local name. The script prints the actual input filename.

| Vocabulary | Short ticket, EN / JP (no BOS) | Full ticket, EN / JP (default special tokens) | Common leading IDs | Remaining EN / JP |
|---|---:|---:|---:|---:|
| Llama BPE | 6 / 12 | 52 / 87 | 21 | 31 / 66 |
| Gemma 4 | 6 / 8 | 65 / 83 | 30 | 35 / 53 |

The Japanese short ticket is `DBサーバーはメモリ不足で落ちた`; its English counterpart is `DB server crashed on OOM`. These are sample counts, not language-wide multipliers. For Llama, `嵐` ends in IDs `123451, 238`: token boundaries need not be character boundaries. Memory allocation, timing, and model accuracy were not measured.
