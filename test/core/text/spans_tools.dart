// 直接回傳指定段落的 TextTools：Rust 的 `parse_mixed_text` 會把「知ってる」切成多段，fake 不會。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/backend/repositories.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:material_ui/material_ui.dart';

final class SpansTools implements TextTools {
  const SpansTools(this.spans);

  final List<MixedSpanDto> spans;

  @override
  List<MixedSpanDto> parseMixedText(String input) => spans;

  @override
  String romajiInputPreview(String input) => input;

  @override
  String? romanizeReading(String reading, ReadingMode mode) => reading;
}

Widget mixedWith(List<MixedSpanDto> spans) => ProviderScope(
  overrides: [textToolsProvider.overrideWithValue(SpansTools(spans))],
  child: const MixedText('x'),
);
