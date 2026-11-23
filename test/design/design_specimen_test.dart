@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/app_text.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/genko_grid.dart';
import 'package:japanese_learn_app/design/widgets/hanko_badge.dart';
import 'package:japanese_learn_app/design/widgets/ink_buttons.dart';
import 'package:japanese_learn_app/design/widgets/kana_cell.dart';
import 'package:japanese_learn_app/design/widgets/milestone_rail.dart';
import 'package:japanese_learn_app/design/widgets/paper_scaffold.dart';
import 'package:japanese_learn_app/design/widgets/paper_texture.dart';
import 'package:japanese_learn_app/design/widgets/rating_bar.dart';
import 'package:japanese_learn_app/design/widgets/ruled_list.dart';
import 'package:japanese_learn_app/design/widgets/side_rule_note.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fixtures.dart';
import '../support/pump_app.dart';

const _kana = [
  ('あ', 'a', KanaStatus.mastered),
  ('い', 'i', KanaStatus.learning),
  ('う', 'u', KanaStatus.learning),
  ('え', 'e', KanaStatus.notStarted),
  ('お', 'o', KanaStatus.notStarted),
  ('か', 'ka', KanaStatus.notStarted),
];

class _Specimen extends StatelessWidget {
  const _Specimen();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PaperScaffold(
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    EyebrowText('第 12 日', color: t.shu),
                    const AppText('今日', scale: TypeScale.displayL),
                  ],
                ),
              ),
              const HankoBadge('済'),
            ],
          ),
          const SizedBox(height: AppSpace.s5),
          GenkoGrid(
            children: [
              for (final (ch, romaji, status) in _kana)
                KanaCell(
                  kana: ch,
                  romaji: romaji,
                  status: status,
                  onTap: () {},
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s5),
          RuledList(
            children: [
              RuledTile.text(
                '複習',
                subtitle: '18 張 · 2.5 分',
                trailing: InkButton(label: '開始', onPressed: () {}),
              ),
              RuledTile(
                title: const MixedText('新內容 {ja:か}行'),
                subtitle: AppText(
                  '5 字 · 14 分',
                  scale: TypeScale.caption,
                  color: t.ink.secondary,
                ),
                onTap: () {},
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s5),
          const ChoiceTile(state: ChoiceTileState.correct, child: AppText('貓')),
          const SizedBox(height: AppSpace.s2),
          const ChoiceTile(state: ChoiceTileState.wrong, child: AppText('狗')),
          const SizedBox(height: AppSpace.s5),
          RatingBar(onRate: (_) {}),
          const SizedBox(height: AppSpace.s5),
          MilestoneRail(
            milestones: [
              milestoneFixture(id: 'a', titleZh: '平假名', passed: true),
              milestoneFixture(id: 'b', titleZh: '片假名'),
              milestoneFixture(id: 'c', titleZh: '入門七課'),
            ],
          ),
          const SizedBox(height: AppSpace.s5),
          const SideRuleNote(title: '容易錯', child: MixedText('助詞的{ja:は}念 wa。')),
        ],
      ),
    );
  }
}

/// 紙紋要真的非同步解碼，testWidgets 的假時鐘等不到；
/// 不先等完，同一個 process 裡第一個跑的測試會拍不到紙紋，結果就取決於執行順序。
Future<void> _decodePaperTexture(WidgetTester tester) async {
  final context = tester.element(find.byType(_Specimen));
  await tester.runAsync(
    () => precacheImage(const AssetImage(PaperTexture.assetPath), context),
  );
  await tester.pump();
}

void main() {
  for (final dark in const [false, true]) {
    final label = dark ? 'dark' : 'light';
    testWidgets('元件樣張 $label', (tester) async {
      await pumpApp(
        tester,
        width: 375,
        height: 920,
        dark: dark,
        child: const _Specimen(),
      );

      await _decodePaperTexture(tester);

      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(_Specimen),
        matchesGoldenFile('../goldens/design_specimen_$label.png'),
      );
    });
  }
}
