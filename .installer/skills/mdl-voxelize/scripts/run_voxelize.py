from __future__ import annotations

import argparse
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path


DEFAULT_CONFIG = {
    "output_dir": "assets/voxels",
    "scene_id": "",
    "max_width": 80,
    "max_height": 60,
    "max_depth": 80,
    "fill_mode": "surface",
    "surface_thickness": 0.55,
    "max_palette_colors": 64,
    "color_levels": 16,
    "raster_color_samples": 2,
    "raster_coverage_samples": 9,
    "raster_min_coverage": 0.45,
}


def load_config(path: Path) -> dict[str, object]:
    config = dict(DEFAULT_CONFIG)
    if not path.exists():
        return config
    data = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(data, dict):
        raise SystemExit(f"config.json 必须是 JSON object: {path}")
    for key in DEFAULT_CONFIG:
        if key in data:
            config[key] = data[key]
    if "out" in data:
        config["out"] = data["out"]
    return config


def cfg_int(config: dict[str, object], key: str) -> int:
    return int(config[key])


def cfg_float(config: dict[str, object], key: str) -> float:
    return float(config[key])


def cfg_str(config: dict[str, object], key: str) -> str:
    return str(config.get(key, "")).strip()


def source_stem(args: argparse.Namespace) -> str:
    if args.mdl:
        return Path(args.mdl).stem
    if args.model_uuid:
        return "model_" + args.model_uuid.replace("uuid://", "")[:8]
    if args.prefab_uuid:
        return "prefab_" + args.prefab_uuid.replace("uuid://", "")[:8]
    return "mdl"


def scene_id_from_stem(stem: str) -> str:
    normalized = re.sub(r"[^0-9A-Za-z_]+", "_", stem).strip("_").lower()
    return f"{normalized or 'mdl'}_voxel"


def default_out_path(config: dict[str, object], stem: str) -> str:
    output_dir = cfg_str(config, "output_dir") or str(DEFAULT_CONFIG["output_dir"])
    return str(Path(output_dir) / f"{stem}_voxel.json")


def ensure_pillow_fallback(requirements_path: Path) -> None:
    if importlib.util.find_spec("PIL") is not None:
        return

    command = [sys.executable, "-m", "pip", "install"]
    if requirements_path.exists():
        command += ["-r", str(requirements_path)]
    else:
        command += ["pillow"]
    subprocess.check_call(command)


def ensure_dependencies(script_dir: Path) -> None:
    check_env_path = script_dir / "check_env.py"
    if check_env_path.exists():
        result = subprocess.call([sys.executable, str(check_env_path)])
        if result != 0:
            raise SystemExit(result)
        return
    ensure_pillow_fallback(script_dir / "requirements.txt")


def split_textures(values: list[str]) -> list[str]:
    textures: list[str] = []
    for value in values:
        for part in value.split(","):
            trimmed = part.strip()
            if trimmed:
                textures.append(trimmed)
    return textures


