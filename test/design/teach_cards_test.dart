import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/tts/tts_controller.dart';
import 'package:japanese_learn_app/design/tokens.dart';
import 'package:japanese_learn_app/design/widgets/beat_strip.dart';
import 'package:japanese_learn_app/design/widgets/confusable_view.dart';
import 'package:japanese_learn_app/design/widgets/grammar_teach_card.dart';
import 'package:japanese_learn_app/design/widgets/kana_teach_card.dart';
import 'package:japanese_learn_app/design/widgets/note_body.dart';
import 'package:japanese_learn_app/design/widgets/pattern_blocks.dart';
import 'package:japanese_learn_app/design/widgets/rule_card_view.dart';
import 'package:japanese_learn_app/design/widgets/speak_button.dart';
import 'package:japanese_learn_app/design/widgets/vocab_teach_card.dart';
import 'package:material_ui/material_ui.dart';

import '../support/fake_backend.dart';
import '../support/fake_tts_engine.dart';
import '../support/fixtures.dart';
import '../support/pump_app.dart';

Widget _scroll(Widget child) => SingleChildScrollView(child: child);

void main() {
  group('KanaTeachCard', () {
    testWidgets('內容：大字、romaji、字源、例字，且自動播一次', (tester) async {
      final tts = FakeTtsEngine();
      var next = 0;
      await pumpApp(
        tester,
        tts: tts,
        child: _scroll(
          KanaTeachCard(detail: kanaDetailFixture(), onNext: () => next++),
        ),
      );

      expect(find.text('あ'), findsWidgets);
      expect(find.text('來自漢字：'), findsOneWidget);
      // 字源漢字走 Klee，Noto 子集沒有部分日文漢字（曽、祢、与…）
      expect(
        tester.widget<Text>(find.text('安')).style?.fontFamily,
        AppFonts.ja,
      );
      expect(find.text('あい'), findsOneWidget);
      expect(tts.spoken.single.id, 'ka.hira.a');

      await tester.tap(find.text('下一步'));
      expect(next, 1);
    });

    testWidgets('listen_disabled 時不播、改顯示說明', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        child: _scroll(
          KanaTeachCard(detail: kanaDetailFixture(listenDisabled: true)),
        ),
      );

      expect(tts.spoken, isEmpty);
      expect(find.text('單獨唸不準，看例字'), findsOneWidget);
    });

    testWidgets('螢幕報讀時不自動播放', (tester) async {
      final tts = FakeTtsEngine();
      await pumpApp(
        tester,
        tts: tts,
        accessibleNavigation: true,
        child: _scroll(KanaTeachCard(detail: kanaDetailFixture())),
      );

      expect(tts.spoken, isEmpty);
    });

    testWidgets('設定關閉自動播放時不播', (tester) async {
      final tts = FakeTtsEngine();
      final backend = FakeBackend()
        ..settings.current = settingsFixture(autoplay: false);
      await pumpApp(
        tester,
        tts: tts,
        backend: backend,
        child: _scroll(KanaTeachCard(detail: kanaDetailFixture())),
      );

      expect(tts.spoken, isEmpty);
    });

    testWidgets('320 寬 1.5 倍字級不溢位', (tester) async {
      await pumpApp(
        tester,
        width: 320,
        textScale: 1.5,
        child: _scroll(KanaTeachCard(detail: kanaDetailFixture())),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('VocabTeachCard', () {
    testWidgets('first_card 非 None 時按鈕為「考一題」', (tester) async {
      await pumpApp(
        tester,
        child: _scroll(
          VocabTeachCard(
            detail: vocabDetailFixture(),
            policy: displayPolicyFixture(),
            hasQuiz: true,
          ),
        ),
      );

      expect(find.text('考一題'), findsOneWidget);
      expect(find.text('貓'), findsOneWidget);
    });

    testWidgets('同形異義徽章', (tester) async {
      await pumpApp(
        tester,
        child: _scroll(
          VocabTeachCard(
            detail: vocabDetailFixture(
              notes: const [
                NoteDto.falseFriend(
                  id: 'no.x',
                  surface: '手紙',
                  jaZh: '信',
                  misreadZh: '衛生紙',
                ),
              ],
            ),
            policy: displayPolicyFixture(),
          ),
        ),
      );

      expect(find.text('同形異義'), findsOneWidget);
    });

    testWidgets('romaji 隱藏模式時不放進樹', (tester) async {
      await pumpApp(
        tester,
        child: _scroll(
          VocabTeachCard(
            detail: vocabDetailFixture(),
            policy: displayPolicyFixture(romaji: RomajiMode.hidden),
          ),
        ),
      );

      expect(find.text('neko'), findsNothing);
    });
  });

  testWidgets('GrammarTeachCard 顯示公式實心塊與提示', (tester) async {
    await pumpApp(
      tester,
      child: _scroll(
        GrammarTeachCard(
          detail: grammarDetailFixture(),
          policy: displayPolicyFixture(),
        ),
      ),
    );

    expect(find.byType(PatternBlocks), findsOneWidget);
    expect(find.text('和中文比一比'), findsOneWidget);
    expect(find.text('容易錯'), findsOneWidget);
  });

  testWidgets('ConfusableView 並排字組', (tester) async {
    await pumpApp(
      tester,
      child: _scroll(ConfusableView(group: confusableFixture())),
    );

    expect(find.text('ぬ'), findsOneWidget);
    expect(find.text('め'), findsOneWidget);
    expect(find.byType(SpeakButton), findsNWidgets(2));
  });

  group('RuleCardView 與 BeatStrip', () {
    testWidgets('有 beats 時顯示拍格，語意「第 2 拍，停一拍」', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(
        tester,
        child: _scroll(RuleCardView(card: ruleCardFixture())),
      );

      expect(find.byType(BeatStrip), findsOneWidget);
      expect(find.bySemanticsLabel('第 2 拍，停一拍'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('TtsStarted 後依序亮格', (tester) async {
      final tts = FakeTtsEngine(autoComplete: false);
      final container = await pumpApp(
        tester,
        tts: tts,
        child: _scroll(RuleCardView(card: ruleCardFixture())),
      );

      await container
          .read(ttsControllerProvider.notifier)
          .speak(
            const SpeechRequest(id: 'ka.rule.sokuon.ex0', text: 'か', kana: 'か'),
          );
      await tester.pump();

      Color? fillOf(int index) {
        final containers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(BeatStrip),
                matching: find.byType(Container),
              ),
            )
            .toList();
        return (containers[index].decoration! as BoxDecoration).color;
      }

      expect(fillOf(0), isNot(Colors.transparent));
      expect(fillOf(1), Colors.transparent);

      await tester.pump(const Duration(milliseconds: 330));
      expect(fillOf(1), isNot(Colors.transparent));
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('無聲模式時有「無聲示範」', (tester) async {
      final backend = FakeBackend()
        ..settings.current = settingsFixture(silentMode: true);
      await pumpApp(
        tester,
        backend: backend,
        child: _scroll(RuleCardView(card: ruleCardFixture())),
      );

      expect(find.text('無聲示範'), findsOneWidget);
      expect(find.text('看節拍'), findsOneWidget);
    });
  });

  group('NoteBody', () {
    final notes = <NoteDto>[
      const NoteDto.falseFriend(
        id: 'a',
        surface: '手紙',
        jaZh: '信',
        misreadZh: '衛生紙',
      ),
      const NoteDto.shinjitai(
        id: 'b',
        ja: '学',
        zhTw: '學',
        kind: 'simplified',
        vocabIds: [],
      ),
      const NoteDto.reading(
        id: 'c',
        titleZh: '濁音',
        bodyZh: '說明',
        examples: [ReadingExampleDto(hanzi: '學', tai: 'hak8', ja: '{ja:がく}')],
        caveatZh: '例外很多',
      ),
      const NoteDto.transfer(
        id: 'd',
        titleZh: '我的',
        zhPattern: 'A 的 B',
        wrong: '{ja:わたし学生}',
        right: '{ja:わたしの学生}',
        explainZh: '要 {ja:の}',
      ),
      const NoteDto.term(
        id: 'e',
        term: '{ja:ます}形',
        bodyZh: '禮貌體',
        grammarIds: ['gr.masu'],
      ),
    ];

    for (final note in notes) {
      testWidgets('${note.runtimeType} 可呈現且不溢位', (tester) async {
        await pumpApp(
          tester,
          width: 320,
          textScale: 1.5,
          child: _scroll(NoteBody(note: note)),
        );

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('和製漢字標「意思近」並說明台灣不用此字', (tester) async {
      await pumpApp(
        tester,
        child: _scroll(
          const NoteBody(
            note: NoteDto.shinjitai(
              id: 'no.sj.komu',
              ja: '込',
              zhTw: '入',
              kind: 'kokuji',
              vocabIds: [],
            ),
          ),
        ),
      );

      expect(find.text('意思近'), findsOneWidget);
      expect(find.text('對照'), findsNothing);
      expect(find.text('日本自創的漢字，台灣不用；右邊是意思最接近的中文字'), findsOneWidget);
    });

    testWidgets('字形對照依種類顯示說明', (tester) async {
      const cases = {
        'simplified_differently': '日本的新字體，和台灣的寫法不同',
        'shape_detail': '同一個字，日本和台灣的筆畫細節不同',
        'variant_split': '日文依意思分成兩個字，這個意思寫左邊的字；台灣都寫右邊的字',
      };
      for (final MapEntry(key: kind, value: caption) in cases.entries) {
        await pumpApp(
          tester,
          child: _scroll(
            NoteBody(
              note: NoteDto.shinjitai(
                id: 'no.sj.x',
                ja: '駅',
                zhTw: '驛',
                kind: kind,
                vocabIds: const [],
              ),
            ),
          ),
        );

        expect(find.text('對照'), findsOneWidget, reason: kind);
        expect(find.text(caption), findsOneWidget, reason: kind);
      }
    });

    testWidgets('讀音筆記在台語讀音旁說明台羅數字調', (tester) async {
      await pumpApp(tester, child: _scroll(NoteBody(note: notes[2])));

      expect(find.text('hak8'), findsOneWidget);
      expect(find.text('台語讀音為台羅拼音，字尾數字是聲調'), findsOneWidget);
    });
  });
}
