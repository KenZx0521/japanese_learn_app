import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/ja_word_line.dart';
import 'package:japanese_learn_app/features/vocab/vocab_topics_screen.dart';
import 'package:japanese_learn_app/features/vocab/widgets/vocab_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';

VocabSummaryDto _long({bool sameKana = true}) => VocabSummaryDto(
  id: 'vo.long',
  surface: 'ありがとうございます',
  kana: sameKana ? 'ありがとうございます' : 'ありがとう ございます',
  romaji: 'arigatou gozaimasu',
  zh: const ['謝謝'],
  pos: 'exp',
  lessonId: 'le.k05',
  srsState: SrsStateLabel.review,
  speech: const SpeechDto(text: 'ありがとうございます', kana: 'ありがとうございます'),
  known: false,
  starred: false,
);

bool _isSingleLine(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  return paragraph.size.height <
      paragraph.getFullHeightForCaret(const TextPosition(offset: 0)) * 1.5;
}

void main() {
  testWidgets('320 寬時長單字不在詞中斷行', (tester) async {
    await pumpApp(tester, width: 320, child: VocabRow(word: _long()));

    expect(_isSingleLine(tester, 'ありがとうございます'), isTrue);
  });

  testWidgets('假名行也不在詞中斷行', (tester) async {
    await pumpApp(
      tester,
      width: 320,
      child: VocabRow(word: _long(sameKana: false)),
    );

    expect(_isSingleLine(tester, 'ありがとう ございます'), isTrue);
  });

  testWidgets('字級 2 倍時狀態改放說明行，單字欄才不會被擠小', (tester) async {
    await pumpApp(
      tester,
      width: 320,
      textScale: 2,
      child: VocabRow(word: _long()),
    );

    expect(find.textContaining('複習中'), findsOneWidget);
    expect(
      tester.getSize(find.byType(JaWordLine).first).width,
      greaterThan(170),
    );
  });

  testWidgets('主題名稱含假名時走 MixedText，假名用日文字型', (tester) async {
    final backend = FakeBackend();
    backend.vocab.topicsStub.returns(const [
      TopicDto(id: 'demonstrative', titleZh: '{ja:こそあど}與指示', count: 13),
    ]);

    await pumpApp(tester, backend: backend, child: const VocabTopicsScreen());

    final rich = tester.widget<RichText>(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('こそあど'),
      ),
    );
    var isJaFont = false;
    rich.text.visitChildren((span) {
      if (span is TextSpan &&
          span.text == 'こそあど' &&
          span.style?.fontFamily == 'KleeOneJP') {
        isJaFont = true;
      }
      return true;
    });
    expect(isJaFont, isTrue);
  });
}
