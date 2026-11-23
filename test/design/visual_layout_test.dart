// 視覺 QA 抓到的版面缺陷的回歸測試（真實內容截圖才看得出來的問題）。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/app_text.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/speed_toggle.dart';
import 'package:japanese_learn_app/design/widgets/vocab_teach_card.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('MixedText 粗體情境的假名用 Klee 600，不會比旁邊的中文細一截', (tester) async {
    await pumpApp(
      tester,
      child: const Column(
        children: [
          MixedText('先把{ja:あ}行', scale: TypeScale.title),
          MixedText('先把{ja:あ}行', scale: TypeScale.body),
        ],
      ),
    );

    TextSpan jaSpan(int index) {
      final rich = tester.widget<RichText>(find.byType(RichText).at(index));
      TextSpan? found;
      rich.text.visitChildren((span) {
        if (span is TextSpan && span.text == 'あ') found = span;
        return true;
      });
      return found!;
    }

    expect(jaSpan(0).style?.fontWeight, FontWeight.w600);
    expect(jaSpan(1).style?.fontWeight, FontWeight.w400);
  });

  testWidgets('ChoiceTile 選取與判定時高度不變，選項不會跳動', (tester) async {
    Future<double> heightOf(ChoiceTileState state) async {
      await pumpApp(
        tester,
        child: Column(
          children: [
            ChoiceTile(
              key: const ValueKey('tile'),
              state: state,
              child: const AppText('選項'),
            ),
          ],
        ),
      );
      return tester.getSize(find.byKey(const ValueKey('tile'))).height;
    }

    final idle = await heightOf(ChoiceTileState.idle);
    for (final state in ChoiceTileState.values) {
      expect(await heightOf(state), idle, reason: state.name);
    }
  });

  testWidgets('SpeedToggle 的底線貼著文字，觸控區仍是 48', (tester) async {
    await pumpApp(
      tester,
      settings: settingsFixture(),
      child: const Row(children: [SpeedToggle()]),
    );

    expect(
      tester.getSize(find.byType(SpeedToggle)).height,
      greaterThanOrEqualTo(PaperLayout.minTarget),
    );
    final underlined = find.descendant(
      of: find.byType(SpeedToggle),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).border != null,
      ),
    );
    expect(tester.getSize(underlined.first).height, lessThan(32));
  });

  testWidgets('HankoBadge muted 不用朱色，供列表的小章', (tester) async {
    await pumpApp(tester, child: const HankoBadge('済', size: 28, muted: true));

    final outer = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(HankoBadge),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = outer.decoration! as BoxDecoration;
    expect(decoration.color, isNot(AppTokens.light.shu));
    expect(decoration.color, AppTokens.light.ink.tertiary);
  });

  testWidgets('VocabTeachCard 長單字在窄螢幕縮小，不在詞中換行', (tester) async {
    const surface = 'よろしくお願いします';
    final detail = vocabDetailFixture().copyWith(
      summary: vocabSummaryFixture(surface: surface, kana: surface),
    );
    await pumpApp(
      tester,
      settings: settingsFixture(),
      width: 320,
      child: SingleChildScrollView(
        child: VocabTeachCard(detail: detail, policy: displayPolicyFixture()),
      ),
    );

    final hero = find.text(surface).first;
    final rect = tester.getRect(hero);
    expect(rect.right, lessThanOrEqualTo(320));
    // 一行的高度遠小於兩行（jaHero 行高 72）
    expect(rect.height, lessThan(TypeScale.jaHero.lineHeight * 1.5));
  });
}

extension on VocabDetailDto {
  VocabDetailDto copyWith({required VocabSummaryDto summary}) => VocabDetailDto(
    summary: summary,
    jlpt: jlpt,
    useLevel: useLevel,
    sameFormZh: sameFormZh,
    hookZh: hookZh,
    trapZh: trapZh,
    readingFamily: readingFamily,
    examples: examples,
    notes: notes,
    conjugations: conjugations,
  );
}
