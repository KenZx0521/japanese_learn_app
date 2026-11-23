#!/usr/bin/env python3
"""make_rust_crates.py 的純函式。執行：python3 -m unittest discover -s tools/licenses"""
from __future__ import annotations

import unittest

import make_rust_crates as mrc


class RenderTest(unittest.TestCase):
    def test_parse_tree_keeps_registry_crates_only(self) -> None:
        output = "\n".join(
            [
                "jp_core v0.1.0 (/repo/rust)",
                "anyhow v1.0.100",
                "syn v2.0.1 (proc-macro)",
                "anyhow v1.0.100 (*)",
                "jp_lang v0.1.0 (/repo/rust/crates/jp_lang)",
                "",
            ]
        )
        self.assertEqual(mrc.parse_tree(output), {("anyhow", "1.0.100"), ("syn", "2.0.1")})

    def test_license_of_prefers_declared_then_override(self) -> None:
        self.assertEqual(mrc.license_of({"name": "a", "license": "MIT"}), "MIT")
        self.assertEqual(mrc.license_of({"name": "rs-fsrs", "license": None}), "MIT")

    def test_license_of_rejects_undeclared_crates(self) -> None:
        with self.assertRaises(SystemExit):
            mrc.license_of({"name": "unknown-crate", "license": None})

    def test_render_is_sorted_tab_separated_with_header(self) -> None:
        text = mrc.render([("b", "2.0.0", "MIT"), ("a", "1.0.0", "Zlib")])
        lines = text.splitlines()
        self.assertTrue(all(line.startswith("#") for line in lines[:-2]))
        self.assertEqual(lines[-2:], ["a\t1.0.0\tZlib", "b\t2.0.0\tMIT"])


if __name__ == "__main__":
    unittest.main()
