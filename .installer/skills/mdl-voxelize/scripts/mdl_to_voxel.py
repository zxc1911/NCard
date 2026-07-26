"""将 TapMaker/UrhoX UMD2 .mdl 网格转换为 voxel JSON。

本工具是 Higgsfield TapMaker 工作流中的本地 MDL 转换路径。它直接读取运行时
Model 文件，默认采样第一个几何体 LOD，并写出
scripts/higgsfield/VoxelSceneRenderer.lua 可消费的轻量 voxel JSON 格式。

示例:
  python3 <skill>/scripts/mdl_to_voxel.py \
    --mdl assets/Meshes/TripoModel.mdl \
    --texture assets/Textures/TripoModel_00_D.jpg \
    --out assets/voxels/tripo_model_voxel.json \
    --scene-id tripo_model_voxel \
    --max-width 48 --max-height 48 --max-depth 48
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import xml.etree.ElementTree as ET
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path

try:
    from PIL import Image
except Exception:  # pragma: no cover - optional dependency in some hosts
    Image = None


Rgb = tuple[int, int, int]
Vec2 = tuple[float, float]
Vec3 = tuple[float, float, float]

TYPE_FLOAT = 1
TYPE_VECTOR2 = 2
TYPE_VECTOR3 = 3
TYPE_VECTOR4 = 4
TYPE_UBYTE4 = 5
TYPE_UBYTE4_NORM = 6

SEM_POSITION = 0
SEM_TEXCOORD = 4

ELEMENT_TYPE_SIZES = {
    0: 4,
    TYPE_FLOAT: 4,
    TYPE_VECTOR2: 8,
    TYPE_VECTOR3: 12,
    TYPE_VECTOR4: 16,
    TYPE_UBYTE4: 4,
    TYPE_UBYTE4_NORM: 4,
}


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def quantize_channel(value: int, levels: int) -> int:
    if levels <= 1:
        return 0
    step = 255 / (levels - 1)
    return clamp(round(round(value / step) * step), 0, 255)


def quantize_rgb(rgb: Rgb, levels: int) -> Rgb:
    return tuple(quantize_channel(c, levels) for c in rgb)


def grid_extent(value: float) -> int:
    return max(1, math.ceil(value - 1.0e-6))


def mix_rgb(values: list[Rgb]) -> Rgb:
    if not values:
        return (180, 180, 180)
    return (
        round(sum(v[0] for v in values) / len(values)),
        round(sum(v[1] for v in values) / len(values)),
        round(sum(v[2] for v in values) / len(values)),
    )


def mix_weighted_rgb(values: list[tuple[Rgb, float]]) -> Rgb:
    if not values:
        return (180, 180, 180)
    total_weight = sum(max(weight, 1.0e-6) for _, weight in values)
    return (
        round(sum(rgb[0] * max(weight, 1.0e-6) for rgb, weight in values) / total_weight),
        round(sum(rgb[1] * max(weight, 1.0e-6) for rgb, weight in values) / total_weight),
        round(sum(rgb[2] * max(weight, 1.0e-6) for rgb, weight in values) / total_weight),
    )


def dominant_quantized_rgb(values: list[tuple[Rgb, float]], levels: int) -> Rgb:
    if not values:
        return (180, 180, 180)
    votes: Counter[Rgb] = Counter()
    for rgb, weight in values:
        votes[quantize_rgb(rgb, levels)] += max(weight, 1.0e-6)
    return sorted(votes.items(), key=lambda item: (-item[1], item[0]))[0][0]


def resolve_rgb(values: list[tuple[Rgb, float]], levels: int, aggregation: str) -> Rgb:
    if aggregation == "dominant":
        return dominant_quantized_rgb(values, levels)
    return quantize_rgb(mix_weighted_rgb(values), levels)


def color_distance_sq(a: Rgb, b: Rgb) -> int:
    return (a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2


def merge_to_major_palette(resolved: dict[tuple[int, int, int], Rgb], max_colors: int) -> dict[tuple[int, int, int], Rgb]:
    if max_colors <= 0:
        return resolved
    color_counts = Counter(resolved.values())
    if len(color_counts) <= max_colors:
        return resolved

    major_colors = [
        rgb for rgb, _ in sorted(color_counts.items(), key=lambda item: (-item[1], item[0]))[:max_colors]
    ]
    major_set = set(major_colors)
    nearest_cache: dict[Rgb, Rgb] = {}

    def nearest_major(rgb: Rgb) -> Rgb:
        if rgb in major_set:
            return rgb
        if rgb not in nearest_cache:
            nearest_cache[rgb] = min(
                major_colors,
                key=lambda candidate: (color_distance_sq(rgb, candidate), -color_counts[candidate], candidate),
            )
        return nearest_cache[rgb]

    return {key: nearest_major(rgb) for key, rgb in resolved.items()}


def smooth_color_regions(
    resolved: dict[tuple[int, int, int], Rgb],
    radius: int,
    iterations: int,
) -> dict[tuple[int, int, int], Rgb]:
    if radius <= 0 or iterations <= 0:
        return resolved

    offsets = []
    max_distance = max(1, radius * 2)
    for dx in range(-radius, radius + 1):
        for dy in range(-radius, radius + 1):
            for dz in range(-radius, radius + 1):
                distance = abs(dx) + abs(dy) + abs(dz)
                if distance <= max_distance:
                    offsets.append((dx, dy, dz, max(1, max_distance + 1 - distance)))

    smoothed = dict(resolved)
    for _ in range(iterations):
        next_colors = {}
        for (x, y, z), rgb in smoothed.items():
            votes: Counter[Rgb] = Counter()
            for dx, dy, dz, weight in offsets:
                neighbor = (x + dx, y + dy, z + dz)
                if neighbor in smoothed:
                    votes[smoothed[neighbor]] += weight
            next_colors[(x, y, z)] = votes.most_common(1)[0][0] if votes else rgb
        smoothed = next_colors
    return smoothed


def merged_voxel_items(
    resolved: dict[tuple[int, int, int], Rgb],
    merge_size: int,
    min_fill: int,
    min_color_ratio: float,
) -> tuple[list[tuple[tuple[int, int, int], int, Rgb]], int]:
    if merge_size <= 1:
        return [(key, 1, rgb) for key, rgb in resolved.items()], 0

    volume = merge_size ** 3
    min_fill = clamp(min_fill, 1, volume)
    min_color_ratio = max(0.0, min(1.0, min_color_ratio))
    blocks: dict[tuple[int, int, int], list[tuple[tuple[int, int, int], Rgb]]] = defaultdict(list)
    items: list[tuple[tuple[int, int, int], int, Rgb]] = []
    merged_count = 0

    for key, rgb in resolved.items():
        x, y, z = key
        origin = (
            (x // merge_size) * merge_size,
            (y // merge_size) * merge_size,
            (z // merge_size) * merge_size,
        )
        blocks[origin].append((key, rgb))

    for origin, cells in sorted(blocks.items(), key=lambda item: (item[0][1], item[0][2], item[0][0])):
        color_counts = Counter(rgb for _, rgb in cells)
        dominant_rgb, dominant_count = color_counts.most_common(1)[0]
        can_merge = len(cells) >= min_fill and (dominant_count / len(cells)) >= min_color_ratio

        if can_merge:
            items.append((origin, merge_size, dominant_rgb))
            merged_count += 1
        else:
            for key, rgb in sorted(cells, key=lambda item: (item[0][1], item[0][2], item[0][0])):
                items.append((key, 1, rgb))

    return items, merged_count


def brightness(rgb: Rgb) -> float:
    r, g, b = rgb
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def repair_dark_outliers(
    resolved: dict[tuple[int, int, int], Rgb],
    threshold: float,
    max_component: int,
    min_boundary: int,
) -> tuple[dict[tuple[int, int, int], Rgb], dict[str, int]]:
    if threshold <= 0 or max_component <= 0:
        return resolved, {"components": 0, "voxels": 0}

    dark_keys = {key for key, rgb in resolved.items() if brightness(rgb) * 255.0 < threshold}
    if not dark_keys:
        return resolved, {"components": 0, "voxels": 0}

    repaired = dict(resolved)
    visited: set[tuple[int, int, int]] = set()
    repaired_components = 0
    repaired_voxels = 0
    neighbor_offsets = (
        (1, 0, 0),
        (-1, 0, 0),
        (0, 1, 0),
        (0, -1, 0),
        (0, 0, 1),
        (0, 0, -1),
    )

    for start in sorted(dark_keys, key=lambda key: (key[1], key[2], key[0])):
        if start in visited:
            continue

        stack = [start]
        component = []
        visited.add(start)
        while stack:
            x, y, z = stack.pop()
            component.append((x, y, z))
            for dx, dy, dz in neighbor_offsets:
                neighbor = (x + dx, y + dy, z + dz)
                if neighbor in dark_keys and neighbor not in visited:
                    visited.add(neighbor)
                    stack.append(neighbor)

        if len(component) > max_component:
            continue

        boundary_votes: Counter[Rgb] = Counter()
        for x, y, z in component:
            for dx, dy, dz in neighbor_offsets:
                neighbor = (x + dx, y + dy, z + dz)
                rgb = resolved.get(neighbor)
                if rgb and neighbor not in dark_keys and brightness(rgb) * 255.0 >= threshold:
                    boundary_votes[rgb] += 1

        if sum(boundary_votes.values()) < min_boundary:
            continue

        replacement = sorted(boundary_votes.items(), key=lambda item: (-item[1], item[0]))[0][0]
        for key in component:
            repaired[key] = replacement
        repaired_components += 1
        repaired_voxels += len(component)

    return repaired, {"components": repaired_components, "voxels": repaired_voxels}


def palette_target(rgb: Rgb) -> str:
    r, g, b = rgb
    if max(rgb) - min(rgb) < 20:
        if brightness(rgb) < 0.25:
            return "materials/stone_dark"
        if brightness(rgb) > 0.78:
            return "materials/stone_light"
        return "materials/stone_mid"
    if b > r + 30 and b > g + 5:
        return "materials/blue"
    if g > r + 20 and g > b + 5:
        return "materials/green"
    if r > 160 and g < 90 and b < 90:
        return "materials/red"
    return "materials/mixed"


class BinaryReader:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.offset = 0

    def read(self, size: int) -> bytes:
        if self.offset + size > len(self.data):
            raise ValueError("unexpected end of file")
        chunk = self.data[self.offset : self.offset + size]
        self.offset += size
        return chunk

    def u8x4(self) -> tuple[int, int, int, int]:
        return struct.unpack("<BBBB", self.read(4))

    def u32(self) -> int:
        return struct.unpack("<I", self.read(4))[0]

    def f32(self) -> float:
        return struct.unpack("<f", self.read(4))[0]


@dataclass
class VertexElement:
    element_type: int
    semantic: int
    index: int
    per_instance: int
    offset: int
    size: int


@dataclass
class VertexBuffer:
    vertex_count: int
    stride: int
    elements: list[VertexElement]
    raw: bytes
    positions: list[Vec3]
    texcoords: list[Vec2 | None]


@dataclass
class IndexBuffer:
    index_count: int
    index_size: int
    indices: list[int]


@dataclass
class GeometryLod:
    distance: float
    primitive_type: int
    vertex_buffer: int
    index_buffer: int
    index_start: int
    index_count: int


@dataclass
class MdlModel:
    vertex_buffers: list[VertexBuffer]
    index_buffers: list[IndexBuffer]
    geometries: list[list[GeometryLod]]


@dataclass
class PrefabLinks:
    model_uuid: str
    prefab_uuids: list[str]
    material_uuids: list[str]


@dataclass
class ResolvedPrefab:
    mdl_path: Path
    model_uuid: str
    prefab_chain: list[tuple[str, Path]]
    material_uuids: list[str]
    diffuse_textures: list[Path]


class TextureSampler:
    def __init__(self, path: Path | None, fallback: Rgb, flip_v: bool) -> None:
        self.fallback = fallback
        self.flip_v = flip_v
        self.image = None
        self.width = 0
        self.height = 0
        if path and Image:
            image = Image.open(path).convert("RGB")
            self.image = image
            self.width, self.height = image.size

    def sample(self, uv: Vec2 | None) -> Rgb:
        if not self.image or uv is None:
            return self.fallback
        u = uv[0] % 1.0
        v = uv[1] % 1.0
        if self.flip_v:
            v = 1.0 - v
        x = clamp(round(u * (self.width - 1)), 0, self.width - 1)
        y = clamp(round(v * (self.height - 1)), 0, self.height - 1)
        return self.image.getpixel((x, y))


def element_size(element_type: int) -> int:
    if element_type not in ELEMENT_TYPE_SIZES:
        raise ValueError(f"unsupported vertex element type: {element_type}")
    return ELEMENT_TYPE_SIZES[element_type]


def read_vector2(raw: bytes, offset: int) -> Vec2:
    return struct.unpack_from("<ff", raw, offset)


def read_vector3(raw: bytes, offset: int) -> Vec3:
    return struct.unpack_from("<fff", raw, offset)


def parse_vertex_buffer(reader: BinaryReader) -> VertexBuffer:
    vertex_count = reader.u32()
    element_count = reader.u32()

    elements: list[VertexElement] = []
    stride = 0
    for _ in range(element_count):
        element_type, semantic, index, per_instance = reader.u8x4()
        size = element_size(element_type)
        elements.append(VertexElement(element_type, semantic, index, per_instance, stride, size))
        stride += size

    # UMD2 stores the morph range before the raw interleaved vertex stream.
    reader.u32()
    reader.u32()

    raw = reader.read(vertex_count * stride)
    position_element = next((e for e in elements if e.semantic == SEM_POSITION), None)
    texcoord_element = next((e for e in elements if e.semantic == SEM_TEXCOORD and e.index == 0), None)
    if not position_element or position_element.element_type != TYPE_VECTOR3:
        raise ValueError("vertex buffer does not contain vector3 positions")

    positions = []
    texcoords = []
    for i in range(vertex_count):
        base = i * stride
        positions.append(read_vector3(raw, base + position_element.offset))
        if texcoord_element and texcoord_element.element_type == TYPE_VECTOR2:
            texcoords.append(read_vector2(raw, base + texcoord_element.offset))
        else:
            texcoords.append(None)

    return VertexBuffer(vertex_count, stride, elements, raw, positions, texcoords)


def parse_index_buffer(reader: BinaryReader) -> IndexBuffer:
    index_count = reader.u32()
    index_size = reader.u32()
    if index_size not in (2, 4):
        raise ValueError(f"unsupported index size: {index_size}")

    raw = reader.read(index_count * index_size)
    fmt = "<" + ("H" if index_size == 2 else "I") * index_count
    indices = list(struct.unpack(fmt, raw))
    return IndexBuffer(index_count, index_size, indices)


def parse_geometries(reader: BinaryReader) -> list[list[GeometryLod]]:
    geometries: list[list[GeometryLod]] = []
    geometry_count = reader.u32()
    for _ in range(geometry_count):
        bone_mapping_count = reader.u32()
        for _ in range(bone_mapping_count):
            reader.u32()

        lod_count = reader.u32()
        lods = []
        for _ in range(lod_count):
            lods.append(
                GeometryLod(
                    distance=reader.f32(),
                    primitive_type=reader.u32(),
                    vertex_buffer=reader.u32(),
                    index_buffer=reader.u32(),
                    index_start=reader.u32(),
                    index_count=reader.u32(),
                )
            )
        geometries.append(lods)
    return geometries


def parse_mdl(path: Path) -> MdlModel:
    reader = BinaryReader(path.read_bytes())
    magic = reader.read(4)
    if magic != b"UMD2":
        raise ValueError(f"{path} 使用 {magic!r} 文件头；当前 MDL 路径只支持 UMD2 文件")

    vertex_buffers = [parse_vertex_buffer(reader) for _ in range(reader.u32())]
    index_buffers = [parse_index_buffer(reader) for _ in range(reader.u32())]
    geometries = parse_geometries(reader)
    return MdlModel(vertex_buffers, index_buffers, geometries)


def normalize_uuid(value: str) -> str:
    return value.removeprefix("uuid://").strip()


def resource_uuids(value: str) -> list[str]:
    return [
        normalize_uuid(part)
        for part in value.split(";")
        if part.startswith("uuid://")
    ]


def find_resource_by_uuid(asset_root: Path, meta_pattern: str, resource_uuid: str) -> Path:
    wanted = normalize_uuid(resource_uuid)
    for meta_path in asset_root.rglob(meta_pattern):
        try:
            data = json.loads(meta_path.read_text(encoding="utf-8"))
        except Exception:
            continue
        if normalize_uuid(str(data.get("uuid", ""))) == wanted:
            resource_path = meta_path.with_suffix("")
            if resource_path.exists():
                return resource_path
    raise FileNotFoundError(f"no local resource found for uuid {wanted} under {asset_root}")


def find_mdl_by_uuid(asset_root: Path, model_uuid: str) -> Path:
    return find_resource_by_uuid(asset_root, "*.mdl.meta", model_uuid)


def find_prefab_by_uuid(asset_root: Path, prefab_uuid: str) -> Path:
    return find_resource_by_uuid(asset_root, "*.prefab.meta", prefab_uuid)


def find_material_by_uuid(asset_root: Path, material_uuid: str) -> Path:
    return find_resource_by_uuid(asset_root, "*.material.meta", material_uuid)


def find_texture_by_uuid(asset_root: Path, texture_uuid: str) -> Path:
    patterns = ("*.tga.meta", "*.png.meta", "*.jpg.meta", "*.jpeg.meta", "*.webp.meta", "*.bmp.meta")
    last_error: Exception | None = None
    for pattern in patterns:
        try:
            return find_resource_by_uuid(asset_root, pattern, texture_uuid)
        except FileNotFoundError as error:
            last_error = error
    raise FileNotFoundError(f"no local texture found for uuid {normalize_uuid(texture_uuid)} under {asset_root}") from last_error


def parse_prefab_links(prefab_path: Path) -> PrefabLinks:
    root = ET.parse(prefab_path).getroot()
    model_uuid = ""
    prefab_uuids: list[str] = []
    material_uuids: list[str] = []

    for attribute in root.iter("attribute"):
        name = attribute.attrib.get("name", "")
        value = attribute.attrib.get("value", "")
        uuids = resource_uuids(value)
        if name == "Model" and uuids:
            model_uuid = uuids[0]
        elif name == "Prefab" and uuids:
            prefab_uuids.extend(uuids)
        elif name == "Material" and uuids:
            material_uuids.extend(uuids)

    return PrefabLinks(model_uuid=model_uuid, prefab_uuids=prefab_uuids, material_uuids=material_uuids)


def diffuse_texture_for_material(asset_root: Path, material_uuid: str) -> Path | None:
    material_path = find_material_by_uuid(asset_root, material_uuid)
    root = ET.parse(material_path).getroot()
    for texture in root.iter("texture"):
        if texture.attrib.get("unit") != "diffuse":
            continue
        uuids = resource_uuids(texture.attrib.get("name", ""))
        if uuids:
            return find_texture_by_uuid(asset_root, uuids[0])
    return None


def resolve_prefab_to_mdl(asset_root: Path, prefab_uuid: str) -> ResolvedPrefab:
    current_uuid = normalize_uuid(prefab_uuid)
    seen: set[str] = set()
    prefab_chain: list[tuple[str, Path]] = []

    for _ in range(8):
        if current_uuid in seen:
            raise ValueError(f"prefab uuid cycle detected at {current_uuid}")
        seen.add(current_uuid)

        prefab_path = find_prefab_by_uuid(asset_root, current_uuid)
        prefab_chain.append((current_uuid, prefab_path))
        links = parse_prefab_links(prefab_path)
        if links.model_uuid:
            mdl_path = find_mdl_by_uuid(asset_root, links.model_uuid)
            diffuse_textures: list[Path] = []
            for material_uuid in links.material_uuids:
                try:
                    texture = diffuse_texture_for_material(asset_root, material_uuid)
                except FileNotFoundError:
                    texture = None
                if texture:
                    diffuse_textures.append(texture)
            return ResolvedPrefab(
                mdl_path=mdl_path,
                model_uuid=links.model_uuid,
                prefab_chain=prefab_chain,
                material_uuids=links.material_uuids,
                diffuse_textures=diffuse_textures,
            )

        if not links.prefab_uuids:
            raise ValueError(f"prefab {current_uuid} does not reference a model or nested prefab")
        current_uuid = links.prefab_uuids[0]

    raise ValueError(f"prefab chain is too deep for {normalize_uuid(prefab_uuid)}")


def display_path(path: Path) -> str:
    return str(path).replace("\\", "/")


def selected_lods(model: MdlModel, lod_index: int) -> list[GeometryLod]:
    lods: list[GeometryLod] = []
    for geometry in model.geometries:
        if not geometry:
            continue
        lods.append(geometry[min(lod_index, len(geometry) - 1)])
    return lods


def triangle_vertices(model: MdlModel, lod: GeometryLod):
    if lod.primitive_type != 0:
        return
    vb = model.vertex_buffers[lod.vertex_buffer]
    ib = model.index_buffers[lod.index_buffer]
    end = min(lod.index_start + lod.index_count, len(ib.indices))
    for offset in range(lod.index_start, end - 2, 3):
        ia, ib_index, ic = ib.indices[offset : offset + 3]
        if ia >= vb.vertex_count or ib_index >= vb.vertex_count or ic >= vb.vertex_count:
            continue
        yield (
            vb.positions[ia],
            vb.positions[ib_index],
            vb.positions[ic],
            vb.texcoords[ia],
            vb.texcoords[ib_index],
            vb.texcoords[ic],
        )


def bounds_for_lods(model: MdlModel, lods: list[GeometryLod]) -> tuple[Vec3, Vec3]:
    mins = [math.inf, math.inf, math.inf]
    maxs = [-math.inf, -math.inf, -math.inf]
    for lod in lods:
        for a, b, c, *_ in triangle_vertices(model, lod):
            for point in (a, b, c):
                for axis in range(3):
                    mins[axis] = min(mins[axis], point[axis])
                    maxs[axis] = max(maxs[axis], point[axis])
    if mins[0] == math.inf:
        raise ValueError("no triangles found in selected MDL LOD")
    return (mins[0], mins[1], mins[2]), (maxs[0], maxs[1], maxs[2])


def triangle_area(a: Vec3, b: Vec3, c: Vec3) -> float:
    ab = (b[0] - a[0], b[1] - a[1], b[2] - a[2])
    ac = (c[0] - a[0], c[1] - a[1], c[2] - a[2])
    cross = (
        ab[1] * ac[2] - ab[2] * ac[1],
        ab[2] * ac[0] - ab[0] * ac[2],
        ab[0] * ac[1] - ab[1] * ac[0],
    )
    return 0.5 * math.sqrt(cross[0] ** 2 + cross[1] ** 2 + cross[2] ** 2)


def vec_sub(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def dot(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def closest_triangle_weights(point: Vec3, a: Vec3, b: Vec3, c: Vec3) -> tuple[float, float, float]:
    ab = vec_sub(b, a)
    ac = vec_sub(c, a)
    ap = vec_sub(point, a)
    d1 = dot(ab, ap)
    d2 = dot(ac, ap)
    if d1 <= 0.0 and d2 <= 0.0:
        return (1.0, 0.0, 0.0)

    bp = vec_sub(point, b)
    d3 = dot(ab, bp)
    d4 = dot(ac, bp)
    if d3 >= 0.0 and d4 <= d3:
        return (0.0, 1.0, 0.0)

    vc = d1 * d4 - d3 * d2
    if vc <= 0.0 and d1 >= 0.0 and d3 <= 0.0:
        v = d1 / (d1 - d3)
        return (1.0 - v, v, 0.0)

    cp = vec_sub(point, c)
    d5 = dot(ab, cp)
    d6 = dot(ac, cp)
    if d6 >= 0.0 and d5 <= d6:
        return (0.0, 0.0, 1.0)

    vb = d5 * d2 - d1 * d6
    if vb <= 0.0 and d2 >= 0.0 and d6 <= 0.0:
        w = d2 / (d2 - d6)
        return (1.0 - w, 0.0, w)

    va = d3 * d6 - d5 * d4
    if va <= 0.0 and (d4 - d3) >= 0.0 and (d5 - d6) >= 0.0:
        w = (d4 - d3) / ((d4 - d3) + (d5 - d6))
        return (0.0, 1.0 - w, w)

    denom = 1.0 / (va + vb + vc)
    v = vb * denom
    w = vc * denom
    return (1.0 - v - w, v, w)


def barycentric_samples(step_count: int):
    yield (1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0)
    if step_count <= 0:
        return
    for i in range(step_count + 1):
        for j in range(step_count + 1 - i):
            u = i / step_count
            v = j / step_count
            w = 1.0 - u - v
            yield (u, v, w)


def lerp3(a: Vec3, b: Vec3, c: Vec3, weights: tuple[float, float, float]) -> Vec3:
    u, v, w = weights
    return (
        a[0] * u + b[0] * v + c[0] * w,
        a[1] * u + b[1] * v + c[1] * w,
        a[2] * u + b[2] * v + c[2] * w,
    )


def lerp2(a: Vec2 | None, b: Vec2 | None, c: Vec2 | None, weights: tuple[float, float, float]) -> Vec2 | None:
    if a is None or b is None or c is None:
        return None
    u, v, w = weights
    return (a[0] * u + b[0] * v + c[0] * w, a[1] * u + b[1] * v + c[1] * w)


def nearby_barycentric_samples(weights: tuple[float, float, float], count: int):
    yield weights
    if count <= 1:
        return

    jitters = [
        (0.14, -0.07, -0.07),
        (-0.07, 0.14, -0.07),
        (-0.07, -0.07, 0.14),
        (0.10, 0.10, -0.20),
        (0.10, -0.20, 0.10),
        (-0.20, 0.10, 0.10),
        (0.18, -0.18, 0.0),
        (-0.18, 0.0, 0.18),
    ]
    yielded = 1
    for du, dv, dw in jitters:
        if yielded >= count:
            return
        u = max(0.0, weights[0] + du)
        v = max(0.0, weights[1] + dv)
        w = max(0.0, weights[2] + dw)
        total = u + v + w
        if total <= 1.0e-6:
            continue
        yield (u / total, v / total, w / total)
        yielded += 1


def voxel_coord(point: Vec3, min_v: Vec3, scale: float, width: int, height: int, depth: int) -> tuple[int, int, int]:
    return (
        clamp(math.floor((point[0] - min_v[0]) * scale), 0, width - 1),
        clamp(math.floor((point[1] - min_v[1]) * scale), 0, height - 1),
        clamp(math.floor((point[2] - min_v[2]) * scale), 0, depth - 1),
    )


def source_coord(x: int, y: int, z: int, min_v: Vec3, scale: float) -> Vec3:
    return (
        min_v[0] + (x + 0.5) / scale,
        min_v[1] + (y + 0.5) / scale,
        min_v[2] + (z + 0.5) / scale,
    )


def source_coord_offset(x: int, y: int, z: int, offset: Vec3, min_v: Vec3, scale: float) -> Vec3:
    return (
        min_v[0] + (x + 0.5 + offset[0]) / scale,
        min_v[1] + (y + 0.5 + offset[1]) / scale,
        min_v[2] + (z + 0.5 + offset[2]) / scale,
    )


def raster_coverage_offsets(sample_count: int) -> list[Vec3]:
    if sample_count <= 1:
        return [(0.0, 0.0, 0.0)]

    offsets: list[Vec3] = [(0.0, 0.0, 0.0)]
    if sample_count <= 9:
        for ox in (-0.25, 0.25):
            for oy in (-0.25, 0.25):
                for oz in (-0.25, 0.25):
                    offsets.append((ox, oy, oz))
        return offsets

    for ox in (-0.33, 0.0, 0.33):
        for oy in (-0.33, 0.0, 0.33):
            for oz in (-0.33, 0.0, 0.33):
                offset = (ox, oy, oz)
                if offset not in offsets:
                    offsets.append(offset)
    return offsets


def raster_triangle_voxels(
    a: Vec3,
    b: Vec3,
    c: Vec3,
    min_v: Vec3,
    scale: float,
    width: int,
    height: int,
    depth: int,
    thickness_voxels: float,
    coverage_samples: int,
    min_coverage: float,
):
    ax, ay, az = voxel_coord(a, min_v, scale, width, height, depth)
    bx, by, bz = voxel_coord(b, min_v, scale, width, height, depth)
    cx, cy, cz = voxel_coord(c, min_v, scale, width, height, depth)
    min_x = max(0, min(ax, bx, cx) - 1)
    max_x = min(width - 1, max(ax, bx, cx) + 1)
    min_y = max(0, min(ay, by, cy) - 1)
    max_y = min(height - 1, max(ay, by, cy) + 1)
    min_z = max(0, min(az, bz, cz) - 1)
    max_z = min(depth - 1, max(az, bz, cz) + 1)
    max_distance_sq = (thickness_voxels / scale) ** 2
    coverage_offsets = raster_coverage_offsets(coverage_samples)
    coverage_threshold = max(0.0, min(1.0, min_coverage))

    for x in range(min_x, max_x + 1):
        for y in range(min_y, max_y + 1):
            for z in range(min_z, max_z + 1):
                hits = 0
                best_distance_sq = None
                best_weights = None
                for offset in coverage_offsets:
                    point = source_coord_offset(x, y, z, offset, min_v, scale)
                    weights = closest_triangle_weights(point, a, b, c)
                    closest = lerp3(a, b, c, weights)
                    delta = vec_sub(point, closest)
                    distance_sq = dot(delta, delta)
                    if best_distance_sq is None or distance_sq < best_distance_sq:
                        best_distance_sq = distance_sq
                        best_weights = weights
                    if distance_sq <= max_distance_sq:
                        hits += 1
                coverage = hits / len(coverage_offsets)
                if best_weights and hits > 0 and coverage >= coverage_threshold:
                    yield x, y, z, best_weights, coverage


def voxelize(
    model: MdlModel,
    *,
    lod_index: int,
    max_width: int,
    max_height: int,
    max_depth: int,
    samples_per_triangle: int,
    fill_mode: str,
    surface_mode: str,
    surface_thickness: float,
    color_aggregation: str,
    color_levels: int,
    max_palette_colors: int,
    color_smooth_radius: int,
    color_smooth_iterations: int,
    raster_color_samples: int,
    raster_coverage_samples: int,
    raster_min_coverage: float,
    dark_repair_threshold: float,
    dark_repair_max_component: int,
    dark_repair_min_boundary: int,
    hybrid_merge_size: int,
    hybrid_merge_min_fill: int,
    hybrid_merge_min_color_ratio: float,
    grid_unit_m: float,
    textures: list[Path],
    base_rgb: Rgb,
    flip_v: bool,
):
    lods = selected_lods(model, lod_index)
    min_v, max_v = bounds_for_lods(model, lods)
    span = (
        max(max_v[0] - min_v[0], 1.0e-6),
        max(max_v[1] - min_v[1], 1.0e-6),
        max(max_v[2] - min_v[2], 1.0e-6),
    )
    scale = min(max_width / span[0], max_height / span[1], max_depth / span[2])
    width = grid_extent(span[0] * scale)
    height = grid_extent(span[1] * scale)
    depth = grid_extent(span[2] * scale)

    texture_samplers = [TextureSampler(path, base_rgb, flip_v) for path in textures]
    fallback_sampler = TextureSampler(None, base_rgb, flip_v)
    voxel_colors: dict[tuple[int, int, int], list[tuple[Rgb, float]]] = defaultdict(list)

    triangle_count = 0
    for geometry_index, lod in enumerate(lods):
        if texture_samplers:
            sampler = texture_samplers[min(geometry_index, len(texture_samplers) - 1)]
        else:
            sampler = fallback_sampler
        for a, b, c, uva, uvb, uvc in triangle_vertices(model, lod):
            triangle_count += 1
            area = max(triangle_area(a, b, c), 1.0e-6)
            if surface_mode == "raster":
                triangle_voxels = raster_triangle_voxels(
                    a,
                    b,
                    c,
                    min_v,
                    scale,
                    width,
                    height,
                    depth,
                    surface_thickness,
                    raster_coverage_samples,
                    raster_min_coverage,
                )
            else:
                adaptive_steps = max(1, min(samples_per_triangle, math.ceil(math.sqrt(area) * scale * 0.85)))
                triangle_voxels = (
                    (*voxel_coord(lerp3(a, b, c, weights), min_v, scale, width, height, depth), weights, 1.0)
                    for weights in barycentric_samples(adaptive_steps)
                )
            for x, y, z, weights, coverage in triangle_voxels:
                sample_weights = list(nearby_barycentric_samples(weights, raster_color_samples))
                sample_weight = area * coverage / max(1, len(sample_weights))
                for color_weights in sample_weights:
                    uv = lerp2(uva, uvb, uvc, color_weights)
                    voxel_colors[(x, y, z)].append((sampler.sample(uv), sample_weight))

    resolved = {
        key: resolve_rgb(values, color_levels, color_aggregation)
        for key, values in voxel_colors.items()
    }
    resolved = merge_to_major_palette(resolved, max_palette_colors)

    surface_voxel_count = len(resolved)
    if fill_mode == "column-solid":
        for x in range(width):
            for z in range(depth):
                column = sorted(y for vx, y, vz in resolved if vx == x and vz == z)
                if len(column) < 2:
                    continue
                low = column[0]
                high = column[-1]
                sample_color = resolved[(x, column[len(column) // 2], z)]
                for y in range(low, high + 1):
                    resolved.setdefault((x, y, z), sample_color)

    resolved = smooth_color_regions(resolved, color_smooth_radius, color_smooth_iterations)
    resolved, dark_repair = repair_dark_outliers(
        resolved,
        dark_repair_threshold,
        dark_repair_max_component,
        dark_repair_min_boundary,
    )
    voxel_items, merged_voxel_count = merged_voxel_items(
        resolved,
        hybrid_merge_size,
        hybrid_merge_min_fill,
        hybrid_merge_min_color_ratio,
    )

    color_counts: Counter[Rgb] = Counter()
    for _, item_size, rgb in voxel_items:
        color_counts[rgb] += item_size ** 3
    palette_rgbs = sorted(color_counts.keys(), key=lambda rgb: (-color_counts[rgb], rgb))
    palette_ids = {rgb: index for index, rgb in enumerate(palette_rgbs)}
    palette = [
        {
            "id": palette_ids[rgb],
            "target": palette_target(rgb),
            "rgb": list(rgb),
            "kind": "material",
            "local_prototype_only": True,
        }
        for rgb in palette_rgbs
    ]
    voxels = []
    for (x, y, z), item_size, rgb in sorted(voxel_items, key=lambda item: (item[0][1], item[0][2], item[0][0])):
        voxel = {"x": x, "y": y, "z": z, "p": palette_ids[rgb]}
        if item_size > 1:
            voxel["s"] = item_size
        voxels.append(voxel)

    return {
        "size": {"width": width, "height": height, "depth": depth, "unit": "voxel"},
        "palette": palette,
        "voxels": voxels,
        "metadata": {
            "triangle_count": triangle_count,
            "surface_voxel_count": surface_voxel_count,
            "solid_fill_count": len(resolved) - surface_voxel_count,
            "palette_count": len(palette),
            "max_palette_colors": max_palette_colors,
            "color_smooth_radius": color_smooth_radius,
            "color_smooth_iterations": color_smooth_iterations,
            "raster_color_samples": raster_color_samples,
            "raster_coverage_samples": raster_coverage_samples,
            "raster_min_coverage": raster_min_coverage,
            "dark_repair_threshold": dark_repair_threshold,
            "dark_repair_max_component": dark_repair_max_component,
            "dark_repair_min_boundary": dark_repair_min_boundary,
            "dark_repair_components": dark_repair["components"],
            "dark_repair_voxels": dark_repair["voxels"],
            "grid_unit_m": grid_unit_m,
            "hybrid_merge_size": hybrid_merge_size,
            "hybrid_merge_min_fill": hybrid_merge_min_fill,
            "hybrid_merge_min_color_ratio": hybrid_merge_min_color_ratio,
            "unit_voxel_count": len(resolved),
            "expanded_unit_voxel_count": sum(item_size ** 3 for _, item_size, _ in voxel_items),
            "merged_voxel_count": merged_voxel_count,
            "small_voxel_count": len(voxels) - merged_voxel_count,
            "source_bounds": {
                "min": {"x": min_v[0], "y": min_v[1], "z": min_v[2]},
                "max": {"x": max_v[0], "y": max_v[1], "z": max_v[2]},
            },
        },
    }


def parse_rgb(value: str) -> Rgb:
    parts = [int(part.strip()) for part in value.split(",")]
    if len(parts) != 3:
        raise argparse.ArgumentTypeError("RGB must be formatted like 180,180,180")
    return tuple(clamp(part, 0, 255) for part in parts)


def evaluate_quality(result, surface_mode: str, min_surface_voxels_per_triangle: float) -> dict:
    metadata = result["metadata"]
    triangle_count = max(1, int(metadata["triangle_count"]))
    surface_voxel_count = int(metadata["surface_voxel_count"])
    voxel_count = len(result["voxels"])
    surface_voxels_per_triangle = surface_voxel_count / triangle_count
    failures = []

    if surface_mode != "raster":
        failures.append("生产体素资产要求 surface_mode 为 raster")
    if surface_voxels_per_triangle < min_surface_voxels_per_triangle:
        failures.append(
            "表面体素密度过低 "
            f"({surface_voxels_per_triangle:.3f} < {min_surface_voxels_per_triangle:.3f})"
        )
    if surface_voxel_count <= 0 or voxel_count <= 0:
        failures.append("体素输出为空")

    return {
        "status": "pass" if not failures else "fail",
        "failures": failures,
        "surface_voxels_per_triangle": surface_voxels_per_triangle,
        "min_surface_voxels_per_triangle": min_surface_voxels_per_triangle,
        "requires_surface_mode": "raster",
    }


def print_probe(path: Path, model: MdlModel) -> None:
    print(f"MDL: {path}")
    print(f"  顶点缓冲(vertex_buffers): {len(model.vertex_buffers)}")
    for index, vb in enumerate(model.vertex_buffers):
        print(f"    [{index}] vertices={vb.vertex_count} stride={vb.stride} elements={[(e.element_type, e.semantic, e.index) for e in vb.elements]}")
    print(f"  索引缓冲(index_buffers): {len(model.index_buffers)}")
    for index, ib in enumerate(model.index_buffers):
        print(f"    [{index}] indices={ib.index_count} index_size={ib.index_size}")
    print(f"  几何体(geometries): {len(model.geometries)}")
    for index, lods in enumerate(model.geometries):
        print(f"    [{index}] lods={len(lods)}")
        for lod_index, lod in enumerate(lods):
            print(
                "      "
                f"lod={lod_index} distance={lod.distance:.3f} primitive={lod.primitive_type} "
                f"vb={lod.vertex_buffer} ib={lod.index_buffer} "
                f"index_start={lod.index_start} index_count={lod.index_count}"
            )


def main() -> None:
    parser = argparse.ArgumentParser(description="将 UrhoX/TapMaker UMD2 .mdl 转换为 TapMaker voxel JSON。")
    parser.add_argument("--mdl", type=Path)
    parser.add_argument("--model-uuid", help="通过匹配 assets/**/*.mdl.meta 中的 uuid 定位本地 .mdl。")
    parser.add_argument("--prefab-uuid", help="定位本地 prefab uuid，跟随嵌套 prefab，并体素化其引用的 MDL。")
    parser.add_argument("--asset-root", type=Path, default=Path("assets"))
    parser.add_argument("--out", type=Path)
    parser.add_argument("--scene-id", default="mdl_voxel")
    parser.add_argument(
        "--texture",
        type=Path,
        action="append",
        default=[],
        help="MDL 几何体的 diffuse 贴图。可重复传入，用于将 geometry 0、1、... 映射到不同贴图。",
    )
    parser.add_argument("--base-rgb", type=parse_rgb, default=(180, 180, 180))
    parser.add_argument("--flip-v", action=argparse.BooleanOptionalAction, default=False)
    parser.add_argument("--lod", type=int, default=0)
    parser.add_argument("--max-width", type=int, default=48)
    parser.add_argument("--max-height", type=int, default=48)
    parser.add_argument("--max-depth", type=int, default=48)
    parser.add_argument("--max-samples-per-triangle", type=int, default=3)
    parser.add_argument("--fill-mode", choices=["surface", "column-solid"], default="surface")
    parser.add_argument("--surface-mode", choices=["raster", "samples"], default="raster")
    parser.add_argument("--surface-thickness", type=float, default=0.5)
    parser.add_argument("--color-aggregation", choices=["dominant", "average"], default="dominant")
    parser.add_argument("--max-palette-colors", type=int, default=96)
    parser.add_argument("--color-smooth-radius", type=int, default=0)
    parser.add_argument("--color-smooth-iterations", type=int, default=0)
    parser.add_argument("--raster-color-samples", type=int, default=1)
    parser.add_argument("--raster-coverage-samples", type=int, default=1)
    parser.add_argument("--raster-min-coverage", type=float, default=0.0)
    parser.add_argument("--dark-repair-threshold", type=float, default=0.0)
    parser.add_argument("--dark-repair-max-component", type=int, default=24)
    parser.add_argument("--dark-repair-min-boundary", type=int, default=2)
    parser.add_argument("--grid-unit-m", type=float, default=0.5)
    parser.add_argument("--hybrid-merge-size", type=int, default=2)
    parser.add_argument("--hybrid-merge-min-fill", type=int, default=4)
    parser.add_argument("--hybrid-merge-min-color-ratio", type=float, default=0.75)
    parser.add_argument(
        "--allow-custom-voxel-size",
        action="store_true",
        help="允许非标准体素尺寸，仅用于本地诊断。生产输出只使用 0.5m 单元和 1m 合并单元。",
    )
    parser.add_argument("--quality-gate", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--min-surface-voxels-per-triangle", type=float, default=0.5)
    parser.add_argument("--color-levels", type=int, default=24)
    parser.add_argument("--probe-only", action="store_true")
    args = parser.parse_args()

    mdl_path = args.mdl
    source_model_uuid = normalize_uuid(args.model_uuid) if args.model_uuid else ""
    source_prefab_uuid = normalize_uuid(args.prefab_uuid) if args.prefab_uuid else ""
    source_prefab_chain: list[dict[str, str]] = []
    material_uuids: list[str] = []
    texture_paths = list(args.texture)

    if not mdl_path and args.prefab_uuid:
        resolved = resolve_prefab_to_mdl(args.asset_root, args.prefab_uuid)
        mdl_path = resolved.mdl_path
        source_model_uuid = normalize_uuid(resolved.model_uuid)
        source_prefab_chain = [
            {"uuid": prefab_uuid, "path": display_path(path)}
            for prefab_uuid, path in resolved.prefab_chain
        ]
        material_uuids = [normalize_uuid(uuid) for uuid in resolved.material_uuids]
        if not texture_paths:
            texture_paths = resolved.diffuse_textures

    if not mdl_path and args.model_uuid:
        mdl_path = find_mdl_by_uuid(args.asset_root, args.model_uuid)
    if not mdl_path:
        raise SystemExit("请提供 --mdl、--model-uuid 或 --prefab-uuid")

    model = parse_mdl(mdl_path)
    if args.probe_only:
        print_probe(mdl_path, model)
        return

    if not args.out:
        raise SystemExit("除非使用 --probe-only，否则必须提供 --out")
    if args.grid_unit_m <= 0:
        raise SystemExit("--grid-unit-m 必须大于 0")
    if args.hybrid_merge_size < 1:
        raise SystemExit("--hybrid-merge-size 至少为 1")
    if not args.allow_custom_voxel_size:
        if abs(args.grid_unit_m - 0.5) > 1.0e-6 or args.hybrid_merge_size != 2:
            raise SystemExit(
                "生产体素资产必须使用通用 0.5m/1m 规格 "
                "(--grid-unit-m 0.5 --hybrid-merge-size 2); "
                "只有本地诊断时才传入 --allow-custom-voxel-size"
            )
    if args.hybrid_merge_size == 1:
        args.hybrid_merge_min_fill = 1

    result = voxelize(
        model,
        lod_index=args.lod,
        max_width=args.max_width,
        max_height=args.max_height,
        max_depth=args.max_depth,
        samples_per_triangle=args.max_samples_per_triangle,
        fill_mode=args.fill_mode,
        surface_mode=args.surface_mode,
        surface_thickness=args.surface_thickness,
        color_aggregation=args.color_aggregation,
        color_levels=args.color_levels,
        max_palette_colors=args.max_palette_colors,
        color_smooth_radius=args.color_smooth_radius,
        color_smooth_iterations=args.color_smooth_iterations,
        raster_color_samples=args.raster_color_samples,
        raster_coverage_samples=args.raster_coverage_samples,
        raster_min_coverage=args.raster_min_coverage,
        dark_repair_threshold=args.dark_repair_threshold,
        dark_repair_max_component=args.dark_repair_max_component,
        dark_repair_min_boundary=args.dark_repair_min_boundary,
        hybrid_merge_size=args.hybrid_merge_size,
        hybrid_merge_min_fill=args.hybrid_merge_min_fill,
        hybrid_merge_min_color_ratio=args.hybrid_merge_min_color_ratio,
        grid_unit_m=args.grid_unit_m,
        textures=texture_paths,
        base_rgb=args.base_rgb,
        flip_v=args.flip_v,
    )
    quality = evaluate_quality(result, args.surface_mode, args.min_surface_voxels_per_triangle)
    if args.quality_gate and quality["status"] != "pass":
        raise SystemExit("体素质量门禁失败: " + "; ".join(quality["failures"]))

    scene = {
        "version": "0.1",
        "scene_id": args.scene_id,
        "source": {
            "input_type": "mdl",
            "input_mdl": display_path(mdl_path),
            "source_prefab_uuid": source_prefab_uuid,
            "source_prefab_chain": source_prefab_chain,
            "source_model_uuid": source_model_uuid,
            "material_uuids": material_uuids,
            "textures": [display_path(path) for path in texture_paths],
            "provider": "codex_mdl_voxelizer",
        },
        "size": result["size"],
        "origin": {"x": 0, "y": 0, "z": 0, "pivot": "bottom_center"},
        "palette": result["palette"],
        "voxels": result["voxels"],
        "metadata": {
            **result["metadata"],
            "fill_mode": args.fill_mode,
            "surface_mode": args.surface_mode,
            "surface_thickness": args.surface_thickness,
            "color_aggregation": args.color_aggregation,
            "max_palette_colors": args.max_palette_colors,
            "color_smooth_radius": args.color_smooth_radius,
            "color_smooth_iterations": args.color_smooth_iterations,
            "raster_color_samples": args.raster_color_samples,
            "raster_coverage_samples": args.raster_coverage_samples,
            "raster_min_coverage": args.raster_min_coverage,
            "dark_repair_threshold": args.dark_repair_threshold,
            "dark_repair_max_component": args.dark_repair_max_component,
            "dark_repair_min_boundary": args.dark_repair_min_boundary,
            "grid_unit_m": args.grid_unit_m,
            "hybrid_merge_size": args.hybrid_merge_size,
            "hybrid_merge_min_fill": args.hybrid_merge_min_fill,
            "hybrid_merge_min_color_ratio": args.hybrid_merge_min_color_ratio,
            "flip_v": args.flip_v,
            "quality_gate": quality,
            "lod": args.lod,
            "color_levels": args.color_levels,
        },
    }

    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(scene, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {
                "out": str(args.out),
                "scene_id": args.scene_id,
                "voxels": len(scene["voxels"]),
                "palette": len(scene["palette"]),
                "size": scene["size"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
