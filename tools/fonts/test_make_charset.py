#!/usr/bin/env python3
"""make_charset.py 的 Rust 字串掃描。執行：python3 -m unittest discover -s tools/fonts"""
from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import make_charset


class RustUiCharsTest(unittest.TestCase):
    def _scan(self, files: dict[str, str]) -> set[str]:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, text in files.items():
                path = root / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text, encoding="utf-8")
            return make_charset.rust_ui_chars(root)

    def test_collects_symbols_from_string_literals(self) -> None:
        chars = self._scan(
            {"rust/crates/jp_quiz/src/a.rs": 'fn f() -> String { format!("{} ⇒ 形", 1) }\n'}
        )
        self.assertIn("⇒", chars)
        self.assertIn("形", chars)

    def test_ignores_comments_tests_and_generated_code(self) -> None:
        chars = self._scan(
            {
                "rust/src/app/a.rs": '// 註解⇒\nlet a = "ok";\n#[cfg(test)]\nmod tests { const X: &str = "測"; }\n',
                "rust/src/frb_generated.rs": 'let a = "生";\n',
            }
        )
        self.assertEqual(chars, set())

    def test_real_sources_include_the_conjugate_arrow(self) -> None:
        self.assertIn("→", make_charset.rust_ui_chars(make_charset.ROOT))

    def test_committed_sans_charset_covers_rust_strings(self) -> None:
        charset = set((make_charset.TOOLS / "charset_noto_sans.txt").read_text(encoding="utf-8"))
        missing = make_charset.rust_ui_chars(make_charset.ROOT) - charset
        self.assertEqual(missing, set(), "請重跑 tools/fonts/make_charset.py")


if __name__ == "__main__":
    unittest.main()
