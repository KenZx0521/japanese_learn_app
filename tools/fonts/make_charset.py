#!/usr/bin/env python3
"""產生字元集並子集化打包字型（reuse-and-verification.md §5.3）。

可重複執行：內容或介面文字變動後再跑一次即可。

    python3 tools/fonts/make_charset.py            # 只更新 charset_*.txt
    python3 tools/fonts/make_charset.py --subset   # 連子集字型一起重建

--subset 需要 fontTools（pip install fonttools）與 .verify-cache/fonts/ 內的上游字型，
缺檔時加 --download 從 github.com/google/fonts 下載。
"""
from __future__ import annotations

import argparse
import glob
import json
import re
import subprocess
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TOOLS = ROOT / "tools" / "fonts"
JOYO_FILE = TOOLS / "joyo_kanji.txt"
CACHE = ROOT / ".verify-cache"
FONT_CACHE = CACHE / "fonts"
BUILD = ROOT / "build" / "fonts"
ASSETS = ROOT / "assets" / "fonts"
LICENSES = ASSETS / "licenses"
CONTENT = ROOT / "rust" / "content"
VERIFY = ROOT / "build" / "verify"

BUDGET_BYTES = 12 * 1024 * 1024
UPSTREAM = "https://raw.githubusercontent.com/google/fonts/main/ofl"
SOURCES = {
    "KleeOne-Regular.ttf": "kleeone/KleeOne-Regular.ttf",
    "KleeOne-SemiBold.ttf": "kleeone/KleeOne-SemiBold.ttf",
    "NotoSansTC[wght].ttf": "notosanstc/NotoSansTC%5Bwght%5D.ttf",
    "NotoSerifTC[wght].ttf": "notoseriftc/NotoSerifTC%5Bwght%5D.ttf",
}
LICENSE_SOURCES = {
    "OFL-KleeOne.txt": "kleeone/OFL.txt",
    "OFL-NotoSansTC.txt": "notosanstc/OFL.txt",
    "OFL-NotoSerifTC.txt": "notoseriftc/OFL.txt",
}
SUBSET_FLAGS = [
    "--layout-features=kern,palt,liga,ccmp,locl,mark,mkmk",
    "--no-hinting",
    "--desubroutinize",
    "--name-IDs=*",
    "--notdef-outline",
    "--recalc-bounds",
]

ASCII = {chr(c) for c in range(0x20, 0x7F)}
JA_MARKER = re.compile(r"\{ja:([^{}]*)\}")
# §5.3 的範圍之外，另收拉丁補充與一般標點：·、—、›、× 這類符號少了會靜默落到系統字型
LIB_CHARS = re.compile(
    r"[\u00a0-\u00ff\u2000-\u206f\u2190-\u21ff"
    r"\u3000-\u303f\u3400-\u4dbf\u4e00-\u9fff\uff00-\uffef]"
)
UI_SYMBOLS = set("·—…×›○")
KANA_BLOCK = re.compile(r"[぀-ヿ]")
RUST_LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
RUST_GENERATED = {"frb_generated.rs"}
RUST_TEST_MARKER = "#[cfg(test)]"
# 中文欄位的鍵：其餘字串一律視為日文內容（id、schema 只有 ASCII，不影響結果）
ZH_KEYS = {"zh", "tai", "hanzi", "zh_tw", "zh_pattern", "aka_zh"}


def is_cjk(ch: str) -> bool:
    code = ord(ch)
    return (
        0x3000 <= code <= 0x30FF
        or 0x3400 <= code <= 0x4DBF
        or 0x4E00 <= code <= 0x9FFF
        or 0xFF00 <= code <= 0xFFEF
        or 0x20000 <= code <= 0x2FFFF
    )


def joyo_kanji() -> set[str]:
    """常用漢字：有 KANJIDIC2 快取時重建清單，否則用 repo 內的清單。"""
    candidates = sorted(glob.glob(str(CACHE / "kanjidic2*.json")))
    if candidates:
        data = json.loads(Path(candidates[-1]).read_text(encoding="utf-8"))
        chars = sorted(
            entry["literal"]
            for entry in data["characters"]
            if entry["misc"].get("grade") in {1, 2, 3, 4, 5, 6, 8}
        )
        JOYO_FILE.write_text("".join(chars) + "\n", encoding="utf-8")
    return set(JOYO_FILE.read_text(encoding="utf-8").strip())


