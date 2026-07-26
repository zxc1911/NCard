"""校验生成的 voxel JSON 是否只使用 0.5m 和 1m 物理尺寸。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description="校验 voxel JSON 的物理体素尺寸。")
    parser.add_argument("json_files", nargs="+", type=Path, help="一个或多个 voxel JSON 文件。")
    args = parser.parse_args()

    for path in args.json_files:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
        metadata = data.get("metadata", {})
        grid_unit = float(metadata.get("grid_unit_m", data.get("grid_unit_m", 1.0)))
        sizes = sorted({round(grid_unit * float(voxel.get("s", 1)), 6) for voxel in data.get("voxels", [])})
        print(f"{path}: 体素尺寸(m)={sizes}")
        if not set(sizes).issubset({0.5, 1.0}):
            raise SystemExit(f"{path} 包含非标准体素尺寸: {sizes}")


if __name__ == "__main__":
    main()
