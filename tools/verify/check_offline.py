#!/usr/bin/env python3
"""O8 離線保證（reuse-and-verification.md §9.12）。只用標準函式庫。exit：0 通過、1 違規、2 環境問題。"""
import argparse, glob, json, os, pathlib, re, shutil, subprocess, sys
from urllib.parse import urlparse
from xml.etree import ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
PERM, NAME = "android.permission.INTERNET", "{http://schemas.android.com/apk/res/android}name"
RUST_DENY = set("""reqwest ureq hyper hyper-util hyper-rustls hyper-tls h2 rustls native-tls openssl openssl-sys curl curl-sys
  isahc surf attohttpc tungstenite tokio-tungstenite tokio-rustls tokio-native-tls quinn wana_kana content_tool""".split())
DART_DENY = set("""http http2 dio web_socket web_socket_channel grpc shelf http_multi_server socket_io_client cronet_http
  cupertino_http rhttp chopper retrofit graphql connectivity_plus google_fonts cached_network_image
  flutter_cache_manager webview_flutter""".split())
SOURCES = [("lib/**/*.dart", r"\b(HttpClient|WebSocket|RawSocket|SecureSocket|Socket\.connect)\b"),
           ("rust/src/**/*.rs", r"\b(std::net|TcpStream|UdpSocket)\b"),
           ("rust/crates/**/*.rs", r"\b(std::net|TcpStream|UdpSocket)\b")]

def run(cmd, cwd=ROOT):
    try:
        return subprocess.run(cmd, cwd=cwd, check=True, capture_output=True, text=True).stdout
    except (OSError, subprocess.CalledProcessError) as e:
        sys.exit(print(f"[環境] {' '.join(cmd)}: {getattr(e, 'stderr', e)}", file=sys.stderr) or 2)

def has_internet(path):
    return any(e.get(NAME) == PERM for e in ET.parse(path).iter() if e.tag.startswith("uses-permission"))

def plugin_manifests(pkgs):
    for p in json.loads((ROOT / ".dart_tool/package_config.json").read_text())["packages"]:
        if p["name"] in pkgs:
            uri = p["rootUri"]
            root = pathlib.Path(urlparse(uri).path) if uri.startswith("file:") else (ROOT / ".dart_tool" / uri).resolve()
            yield root / "android/src/main/AndroidManifest.xml"

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--apk")
    ap.add_argument("--require-apk", action="store_true")
    args, errors = ap.parse_args(), []
    tree = run(["cargo", "tree", "-p", "jp_core", "-e", "normal,build", "--prefix", "none", "--no-dedupe", "--target", "all"], ROOT / "rust")
    errors += [f"L03 Rust 相依含 {n}" for n in sorted({l.split()[0] for l in tree.splitlines() if l.strip()} & RUST_DENY)]
    pkgs = set(re.findall(r"^- (\S+)", run(["flutter", "pub", "deps", "--no-dev", "--style=compact"]), re.M))
    errors += [f"L06 Dart release 相依含 {p}" for p in sorted(pkgs) if p in DART_DENY or p.startswith("firebase_")]
    app = [ROOT / f"android/app/src/{v}/AndroidManifest.xml" for v in ("main", "release")]
    errors += [f"L05 {m} 宣告 INTERNET" for m in [*app, *plugin_manifests(pkgs)] if m.exists() and has_internet(m)]
    for pattern, rx in SOURCES:
        for f in ROOT.glob(pattern):
            if m := re.search(rx, f.read_text(encoding="utf-8")):
                errors.append(f"L08 {f.relative_to(ROOT)} 使用 {m.group(1)}")
    aapt = shutil.which("aapt") or max(glob.glob(os.path.expandvars("$ANDROID_HOME/build-tools/*/aapt")), default=None)
    if aapt and args.apk and pathlib.Path(args.apk).exists():
        errors += [f"L07 {args.apk} 含 INTERNET"] if PERM in run([aapt, "dump", "permissions", args.apk]) else []
    elif args.require_apk:
        sys.exit(print("[環境] 找不到 aapt 或 APK", file=sys.stderr) or 2)
    else:
        print("SKIP L07：沒有 aapt 或 APK，只完成靜態檢查")
    print("\n".join(errors) or "離線檢查通過")
    sys.exit(1 if errors else 0)

main()
