import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/core/text/romaji_scope.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

Future<void> _pumpLine(
  WidgetTester tester,
  DisplayPolicyDto policy, {
  int? blank,
  ValueChanged<WordDto>? onTap,
  double width = 375,
  double textScale = 1,
}) => pumpApp(
  tester,
  width: width,
  textScale: textScale,
  child: RubyLine(
    words: sentenceWordsFixture(),
    policy: policy,
    semanticLabel: '私は学生です。',
    blankWordIndex: blank,
    onWordTap: onTap,
  ),
);

void main() {
  group('RomajiMode', () {
    testWidgets('Shown：永遠顯示', (tester) async {
      await _pumpLine(tester, displayPolicyFixture());
      expect(find.text('watashi'), findsOneWidget);
    });

    testWidgets('Hidden：不顯示', (tester) async {
      await _pumpLine(tester, displayPolicyFixture(romaji: RomajiMode.hidden));
      expect(find.text('watashi'), findsNothing);
    });

    testWidgets('TapToReveal：預設隱藏，按 aA 才顯示', (tester) async {
      await _pumpLine(
        tester,
        displayPolicyFixture(romaji: RomajiMode.tapToReveal),
      );
      expect(find.text('watashi'), findsNothing);

      await tester.tap(find.text('aA'));
      await tester.pump();

      expect(find.text('watashi'), findsOneWidget);
    });

    testWidgets('LongPressOnly：長按單字才顯示該字', (tester) async {
      await _pumpLine(
        tester,
        displayPolicyFixture(romaji: RomajiMode.longPressOnly),
      );
      expect(find.text('gakusei'), findsNothing);

      await tester.longPress(find.text('学生'));
      await tester.pump();

      expect(find.text('gakusei'), findsOneWidget);
      expect(find.text('watashi'), findsNothing);
    });

    testWidgets('ShownToggleable：受頁面開關影響', (tester) async {
      await pumpApp(
        tester,
        child: RomajiPageScope(
          child: Builder(
            builder: (context) => Column(
              children: [
                RubyLine(
                  words: sentenceWordsFixture(),
                  policy: displayPolicyFixture(
                    romaji: RomajiMode.shownToggleable,
                  ),
                ),
                TextButton(
                  onPressed: () => RomajiPageScope.toggle(context),
                  child: const Text('toggle'),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('watashi'), findsOneWidget);

      await tester.tap(find.text('toggle'));
      await tester.pump();

      expect(find.text('watashi'), findsNothing);
    });
  });

  group('FuriganaMode', () {
    testWidgets('All：顯示 ruby', (tester) async {
      await _pumpLine(tester, displayPolicyFixture());
      expect(find.text('わたし'), findsOneWidget);
      expect(find.text('がくせい'), findsOneWidget);
    });

    testWidgets('UnknownOnly：已知的詞隱藏 ruby', (tester) async {
      await _pumpLine(
        tester,
        displayPolicyFixture(furigana: FuriganaMode.unknownOnly),
      );
      expect(find.text('わたし'), findsNothing);
      expect(find.text('がくせい'), findsOneWidget);
    });
  });

  testWidgets('blankWordIndex：答案不放進 widget tree', (tester) async {
    await _pumpLine(tester, displayPolicyFixture(), blank: 2);

    expect(find.text('学生'), findsNothing);
    expect(find.text('がくせい'), findsNothing);
    expect(find.text('gakusei'), findsNothing);
  });

  testWidgets('點詞觸發 onWordTap，標點不可點', (tester) async {
    final tapped = <String>[];
    await _pumpLine(
      tester,
      displayPolicyFixture(),
      onTap: (word) => tapped.add(word.surface),
    );

    await tester.tap(find.text('学生'));
    await tester.pump();

    expect(tapped, ['学生']);
  });

  testWidgets('語意：句子 label 標 ja-JP', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpLine(tester, displayPolicyFixture());

    final data = tester.getSemantics(find.byType(RubyLine)).getSemanticsData();

    expect(data.attributedLabel.string, contains('私は学生です。'));
    final attribute = data.attributedLabel.attributes.single;
    expect(attribute, isA<LocaleStringAttribute>());
    expect(
      (attribute as LocaleStringAttribute).locale,
      const Locale('ja', 'JP'),
    );
    handle.dispose();
  });

  testWidgets('換題時重置「顯示羅馬字」', (tester) async {
    var words = sentenceWordsFixture();
    late StateSetter setOuter;
    await pumpApp(
      tester,
      child: StatefulBuilder(
        builder: (context, setState) {
          setOuter = setState;
          return RubyLine(
            words: words,
            policy: displayPolicyFixture(romaji: RomajiMode.tapToReveal),
          );
        },
      ),
    );
    await tester.tap(find.text('aA'));
    await tester.pump();
    expect(find.text('watashi'), findsOneWidget);

    setOuter(() => words = sentenceWordsFixture());
    await tester.pump();

    expect(find.text('watashi'), findsNothing);
  });

  testWidgets('字級 1.5 倍、320 寬不溢位', (tester) async {
    await _pumpLine(tester, displayPolicyFixture(), width: 320, textScale: 1.5);

    expect(tester.takeException(), isNull);
  });
}
