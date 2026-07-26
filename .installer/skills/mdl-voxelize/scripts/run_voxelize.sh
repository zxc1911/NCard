#!/bin/sh
# 在 Linux/macOS 上运行生产体素化 launcher。

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

if command -v python3 >/dev/null 2>&1; then
  PY=python3
elif command -v python >/dev/null 2>&1; then
  PY=python
else
  echo "找不到 python3 或 python，请先安装 Python 3。"
  exit 1
fi

exec "$PY" "$SCRIPT_DIR/run_voxelize.py" "$@"
