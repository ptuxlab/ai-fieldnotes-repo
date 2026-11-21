"""Look up one real embedding row at a time; do not dequantize the full table."""
import argparse
from pathlib import Path

import numpy as np
from gguf import GGUFReader, dequantize


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("gguf", type=Path, help="Path to the pinned Q4_K_M weights")
    args = parser.parse_args()
    reader = GGUFReader(args.gguf)
    table = next((t for t in reader.tensors if t.name == "token_embd.weight"), None)
    if table is None or list(table.shape) != [4096, 128256]:
        parser.error("expected token_embd.weight with GGUF dimensions [4096, 128256]")
    labels = reader.get_field("tokenizer.ggml.tokens")
    print(f"{table.name}: 128256 rows × 4096 coordinates ({table.tensor_type.name})")
    for token_id in (496, 3590, 127242):
        row = dequantize(table.data[token_id:token_id + 1], table.tensor_type).reshape(-1)
        if row.size != 4096 or not np.isfinite(row).all():
            raise ValueError(f"invalid row {token_id}")
        print(f"ID {token_id}: vocabulary label {labels.contents(token_id)!r}; "
              f"x[:3]={row[:3].round(4)}, x[-1]={row[-1]:+.4f}")


if __name__ == "__main__":
    main()
