@Tags(['golden'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ja_text.dart';
import 'package:japanese_learn_app/core/text/mixed_text.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/app_text.dart';
import 'package:japanese_learn_app/features/kana/rule_card_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

const _mixedSpecimens = <Widget>[
  MixedText('「{ja:は}」當主題助詞時念 wa，例如{ja:学校|がっこう}的{ja:学|がく}。'),
  SizedBox(height: AppSpace.s2),
  MixedText('{ja:は} 當助詞時念 wa。', scale: TypeScale.caption),
  SizedBox(height: AppSpace.s2),
  MixedText(
    '長句換行：{ja:大丈夫|だいじょうぶ}？語調上揚是問句「你還好嗎？」，回答時語調下降的'
    '{ja:大丈夫|だいじょうぶ}是「沒事」；{ja:私|わたし}們在不同寬度下應該換在不同的位置，'
    '行首與行尾的振假名都不能懸出畫面。',
  ),
  SizedBox(height: AppSpace.s2),
  // 列首（U1）：不得有連續空白
  MixedText('{ja:大丈夫|だいじょうぶ}？：你還好嗎？'),
  MixedText('{ja:私|わたし}：歌詞裡的「我」'),
  SizedBox(height: AppSpace.s2),
  // 開括號不落在行尾、收尾字不落在行首（U2）
  MixedText(
    '看任何一部你喜歡的日劇，每聽到一次（例如{ja:知ってる|しってる}、{ja:寝てた|ねてた}）就畫一筆，'
    '語調上揚的「{ja:大丈夫|だいじょうぶ}？」是問句。',
  ),
];

class _TextSpecimen extends StatelessWidget {
  const _TextSpecimen();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // 撐滿可用寬度，375／768／1024 的換行才會不同（review_fc F12：原本三個寬度的圖完全相同）
    return Container(
      width: double.infinity,
      color: t.paper.base,
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppText('今日', scale: TypeScale.displayM),
            const AppText('第 12 日', scale: TypeScale.label, letterSpacing: 2),
            const SizedBox(height: AppSpace.s3),
            const JaText('あさきそらり', scale: TypeScale.jaHero),
            const JaText('今日はいい天気ですね。', scale: TypeScale.jaSentence),
            const SizedBox(height: AppSpace.s3),
            RubyLine(
              words: sentenceWordsFixture(),
              policy: displayPolicyFixture(),
            ),
            const SizedBox(height: AppSpace.s3),
            RubyLine(
              words: sentenceWordsFixture(),
              policy: displayPolicyFixture(
                romaji: RomajiMode.hidden,
                furigana: FuriganaMode.unknownOnly,
                wordSpacing: false,
              ),
            ),
            const SizedBox(height: AppSpace.s3),
            ..._mixedSpecimens,
          ],
        ),
      ),
    );
  }
}

/// K3 規則卡的真實內容（U14：「。」不落到行首）。
RuleCardDto _accentIntroCard() {
  final base = ruleCardFixture();
  return RuleCardDto(
    id: 'ka.rule.accent_intro',
    lessonId: 'le.k19',
    titleZh: '音調入門：高低，不是四聲',
    bodyZh:
        '日語每一拍只分高低兩種音高，靠整個詞的高低起伏分辨意思，和中文每個字各有四聲的方式不同。'
        '同一串假名可能因音調不同而意思不同，例如 {ja:雨|あめ} 與 {ja:飴|あめ}。'
        '音調也會因地區不同而有差異，這裡的語音由裝置合成，僅供參考。',
    examples: base.examples,
    soundGroups: const [],
    drillIds: const [],
  );
}

void main() {
  testWidgets('K3 規則卡 320 寬', (tester) async {
    final backend = FakeBackend();
    backend.kana.ruleCardStub.returns(_accentIntroCard());
    await pumpApp(
      tester,
      backend: backend,
      width: 320,
      settings: settingsFixture(),
      child: const RuleCardScreen(ruleId: 'ka.rule.accent_intro'),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(RuleCardScreen),
      matchesGoldenFile('../../goldens/k3_rule_card_320.png'),
    );
  });

  for (final width in const [320.0, 375.0, 768.0, 1024.0]) {
    for (final dark in const [false, true]) {
      final label = '${width.toInt()}_${dark ? 'dark' : 'light'}';
      testWidgets('文字元件 $label', (tester) async {
        await pumpApp(
          tester,
          width: width,
          dark: dark,
          child: const SingleChildScrollView(child: _TextSpecimen()),
        );

        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(_TextSpecimen),
          matchesGoldenFile('../../goldens/text_specimen_$label.png'),
        );
      });
    }
  }

  testWidgets('文字元件 320 寬、字級 2.0', (tester) async {
    await pumpApp(
      tester,
      width: 320,
      textScale: 2,
      child: const SingleChildScrollView(child: _TextSpecimen()),
    );

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(_TextSpecimen),
      matchesGoldenFile('../../goldens/text_specimen_320_scale2.png'),
    );
  });
}