def kana_and_punct() -> set[str]:
    ranges = [
        (0x3000, 0x303F),  # 全形標點，含 U+301C
        (0x3041, 0x3096),
        (0x309D, 0x309E),
        (0x30A1, 0x30FA),
        (0x30FB, 0x30FE),
        (0xFF01, 0xFF5E),
    ]
    extra = {"—", "‥", "…", "\U00020B9F"}
    return {chr(c) for lo, hi in ranges for c in range(lo, hi + 1)} | extra | ASCII


def big5_level1() -> set[str]:
    chars: set[str] = set()
    for lead in range(0xA4, 0xC7):
        for trail in list(range(0x40, 0x7F)) + list(range(0xA1, 0xFF)):
            if lead == 0xC6 and trail > 0x7E:
                continue
            try:
                chars.add(bytes([lead, trail]).decode("big5"))
            except UnicodeDecodeError:
                continue
    return chars


def fullwidth_punct() -> set[str]:
    return {chr(c) for c in range(0x3000, 0x3040)} | {chr(c) for c in range(0xFF00, 0xFFF0)}


def is_zh_key(key: str) -> bool:
    return key in ZH_KEYS or key.endswith("_zh")


def collect_strings(node, key: str, ja: set[str], zh: set[str]) -> None:
    if isinstance(node, dict):
        for child_key, value in node.items():
            collect_strings(value, child_key, ja, zh)
    elif isinstance(node, list):
        for value in node:
            collect_strings(value, key, ja, zh)
    elif isinstance(node, str):
        split_field(node, key, ja, zh)


def split_field(text: str, key: str, ja: set[str], zh: set[str]) -> None:
    if not is_zh_key(key):
        ja.update(ch for ch in text if is_cjk(ch))
        return
    for match in JA_MARKER.finditer(text):
        ja.update(ch for ch in match.group(1) if is_cjk(ch))
    zh.update(ch for ch in JA_MARKER.sub("", text) if is_cjk(ch))


def content_chars() -> tuple[set[str], set[str]]:
    """聯集 rust/content 的 JSON 與 content_tool charset 的輸出（若有）。"""
    ja: set[str] = set()
    zh: set[str] = set()
    for path in sorted(CONTENT.rglob("*.json")):
        collect_strings(json.loads(path.read_text(encoding="utf-8")), "", ja, zh)
    for name, target in (("chars_ja.txt", ja), ("chars_zh.txt", zh)):
        generated = VERIFY / name
        if generated.exists():
            target.update(generated.read_text(encoding="utf-8").strip())
    return ja, zh


def strip_line_comment(line: str) -> str:
    # 字串內的 // 只會是網址，這裡不需要處理跳脫，切掉 URL 尾端不影響用字
    index = line.find("//")
    return line if index < 0 else line[:index]


def lib_chars() -> set[str]:
    chars: set[str] = set()
    for path in sorted((ROOT / "lib").rglob("*.dart")):
        if "src/rust" in path.as_posix():
            continue
        for line in path.read_text(encoding="utf-8").splitlines():
            chars.update(LIB_CHARS.findall(strip_line_comment(line)))
    return {ch for ch in chars if not KANA_BLOCK.match(ch)}


def rust_source_files(root: Path) -> list[Path]:
    sources = sorted((root / "rust" / "src").rglob("*.rs"))
    sources += sorted((root / "rust" / "crates").glob("*/src/**/*.rs"))
    return [path for path in sources if path.name not in RUST_GENERATED]


def rust_ui_chars(root: Path = ROOT) -> set[str]:
    """Rust 組出的介面字串（Conjugate 題幹的 →、題型說明等）。

    這些字串不經過 lib/ 也不在內容 JSON，沒掃到就只能靠 lib 碰巧用到同一個字。
    與 lib_chars 同一組字元範圍；測試碼（#[cfg(test)] 之後）與生成碼不算介面字串。
    """
    chars: set[str] = set()
    for path in rust_source_files(root):
        text = path.read_text(encoding="utf-8").partition(RUST_TEST_MARKER)[0]
        for line in text.splitlines():
            for literal in RUST_LITERAL.findall(strip_line_comment(line)):
                chars.update(LIB_CHARS.findall(literal))
    return chars


