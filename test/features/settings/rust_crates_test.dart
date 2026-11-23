import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/features/settings/rust_crates.dart';

const _assetFile = 'assets/licenses/rust_crates.txt';

/// O8：HTTP／TLS client 與僅供內容工具、測試使用的 crate 都不該出現在打包清單。
const _forbidden = {
  'reqwest',
  'ureq',
  'hyper',
  'h2',
  'rustls',
  'native-tls',
  'openssl',
  'curl',
  'isahc',
  'surf',
  'attohttpc',
  'tungstenite',
  'quinn',
  'wana_kana',
  'clap',
  'sha2',
  'toml',
  'ttf-parser',
  'encoding_rs',
  'tempfile',
  'proptest',
};

Set<String> _lockedPackages() {
  final packageBlock = RegExp(
    r'\[\[package\]\]\nname = "([^"]+)"\nversion = "([^"]+)"',
  );
  return {
    for (final match in packageBlock.allMatches(
      File('rust/Cargo.lock').readAsStringSync(),
    ))
      '${match.group(1)} ${match.group(2)}',
  };
}

void main() {
  group('parseRustCrates', () {
    test('略過註解與空行，保留欄位', () {
      final crates = parseRustCrates(
        '# 註解\n\nchrono\t0.4.45\tMIT OR Apache-2.0\n',
      );
      expect(crates, hasLength(1));
      expect(crates.single.name, 'chrono');
      expect(crates.single.version, '0.4.45');
      expect(crates.single.license, 'MIT OR Apache-2.0');
    });

    test('欄位數不對時回報格式錯誤', () {
      expect(() => parseRustCrates('chrono\t0.4.45\n'), throwsFormatException);
    });
  });

  group('打包的清單', () {
    final crates = parseRustCrates(File(_assetFile).readAsStringSync());

    test('包含 jp_core 的正式相依，版本對得上 Cargo.lock', () {
      final locked = _lockedPackages();
      final names = crates.map((c) => c.name).toSet();
      expect(
        names,
        containsAll(['flutter_rust_bridge', 'rusqlite', 'rs-fsrs', 'chrono']),
      );
      for (final crate in crates) {
        expect(locked, contains('${crate.name} ${crate.version}'));
      }
    });

    test('每個 crate 都有授權，且不列工作區自己的套件', () {
      for (final crate in crates) {
        expect(crate.license, isNotEmpty, reason: crate.name);
        expect(crate.name.startsWith('jp_'), isFalse, reason: crate.name);
      }
    });

    test('沒有 HTTP/TLS client，也沒有工具或測試專用的 crate（O8）', () {
      final names = crates.map((c) => c.name).toSet();
      expect(names.intersection(_forbidden), isEmpty);
    });

    testWidgets('已宣告為 asset，App 內讀得到', (tester) async {
      final text = await rootBundle.loadString(_assetFile);
      expect(parseRustCrates(text), isNotEmpty);
    });
  });
}
