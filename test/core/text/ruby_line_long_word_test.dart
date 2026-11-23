import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/text/ruby_line.dart';

import '../../support/fixtures.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('單一長詞在窄版大字級下換行，不溢位', (tester) async {
    await pumpApp(
      tester,
      width: 320,
      textScale: 1.5,
      child: RubyLine(
        words: [
          wordFixture(
            surface: 'どうもありがとうございました',
            kana: 'どうもありがとうございました',
            romaji: 'doumo arigatou gozaimashita',
          ),
        ],
        policy: displayPolicyFixture(),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('多段的長詞也不溢位', (tester) async {
    await pumpApp(
      tester,
      width: 320,
      textScale: 1.5,
      child: RubyLine(
        words: [
          wordFixture(
            surface: '東京大学医学部附属病院',
            kana: 'とうきょうだいがくいがくぶふぞくびょういん',
            romaji: 'toukyou',
            ruby: const [
              RubyPartDto(base: '東京', ruby: 'とうきょう'),
              RubyPartDto(base: '大学', ruby: 'だいがく'),
              RubyPartDto(base: '医学部', ruby: 'いがくぶ'),
              RubyPartDto(base: '附属', ruby: 'ふぞく'),
              RubyPartDto(base: '病院', ruby: 'びょういん'),
            ],
          ),
        ],
        policy: displayPolicyFixture(),
      ),
    );

    expect(tester.takeException(), isNull);
  });
}
