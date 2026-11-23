#!/usr/bin/env python3
"""捷徑：實作在 tools/fonts/make_charset.py（reuse-and-verification.md §5.3）。"""
import runpy
from pathlib import Path

runpy.run_path(str(Path(__file__).parent / "fonts" / "make_charset.py"), run_name="__main__")