def write_charset(name: str, chars: set[str]) -> int:
    ordered = "".join(sorted(chars))
    (TOOLS / name).write_text(ordered + "\n", encoding="utf-8")
    return len(ordered)


def generate_charsets() -> None:
    ja, zh = content_chars()
    lib = lib_chars()
    rust = rust_ui_chars()
    counts = {
        "charset_ja.txt": write_charset("charset_ja.txt", joyo_kanji() | kana_and_punct() | ja),
        "charset_noto_sans.txt": write_charset(
            "charset_noto_sans.txt",
            big5_level1() | fullwidth_punct() | ASCII | UI_SYMBOLS | zh | lib | rust,
        ),
        "charset_noto_serif.txt": write_charset(
            "charset_noto_serif.txt", lib | ASCII | UI_SYMBOLS
        ),
    }
    for name, count in counts.items():
        sys.stdout.write(f"{name}: {count} 字\n")


def download(url: str, target: Path) -> None:
    sys.stdout.write(f"下載 {url}\n")
    with urllib.request.urlopen(url, timeout=120) as response:  # noqa: S310
        target.write_bytes(response.read())


def ensure_sources(allow_download: bool) -> None:
    FONT_CACHE.mkdir(parents=True, exist_ok=True)
    LICENSES.mkdir(parents=True, exist_ok=True)
    for name, relative in SOURCES.items():
        target = FONT_CACHE / name
        if target.exists():
            continue
        if not allow_download:
            sys.exit(f"缺少 {target}，請加 --download")
        download(f"{UPSTREAM}/{relative}", target)
    for name, relative in LICENSE_SOURCES.items():
        target = LICENSES / name
        if target.exists():
            continue
        if not allow_download:
            sys.exit(f"缺少 {target}，請加 --download")
        download(f"{UPSTREAM}/{relative}", target)


def run_fonttools(*args: str) -> None:
    subprocess.run([sys.executable, "-I", "-m", "fontTools", *args], check=True)


def instantiate(source: str, weight: int, output: str) -> Path:
    BUILD.mkdir(parents=True, exist_ok=True)
    target = BUILD / output
    run_fonttools("varLib.instancer", str(FONT_CACHE / source), f"wght={weight}", "-o", str(target))
    return target


def subset(font: Path, charset: str, output: str) -> None:
    args = [
        "subset",
        str(font),
        f"--text-file={TOOLS / charset}",
        *SUBSET_FLAGS,
        f"--output-file={ASSETS / (output + '.subset.ttf')}",
    ]
    run_fonttools(*args)


def build_subsets() -> None:
    subset(FONT_CACHE / "KleeOne-Regular.ttf", "charset_ja.txt", "KleeOne-Regular")
    subset(FONT_CACHE / "KleeOne-SemiBold.ttf", "charset_ja.txt", "KleeOne-SemiBold")
    sans = "NotoSansTC[wght].ttf"
    subset(instantiate(sans, 400, "NotoSansTC-Regular.ttf"), "charset_noto_sans.txt", "NotoSansTC-Regular")
    subset(instantiate(sans, 700, "NotoSansTC-Bold.ttf"), "charset_noto_sans.txt", "NotoSansTC-Bold")
    serif = instantiate("NotoSerifTC[wght].ttf", 800, "NotoSerifTC-ExtraBold.ttf")
    subset(serif, "charset_noto_serif.txt", "NotoSerifTC-ExtraBold")
    total = 0
    for path in sorted(ASSETS.glob("*.subset.ttf")):
        size = path.stat().st_size
        total += size
        sys.stdout.write(f"{path.name}: {size / 1024 / 1024:.2f} MB\n")
    sys.stdout.write(f"合計 {total / 1024 / 1024:.2f} MB（預算 12 MB）\n")
    if total > BUDGET_BYTES:
        sys.stdout.write("警告：超過字型預算（F05）\n")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--subset", action="store_true", help="重建 assets/fonts/*.subset.ttf")
    parser.add_argument("--download", action="store_true", help="缺上游字型時下載")
    args = parser.parse_args()
    generate_charsets()
    if args.subset:
        ensure_sources(args.download)
        build_subsets()


if __name__ == "__main__":
    main()
