# Case 02 · A vocabulary label is not an embedding

What does ID `3590` buy you? The vocabulary answers `DB`. The embedding table gives its initial numeric input `x`: 4,096 learned coordinates for the **same row number**. This lookup involves no inference.

1. Obtain [`Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf` from this revision](https://huggingface.co/bartowski/Meta-Llama-3.1-8B-Instruct-GGUF/blob/bf5b95e96dac0462e2a09145ec66cae9a3f12067/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf) (4,920,739,232 bytes). Tokenizer-only fixtures do not contain weights.
2. From this directory, run `uv run --with gguf==0.19.0 python inspect_embedding.py /path/to/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf`. It maps the file and dequantizes only the three selected rows.
3. Check the shape and the first three / last coordinates (rounded to 4 decimals):

| ID | Text piece | First three | Last |
|---:|---|---|---:|
| 496 | `str` | −0.0052, +0.0030, +0.0092 | +0.0053 |
| 3590 | `DB` | +0.0092, +0.0037, +0.0092 | +0.0168 |
| 127242 | `不足` | +0.0107, −0.0126, −0.0126 | +0.0002 |

Byte-level vocabulary labels in GGUF can be encoded (`ä¸įè¶³` for the last row); a tokenizer decodes them to the text piece shown here. The table is a parameter; the selected row is an input to subsequent layers. These numbers are specific to the named checkpoint and quantization.
