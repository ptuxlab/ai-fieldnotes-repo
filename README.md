# ai-fieldnotes

**Hands-on field notes, reproducible benchmarks, and boundary tests for local LLMs and AI agent systems.**  
**プロンプト論ではなく、実機計測・境界検証・再現スクリプトだけを残す AI システム現場メモ。**

Frameworks and API wrappers change every few months. Hardware memory bandwidth, KV cache growth, and OS kernel permission boundaries do not.  
This repository collects **minimal, reproducible experiments** run on real hardware (starting from a 16GB Apple Silicon Mac) so engineers can verify claims in 60 seconds instead of guessing.

---

## Experiments / 実測検証一覧

| # | Stage | Experiment | What It Verifies | Key Measured Result |
|---:|---|---|---|---|
| 00 | Day 0 (Safety) | [**macOS `sandbox-exec` for AI Agents**](experiments/01-macos-sandbox-exec/) | Can OS kernel Seatbelt profiles deterministically block `.env` reads (including symlink & Python bypasses) and out-of-workspace writes? | 100% blocked (`Operation not permitted`); **`+18.04 ms`** overhead over 50 runs on Apple M3 |

*(Upcoming in strict curriculum order — Part 1: BPE Tokenizer blindspots, Embedding `x` & ReLU collapse, RAG vs Attention `Q·K` & XGrammar JSON; Part 2: 16GB VRAM budget & GGUF, Prefill vs Decode Roofline, KV cache reuse; Part 3: `vLLM` concurrency & GPU economics; Part 4: Agent OS, 2-stage RAG, Durable execution & private Evals.)*

---

## Principles / 方針

1. **Measured on real machines**: Every table and log is produced by running the attached script—no simulated benchmarks.
2. **Vendor-neutral & open**: Focused strictly on open tools, OS primitives, and transferable engineering fundamentals.
3. **Zero bloat**: Each experiment runs in ~1 minute inside an isolated temp directory and cleans up after itself.

---

## License

MIT License. See [`LICENSE`](LICENSE).
