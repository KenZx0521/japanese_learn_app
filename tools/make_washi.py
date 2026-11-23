#!/usr/bin/env python3
"""產生 assets/textures/washi_256.png：灰階紙纖維（flutter-app.md §4.2）。

輸出是灰階＋透明度，底色全透明，疊在 paper.base 上不會改變文字對比。
亂數種子固定，重跑結果相同。只用標準函式庫。
"""
import math
import random
import struct
import zlib
from pathlib import Path

SIZE = 256
FIBERS = 90
SEED = 20261109
ALPHA_LEVELS = (40, 80, 120)
TARGET = Path(__file__).resolve().parents[1] / "assets" / "textures" / "washi_256.png"
SIZE_LIMIT = 20 * 1024


def draw_fiber(alpha: bytearray, rng: random.Random) -> None:
    x = rng.uniform(0, SIZE)
    y = rng.uniform(0, SIZE)
    angle = rng.uniform(0, math.tau)
    length = rng.randint(24, 72)
    level = rng.choice(ALPHA_LEVELS)
    for _ in range(length):
        index = int(y) % SIZE * SIZE + int(x) % SIZE
        alpha[index] = max(alpha[index], level)
        angle += rng.uniform(-0.22, 0.22)
        x += math.cos(angle)
        y += math.sin(angle)


def png_chunk(tag: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(tag + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", crc)


def encode(alpha: bytearray) -> bytes:
    raw = bytearray()
    for row in range(SIZE):
        raw.append(0)
        for value in alpha[row * SIZE : (row + 1) * SIZE]:
            raw += bytes((0, value))
    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 4, 0, 0, 0)
    return (
        b"\x89PNG\r\n\x1a\n"
        + png_chunk(b"IHDR", header)
        + png_chunk(b"IDAT", zlib.compress(bytes(raw), 9))
        + png_chunk(b"IEND", b"")
    )


def main() -> None:
    rng = random.Random(SEED)
    alpha = bytearray(SIZE * SIZE)
    for _ in range(FIBERS):
        draw_fiber(alpha, rng)
    data = encode(alpha)
    if len(data) > SIZE_LIMIT:
        raise SystemExit(f"紙紋 {len(data)} 位元組，超過 {SIZE_LIMIT}")
    TARGET.write_bytes(data)
    print(f"{TARGET.name}: {len(data)} 位元組")


if __name__ == "__main__":
    main()
