#!/usr/bin/env python3
"""產生 R15 的簡體字表（reuse-and-verification.md §9.1）。

字表為「GB2312 有、Big5 沒有」的漢字，只用 Python 內建編碼表，沒有外部資料。
用法：python3 tools/verify/make_zh_simplified.py [輸出路徑]
"""

import sys

DEFAULT_OUTPUT = "rust/content/lint/zh_simplified_chars.txt"
GB2312_LEAD_RANGE = range(0xB0, 0xF8)
GB2312_TRAIL_RANGE = range(0xA1, 0xFF)
LINE_WIDTH = 40


def gb2312_hanzi():
    for lead in GB2312_LEAD_RANGE:
        for trail in GB2312_TRAIL_RANGE:
            try:
                yield bytes([lead, trail]).decode("gb2312")
            except UnicodeDecodeError:
                continue


def not_in_big5(char):
    try:
        char.encode("big5")
    except UnicodeEncodeError:
        return True
    return False


def main():
    chars = sorted({c for c in gb2312_hanzi() if not_in_big5(c)})
    output = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUTPUT
    lines = [
        "# GB2312 有、Big5 沒有的漢字，由 tools/verify/make_zh_simplified.py 產生，請勿手改。",
    ]
    lines += ["".join(chars[i : i + LINE_WIDTH]) for i in range(0, len(chars), LINE_WIDTH)]
    with open(output, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")
    print(f"{len(chars)} chars -> {output}")


if __name__ == "__main__":
    main()
