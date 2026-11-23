#!/usr/bin/env bash
# 依 tools/verify/data.lock.toml 下載內容驗證用的外部資料到 .verify-cache/，並校驗 sha256。
# 這是驗證流程唯一碰網路的步驟（reuse-and-verification.md §9.4），工具本身不連網。
# 資料授權為 CC BY-SA 等，只在開發時使用，不進 repo、不進 App（§2.4）。
#
# 用法：tools/verify/fetch_data.sh（從任何目錄皆可）
# 環境變數 VERIFY_CACHE 可覆寫下載目錄（預設 <repo>/.verify-cache）。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/tools/verify/data.lock.toml"
CACHE="${VERIFY_CACHE:-$ROOT/.verify-cache}"
DOWNLOADS="$CACHE/downloads"

SECTIONS=(jmdict kanjidic2 furigana jlpt_n5 jlpt_n4 freq_subtitles kanjium)

die() {
    echo "[fetch_data] $*" >&2
    exit 2
}

command -v curl >/dev/null || die "需要 curl"
command -v sha256sum >/dev/null || die "需要 sha256sum"
command -v tar >/dev/null || die "需要 tar"
[[ -f "$LOCK" ]] || die "找不到鎖定檔：$LOCK"
mkdir -p "$DOWNLOADS"

# 讀 [section] 底下的 key = "value"（鎖定檔只用字串值）。
lock_value() {
    awk -v section="$1" -v key="$2" '
        /^\[/ { current = substr($0, 2, length($0) - 2); next }
        current == section && $1 == key {
            value = $0
            sub(/^[^=]*=[ ]*"/, "", value)
            sub(/"[ ]*$/, "", value)
            print value
        }
    ' "$LOCK"
}

fetch_section() {
    local section="$1" url sha output name artifact
    url="$(lock_value "$section" url)"
    sha="$(lock_value "$section" sha256)"
    output="$(lock_value "$section" output)"
    [[ -n "$url" && -n "$sha" && -n "$output" ]] || die "$section 缺 url、sha256 或 output"

    name="$sha-$(basename "${url%%\?*}")"
    artifact="$DOWNLOADS/$name"
    if [[ ! -f "$artifact" ]] || ! echo "$sha  $artifact" | sha256sum -c --status; then
        echo "[fetch_data] 下載 $section"
        curl -fsSL --retry 3 -o "$artifact.tmp" "$url" || die "$section 下載失敗：$url"
        mv "$artifact.tmp" "$artifact"
    fi
    if ! echo "$sha  $artifact" | sha256sum -c --status; then
        die "$section 雜湊不符：$url（鎖定檔 $sha）"
    fi

    if [[ "$artifact" == *.tgz ]]; then
        local extract
        extract="$(mktemp -d "$CACHE/extract.XXXXXX")"
        tar -xzf "$artifact" -C "$extract"
        local found
        found="$(find "$extract" -type f -name '*.json' | head -n 1)"
        [[ -n "$found" ]] || die "$section 解壓後找不到 JSON"
        mv "$found" "$CACHE/$output"
        rm -rf "$extract"
    else
        cp "$artifact" "$CACHE/$output"
    fi
    echo "[fetch_data] 完成 $section → $CACHE/$output"
}

for section in "${SECTIONS[@]}"; do
    fetch_section "$section"
done

echo "[fetch_data] 全部完成：$CACHE"
