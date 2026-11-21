#!/usr/bin/env bash
# macOS sandbox-exec (Seatbelt) 実測検証スクリプト
# 用途: AI エージェントにツール権限を渡す際、プロンプト禁止ではなく
#       OS カーネル層で .env 読取・ワークスペース外書込を物理遮断できることを 1 分で確認する。
# 環境: macOS (Apple Silicon / Intel 共通), python3
# 安全: 一時ディレクトリ配下のみを作成し、終了時に自動削除します。

set -u

RAW_DIR="$(mktemp -d /tmp/agent-sandbox-demo.XXXXXX)"
# macOS では /tmp -> /private/tmp のため、Seatbelt 用に必ず realpath を解決する
DEMO_DIR="$(python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$RAW_DIR")"

cleanup() {
  rm -rf "$DEMO_DIR"
}
trap cleanup EXIT

mkdir -p "$DEMO_DIR/workspace" "$DEMO_DIR/outside"
echo "ERROR 2026-11-21T09:12:03Z db-primary connection refused (retry=3)" > "$DEMO_DIR/workspace/app.log"
echo "DB_PASSWORD=super_secret_dummy_value_12345" > "$DEMO_DIR/workspace/.env"
echo "HOST_DATA=do_not_touch" > "$DEMO_DIR/outside/hosts.dummy"
ln -sf "$DEMO_DIR/workspace/.env" "$DEMO_DIR/workspace/innocent.txt"

cat > "$DEMO_DIR/strict.sb" <<EOF
(version 1)
(allow default)

;; 1. 書き込みはデフォルト全拒否（Allowlist方式）
(deny file-write*)
(allow file-write*
  (subpath "$DEMO_DIR/workspace"))

;; 2. 秘密ファイル (.env / .env.*) はワークスペース内でも読み書き完全拒否
(deny file-read* file-write*
  (regex #"/\.env(\.[^/]+)?$"))
EOF

echo "=== Environment ==="
echo "macOS: $(sw_vers -productVersion) / CPU: $(sysctl -n machdep.cpu.brand_string)"
echo "Demo root (realpath): $DEMO_DIR"
echo

echo "=== [1] Without sandbox: cat workspace/.env (LEAKS) ==="
cat "$DEMO_DIR/workspace/.env"
echo "exit=$?"
echo

echo "=== [2] With sandbox: cat workspace/app.log (ALLOWED) ==="
sandbox-exec -f "$DEMO_DIR/strict.sb" cat "$DEMO_DIR/workspace/app.log"
echo "exit=$?"
echo

echo "=== [3] With sandbox: cat workspace/.env (DENIED) ==="
sandbox-exec -f "$DEMO_DIR/strict.sb" cat "$DEMO_DIR/workspace/.env" 2>&1
echo "exit=$?"
echo

echo "=== [4] With sandbox: symlink bypass cat innocent.txt -> .env (DENIED) ==="
sandbox-exec -f "$DEMO_DIR/strict.sb" cat "$DEMO_DIR/workspace/innocent.txt" 2>&1
echo "exit=$?"
echo

echo "=== [5] With sandbox: python3 open(.env) bypass (DENIED) ==="
sandbox-exec -f "$DEMO_DIR/strict.sb" python3 -c "print(open('$DEMO_DIR/workspace/.env').read())" 2>&1
echo "exit=$?"
echo

echo "=== [6] With sandbox: write outside workspace (DENIED) & write workspace/.env (DENIED) ==="
sandbox-exec -f "$DEMO_DIR/strict.sb" sh -c "echo x > '$DEMO_DIR/outside/pwned.txt'" 2>&1
echo "outside write exit=$?"
sandbox-exec -f "$DEMO_DIR/strict.sb" sh -c "echo 'LEAK=1' >> '$DEMO_DIR/workspace/.env'" 2>&1
echo ".env write exit=$?"
sandbox-exec -f "$DEMO_DIR/strict.sb" sh -c "echo 'clean output' > '$DEMO_DIR/workspace/ok.txt'" 2>&1
echo "workspace/ok.txt write exit=$?"
echo

echo "=== [7] Overhead benchmark (50 runs) ==="
python3 - "$DEMO_DIR" <<'PY'
import subprocess, sys, time

demo_dir = sys.argv[1]
def bench(cmd, n=50):
    t0 = time.perf_counter()
    for _ in range(n):
        subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    return (time.perf_counter() - t0) / n * 1000

base = bench(["cat", f"{demo_dir}/workspace/app.log"])
sb = bench(["sandbox-exec", "-f", f"{demo_dir}/strict.sb", "cat", f"{demo_dir}/workspace/app.log"])
print(f"plain cat avg:        {base:.2f} ms")
print(f"sandbox-exec cat avg: {sb:.2f} ms")
print(f"overhead:             +{sb - base:.2f} ms")
PY