def main() -> int:
    parser = argparse.ArgumentParser(
        description="将 UrhoX UMD2 .mdl 和 diffuse 贴图转换为生产可用的 voxel JSON。"
    )
    parser.add_argument("--project-root", type=Path, default=Path.cwd())
    parser.add_argument("--config", type=Path)
    parser.add_argument("--mdl")
    parser.add_argument("--model-uuid")
    parser.add_argument("--prefab-uuid")
    parser.add_argument("--asset-root", default="assets")
    parser.add_argument("--texture", action="append", default=[])
    parser.add_argument("--out")
    parser.add_argument("--scene-id")
    parser.add_argument("--max-width", type=int)
    parser.add_argument("--max-height", type=int)
    parser.add_argument("--max-depth", type=int)
    parser.add_argument("--fill-mode", choices=["surface", "column-solid"])
    parser.add_argument("--surface-thickness", type=float)
    parser.add_argument("--max-palette-colors", type=int)
    parser.add_argument("--color-levels", type=int)
    parser.add_argument("--raster-color-samples", type=int)
    parser.add_argument("--raster-coverage-samples", type=int)
    parser.add_argument("--raster-min-coverage", type=float)
    args = parser.parse_args()

    if not args.mdl and not args.model_uuid and not args.prefab_uuid:
        raise SystemExit("请提供 --mdl、--model-uuid 或 --prefab-uuid")

    script_dir = Path(__file__).resolve().parent
    config_path = args.config if args.config else script_dir.parent / "config.json"
    config = load_config(config_path)
    stem = source_stem(args)

    max_width = args.max_width if args.max_width is not None else cfg_int(config, "max_width")
    max_height = args.max_height if args.max_height is not None else cfg_int(config, "max_height")
    max_depth = args.max_depth if args.max_depth is not None else cfg_int(config, "max_depth")
    if max_width <= 0 or max_height <= 0 or max_depth <= 0:
        raise SystemExit("--max-width、--max-height 和 --max-depth 必须大于 0")

    voxelizer_path = script_dir / "mdl_to_voxel.py"
    if not voxelizer_path.exists():
        raise SystemExit(f"缺少核心体素化脚本: {voxelizer_path}")

    ensure_dependencies(script_dir)

    project_root = args.project_root.resolve()
    configured_out = cfg_str(config, "out")
    out_path = args.out or configured_out or default_out_path(config, stem)
    scene_id = args.scene_id or cfg_str(config, "scene_id") or scene_id_from_stem(stem)
    fill_mode = args.fill_mode or cfg_str(config, "fill_mode") or str(DEFAULT_CONFIG["fill_mode"])
    surface_thickness = args.surface_thickness if args.surface_thickness is not None else cfg_float(config, "surface_thickness")
    max_palette_colors = args.max_palette_colors if args.max_palette_colors is not None else cfg_int(config, "max_palette_colors")
    color_levels = args.color_levels if args.color_levels is not None else cfg_int(config, "color_levels")
    raster_color_samples = args.raster_color_samples if args.raster_color_samples is not None else cfg_int(config, "raster_color_samples")
    raster_coverage_samples = args.raster_coverage_samples if args.raster_coverage_samples is not None else cfg_int(config, "raster_coverage_samples")
    raster_min_coverage = args.raster_min_coverage if args.raster_min_coverage is not None else cfg_float(config, "raster_min_coverage")

    command = [
        sys.executable,
        str(voxelizer_path),
        "--out",
        out_path,
        "--scene-id",
        scene_id,
        "--max-width",
        str(max_width),
        "--max-height",
        str(max_height),
        "--max-depth",
        str(max_depth),
        "--surface-mode",
        "raster",
        "--surface-thickness",
        str(surface_thickness),
        "--fill-mode",
        fill_mode,
        "--color-aggregation",
        "dominant",
        "--max-palette-colors",
        str(max_palette_colors),
        "--color-levels",
        str(color_levels),
        "--raster-color-samples",
        str(raster_color_samples),
        "--raster-coverage-samples",
        str(raster_coverage_samples),
        "--raster-min-coverage",
        str(raster_min_coverage),
        "--grid-unit-m",
        "0.5",
        "--hybrid-merge-size",
        "2",
        "--hybrid-merge-min-fill",
        "4",
        "--hybrid-merge-min-color-ratio",
        "0.75",
        "--no-flip-v",
    ]

    if args.mdl:
        command += ["--mdl", args.mdl]
    if args.model_uuid:
        command += ["--model-uuid", args.model_uuid, "--asset-root", args.asset_root]
    if args.prefab_uuid:
        command += ["--prefab-uuid", args.prefab_uuid, "--asset-root", args.asset_root]

    for texture in split_textures(args.texture):
        command += ["--texture", texture]

    print("[voxelize] " + " ".join(command))
    return subprocess.call(command, cwd=project_root)


if __name__ == "__main__":
    raise SystemExit(main())
