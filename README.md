# ai-fieldnotes-repo

Small experiments for local LLMs and agent systems. Each entry distinguishes measured output from estimates. 実測値は入力・環境・単位とセットで記録する。

| Experiment | What to check |
|---|---|
| [Day 0 · Filesystem policy on macOS](experiments/01-macos-sandbox-exec/) | Five expected read/write outcomes, then a fresh 50-run launch benchmark. |
| [Case 01 · Tokenizer](experiments/case01-tokenizer-blindspot/) | Reproduce two vocabularies' token IDs and lengths using small, pinned GGUF fixtures; no inference or VRAM measurement. |
| [Case 02 · Embedding lookup](experiments/case02-embedding-and-relu/) | Find a label and inspect a 4,096-coordinate row in a fixed Q4_K_M file. |
| [Case 03 · Structured response](experiments/case03-attention-and-json/) | Check transport, completion, JSON shape and classification separately. |

The scripts are [MIT licensed](LICENSE). Supply synthetic inputs or data you can share.
