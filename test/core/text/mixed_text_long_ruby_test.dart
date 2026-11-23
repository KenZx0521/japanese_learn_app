import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/core/backend/repositories.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/pump_app.dart';

/// Rust 依讀音對齊，把 `{ja:台北に映画を見に行きます|…}` 切成多段。
final class _AlignedTools implements TextTools {
  const _AlignedTools();

  static const parts = [
    RubyPartDto(base: '台北', ruby: 'たいぺい'),
    RubyPartDto(base: 'に'),
    RubyPartDto(base: '映画', ruby: 'えいが'),
    RubyPartDto(base: 'を'),
    RubyPartDto(base: '見', ruby: 'み'),
    RubyPartDto(base: 'に'),
    RubyPartDto(base: '行', ruby: 'い'),
    RubyPartDto(base: 'きます'),
  ];

  @override
  List<MixedSpanDto> parseMixedText(String input) => const [
    MixedSpanDto.ja(text: '台北に映画を見に行きます', ruby: parts),
  ];

  @override
  String romajiInputPreview(String input) => input;

  @override
  String? romanizeReading(String reading, ReadingMode mode) => reading;
}

/// `pumpApp` 已覆寫 `textToolsProvider`，這裡用巢狀 scope 換掉。
class _Aligned extends StatelessWidget {
  const _Aligned();

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: [textToolsProvider.overrideWithValue(const _AlignedTools())],
    child: const MixedText('source'),
  );
}

void main() {
  testWidgets('整段帶振假名的日文在窄版大字級下可換行，不溢位', (tester) async {
    await pumpApp(tester, width: 320, textScale: 1.5, child: const _Aligned());

    expect(tester.takeException(), isNull);
    expect(find.text('台北'), findsOneWidget);
    expect(find.text('きます'), findsOneWidget);
  });

  testWidgets('螢幕報讀整段只讀一次', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, child: const _Aligned());

    expect(find.bySemanticsLabel('台北に映画を見に行きます'), findsOneWidget);
    expect(find.bySemanticsLabel('台北'), findsNothing);
    handle.dispose();
  });
}
