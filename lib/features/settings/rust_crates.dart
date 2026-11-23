import 'package:material_ui/material_ui.dart' show immutable;

const _commentPrefix = '#';
const _fieldSeparator = '\t';
const _fieldCount = 3;

/// `assets/licenses/rust_crates.txt` 的一列（tools/licenses/make_rust_crates.py 產生）。
@immutable
final class RustCrateInfo {
  const RustCrateInfo(this.name, this.version, this.license);
  final String name, version, license;
}

/// 每列 `name<TAB>version<TAB>license`；`#` 開頭與空行略過。
List<RustCrateInfo> parseRustCrates(String source) => [
  for (final line in source.split('\n'))
    if (line.trim().isNotEmpty && !line.startsWith(_commentPrefix))
      _parseLine(line),
];

RustCrateInfo _parseLine(String line) {
  final fields = line.split(_fieldSeparator);
  if (fields.length != _fieldCount) {
    throw FormatException('rust_crates.txt 格式錯誤：$line');
  }
  return RustCrateInfo(fields[0], fields[1], fields[2]);
}
