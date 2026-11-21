# Case 01. BPE Tokenizer Blindspots & Multilingual Token Inflation

Why does `Llama-3.1-8B-Instruct` confidently answer *"There are 2 letter R's in the word strawberry"* at `temperature=0`, and why do Japanese incident logs consume ~2x the KV cache and prefill compute of identical English logs?

This 5-second experiment runs `llama-tokenize` directly against the local GGUF model blob to inspect the exact integer IDs entering the Transformer.

## Quick Run

```bash
brew install llama.cpp
chmod +x demo-tokenizer.sh
./demo-tokenizer.sh
```

*(Uses `meta-llama-3.1-8b-instruct-q4_k_m` from Ollama by default, or override via `GGUF_PATH=/path/to/model.gguf ./demo-tokenizer.sh`.)*

## Key Measured Findings (Apple M3 / `Llama-3.1-8B-Instruct Q4_K_M`)

### 1. `"strawberry"` in a real question is not 3 tokens — it is **1 single integer (`73700`)**

| Input | Exact `llama-tokenize` Output (excluding `<\|begin_of_text\|>`) | What the Transformer Sees |
|---|---|---|
| `"strawberry"` (standalone, no leading space) | `496 ('str')`, `675 ('aw')`, `15717 ('berry')` | 3 integers |
| `"How many r's are in strawberry?"` | `4438 ('How')`, `1690 (' many')`, `436 (' r')`, `596 (''s')`, `527 (' are')`, `304 (' in')`, **`73700 (' strawberry')`**, `30 ('?')` | **1 single integer (`73700`)** for the entire word `' strawberry'` |

Because BPE merges frequent leading-space words into a single token, asking *"How many r's are in strawberry?"* literally asks the network whether integer `73700` contains integer `436`.

### 2. English vs Japanese Incident Log (`6` vs `12` tokens = `2.0x`)

| Log Line | Token Count (excl. BOS) | Exact Split |
|---|---:|---|
| `"DB server crashed on OOM"` | **6** | `'DB'(3590)` `' server'(3622)` `' crashed'(34853)` `' on'(389)` `' O'(507)` `'OM'(1937)` |
| `"DBサーバーはメモリ不足で落ちた"` (Llama 3.1 8B) | **12 (`2.0x`)** | `'DB'(3590)` `'サ'(60868)` `'ーバ'(112164)` `'ー'(11972)` `'は'(15682)` `'メ'(39850)` `'モ'(102494)` `'リ'(37823)` `'不足'(127242)` `'で'(16556)` `'落ち'(120175)` `'た'(28713)` |
| `"DBサーバーはメモリ不足で落ちた"` (Gemma 4, 256K vocab) | **8 (`1.33x`)** | `'DB'(6270)` **`'サーバー'(125591)`** `'は'(237048)` **`'メモリ'(210413)`** `'不足'(51750)` `'で'(237007)` `'落ち'(67309)` `'た'(237036)` |

### 3. Mid-Kanji UTF-8 Byte Fallback (`"リトライ嵐"`)

In `Llama 3.1 8B`, `"リトライ嵐"` splits `"嵐"` (`U+5D50`, 3 UTF-8 bytes) across two sub-character byte tokens (`123451` + `238`), printing replacement characters (``) when inspected individually—demonstrating how Byte-level BPE avoids `[UNK]` errors at the cost of extra token steps.

## Engineering Takeaway

Never spend prompt engineering effort forcing an LLM to count characters, parse regexes, or do exact arithmetic—offload deterministic string/math operations to tools (`python`, `wc`, `jq`), and account for the **~1.7x–2.1x non-English token multiplier** when sizing local KV cache budgets.
