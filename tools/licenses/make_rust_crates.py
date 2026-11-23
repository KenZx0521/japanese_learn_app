#!/usr/bin/env python3
"""產生 assets/licenses/rust_crates.txt：App 內建 Rust 核心的第三方 crate 清單（reuse-and-verification.md §10）。

範圍與 O8 的 L03 檢查相同（cargo tree -p jp_core -e normal,build --target all）：
不含 dev 相依，也不含只有 content_tool 用的 crate。授權欄取自 cargo metadata。
cargo metadata 的 resolve 圖會把整個 workspace 的 feature 併在一起，單看它會多列
測試與工具才帶入的 crate，所以範圍要用 cargo tree 決定。全程只讀本機 Cargo.lock
與 registry 快取（--locked --offline）。

    python3 tools/licenses/make_rust_crates.py          # 更新清單
    python3 tools/licenses/make_rust_crates.py --check  # 清單過期時 exit 1
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
RUST = ROOT / "rust"
OUTPUT = ROOT / "assets" / "licenses" / "rust_crates.txt"
ROOT_PACKAGE = "jp_core"
HEADER = (
    "# App 內建 Rust 核心的第三方 crate：名稱<TAB>版本<TAB>授權。\n"
    "# 由 tools/licenses/make_rust_crates.py 產生，請勿手改。\n"
)
# Cargo.toml 沒寫 license、只附 LICENSE 檔的 crate；值由人工確認該檔內容。
UNDECLARED_LICENSES = {
    "allo-isolate": "Apache-2.0",
    "rs-fsrs": "MIT",
}


def run_cargo(*args: str) -> str:
    command = ["cargo", *args, "--locked", "--offline"]
    try:
        return subprocess.run(
            command, cwd=RUST, check=True, capture_output=True, text=True
        ).stdout
    except (OSError, subprocess.CalledProcessError) as error:
        sys.exit(f"無法執行 {' '.join(command)}：{getattr(error, 'stderr', error)}")


def parse_tree(output: str) -> set[tuple[str, str]]:
    """`cargo tree --prefix none` 的輸出；路徑相依（workspace 自己的套件）不列入。"""
    crates: set[tuple[str, str]] = set()
    for line in output.splitlines():
        parts = line.split()
        if len(parts) >= 2 and "(/" not in line:
            crates.add((parts[0], parts[1].removeprefix("v")))
    return crates


def license_of(package: dict) -> str:
    license_name = package.get("license") or UNDECLARED_LICENSES.get(package["name"])
    if not license_name:
        sys.exit(
            f"{package['name']} 沒有宣告授權；確認其 LICENSE 檔後登錄到 UNDECLARED_LICENSES"
        )
    return license_name


def render(crates: list[tuple[str, str, str]]) -> str:
    return HEADER + "".join("\t".join(crate) + "\n" for crate in sorted(crates))


def collect() -> list[tuple[str, str, str]]:
    tree = run_cargo(
        "tree", "-p", ROOT_PACKAGE, "-e", "normal,build", "--prefix", "none", "--target", "all"
    )
    metadata = json.loads(run_cargo("metadata", "--format-version", "1"))
    packages = {(p["name"], p["version"]): p for p in metadata["packages"]}
    return [(name, version, license_of(packages[(name, version)])) for name, version in parse_tree(tree)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="只比對，不寫檔")
    args = parser.parse_args()
    text = render(collect())
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != text:
            sys.exit(f"{OUTPUT.relative_to(ROOT)} 已過期，請重跑 tools/licenses/make_rust_crates.py")
        return
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(text, encoding="utf-8")
    sys.stdout.write(f"{OUTPUT.relative_to(ROOT)}：{len(text.splitlines()) - 2} 個 crate\n")


if __name__ == "__main__":
    main()
