import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/routes.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/note_body.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/features/vocab/vocab_detail_screen.dart';
import 'package:japanese_learn_app/features/vocab/widgets/accent_line.dart';
import 'package:japanese_learn_app/features/vocab/widgets/vocab_row.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/fixtures.dart';
import '../../support/pump_app.dart';
import 'vocab_fixtures.dart';

const _screen = VocabDetailScreen(wordId: 'vo.neko');

FakeBackend _backend({
  VocabDetailDto? detail,
  ContentStage stage = ContentStage.p0A,
}) {
  final backend = FakeBackend();
  backend.vocab.detailStub.returns(detail ?? detailFixture());
  backend.course.overviewStub.returns(
    courseOverviewFixture(contentStage: stage),
  );
  backend.settings.displayPolicyStub.returns(displayPolicyFixture());
  return backend;
}

Future<void> _pump(
  WidgetTester tester,
  FakeBackend backend, {
  double width = 375,
  double textScale = 1,
}) => pumpApp(
  tester,
  backend: backend,
  child: _screen,
  width: width,
  textScale: textScale,
);

VocabSummaryDto _flagged({bool known = false, bool starred = false}) =>
    VocabSummaryDto(
      id: 'vo.neko',
      surface: '猫',
      kana: 'ねこ',
      romaji: 'neko',
      zh: const ['貓'],
      pos: 'n',
      lessonId: 'le.l01',
      srsState: SrsStateLabel.notStarted,
      speech: const SpeechDto(text: '猫', kana: 'ねこ'),
      known: known,
      starred: starred,
    );

void main() {
  testWidgets('顯示單字、假名、意思、例句與記法', (tester) async {
    await _pump(tester, _backend());

    expect(find.text('猫'), findsOneWidget);
    expect(find.text('ねこ'), findsOneWidget);
    expect(find.text('貓'), findsOneWidget);
    expect(find.text('例句'), findsOneWidget);
    expect(find.text('記法'), findsOneWidget);
  });

  testWidgets('依單字所屬的課取顯示規則', (tester) async {
    final backend = _backend();
    await _pump(tester, backend);

    final context =
        backend.settings.displayPolicyStub.calls.single.single!
            as DisplayContext;
    expect(context.lessonId, 'le.l01');
  });

  testWidgets('沒有例句時隱藏該區', (tester) async {
    await _pump(tester, _backend(detail: detailFixture(examples: const [])));

    expect(find.text('例句'), findsNothing);
    expect(find.text('貓'), findsOneWidget);
  });

  group('參考級別（O7）', () {
    testWidgets('P0a 的 N5 顯示「參考 N5」', (tester) async {
      await _pump(tester, _backend());
      expect(find.text('參考 N5'), findsOneWidget);
    });

    testWidgets('P0a 的 N4 不顯示標籤，也不出現 N4 字樣', (tester) async {
      await _pump(tester, _backend(detail: detailFixture(jlpt: JlptLevel.n4)));
      expect(find.textContaining('N4'), findsNothing);
      expect(find.textContaining('參考'), findsNothing);
    });

    testWidgets('P0a 的 Beyond 不顯示標籤', (tester) async {
      await _pump(
        tester,
        _backend(detail: detailFixture(jlpt: JlptLevel.beyond)),
      );
      expect(find.textContaining('N4'), findsNothing);
      expect(find.textContaining('參考'), findsNothing);
    });

    testWidgets('P0 顯示 N4 與 Beyond 標籤', (tester) async {
      await _pump(
        tester,
        _backend(
          detail: detailFixture(jlpt: JlptLevel.n4),
          stage: ContentStage.p0,
        ),
      );
      expect(find.text('參考 N4'), findsOneWidget);
    });

    testWidgets('P0 的 Beyond 顯示「N4 以外」', (tester) async {
      await _pump(
        tester,
        _backend(
          detail: detailFixture(jlpt: JlptLevel.beyond),
          stage: ContentStage.p0,
        ),
      );
      expect(find.text('N4 以外'), findsOneWidget);
    });

    testWidgets('讀不到課程階段時不顯示級別', (tester) async {
      final backend = _backend(detail: detailFixture(jlpt: JlptLevel.n4));
      backend.course.overviewStub.throws(const StorageFailure());

      await _pump(tester, backend);

      expect(find.textContaining('參考'), findsNothing);
      expect(find.textContaining('N4'), findsNothing);
      expect(find.text('猫'), findsOneWidget);
    });
  });

  testWidgets('顯示使用層級、自他動詞、容易錯與活用', (tester) async {
    await _pump(
      tester,
      _backend(
        detail: detailFixture(
          useLevel: UseLevelDto.friendsOnly,
          trans: TransitivityDto.transitive,
          trapZh: '別念成 {ja:ねご}',
          conjugations: const [
            ConjugationDto(form: '{ja:て}形', surface: '猫て', kana: 'ねこて'),
          ],
        ),
      ),
    );

    expect(find.text('朋友間才用'), findsOneWidget);
    expect(find.text('他動詞'), findsOneWidget);
    expect(find.text('容易錯'), findsOneWidget);
    expect(find.text('活用'), findsOneWidget);
    // 後端回傳 {ja:} 標記，不能把原始標記露出來
    expect(find.textContaining('{ja:'), findsNothing);
    expect(find.textContaining('形', findRichText: true), findsWidgets);
  });

  testWidgets('RecognizeOnly 顯示聽懂就好', (tester) async {
    await _pump(
      tester,
      _backend(detail: detailFixture(useLevel: UseLevelDto.recognizeOnly)),
    );
    expect(find.text('聽懂就好'), findsOneWidget);
  });

  testWidgets('音調線只在有 accent 時出現', (tester) async {
    await _pump(tester, _backend());
    expect(find.byType(AccentLine), findsNothing);
  });

  testWidgets('accent 非 null 時畫音調線並有語意', (tester) async {
    await _pump(tester, _backend(detail: detailFixture(accent: 1)));
    expect(find.byType(AccentLine), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('音調')), findsOneWidget);
  });

  testWidgets('自他成對與同字異讀可點開另一個字', (tester) async {
    final backend = _backend(
      detail: detailFixture(
        pair: const VocabRefDto(
          id: 'vo.aku',
          surface: '開く',
          kana: 'あく',
          zh: ['打開'],
        ),
        readingFamily: const [
          VocabRefDto(id: 'vo.ichi', surface: '一', kana: 'いち', zh: ['一']),
        ],
      ),
    );
    await pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.vocabWord('vo.neko'),
    );

    expect(find.text('自他成對'), findsOneWidget);
    expect(find.text('同字異讀'), findsOneWidget);

    backend.vocab.detailStub.returns(detailFixture(summary: wordAt(9)));
    await tester.ensureVisible(find.text('開く'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('開く'));
    await tester.pumpAndSettle();

    expect(backend.vocab.detailStub.calls.last, ['vo.aku']);
  });

  testWidgets('筆記用 NoteBody，連到另一個字', (tester) async {
    final backend = _backend(
      detail: detailFixture(notes: const [falseFriendNote]),
    );
    await pumpApp(
      tester,
      backend: backend,
      location: AppRoutes.vocabWord('vo.neko'),
    );
    expect(find.byType(NoteBody), findsOneWidget);

    backend.vocab.detailStub.returns(detailFixture(summary: wordAt(9)));
    await tester.ensureVisible(find.text('看單字'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('看單字'));
    await tester.pumpAndSettle();

    expect(backend.vocab.detailStub.calls.last, ['vo.tegami']);
  });

  group('標記', () {
    testWidgets('按「已會」寫入旗標並顯示說明', (tester) async {
      final backend = _backend();
      backend.vocab.setFlagsStub.returns(_flagged(known: true));
      await _pump(tester, backend);

      expect(find.text('這個字之後不會出現在複習裡。'), findsNothing);
      await tester.tap(find.text('已會'));
      await tester.pumpAndSettle();

      final call = backend.vocab.setFlagsStub.calls.single;
      expect(call.first, 'vo.neko');
      expect(call.last, const VocabFlagsDto(known: true, starred: false));
      expect(find.text('這個字之後不會出現在複習裡。'), findsOneWidget);
    });

    testWidgets('取消已會即恢復，帶回目前的收藏狀態', (tester) async {
      final backend = _backend(
        detail: detailFixture(summary: _flagged(known: true, starred: true)),
      );
      backend.vocab.setFlagsStub.returns(_flagged(starred: true));
      await _pump(tester, backend);

      await tester.tap(find.text('已會'));
      await tester.pumpAndSettle();

      expect(
        backend.vocab.setFlagsStub.calls.single.last,
        const VocabFlagsDto(known: false, starred: true),
      );
      expect(find.text('這個字之後不會出現在複習裡。'), findsNothing);
    });

    testWidgets('按「收藏」不動已會', (tester) async {
      final backend = _backend();
      backend.vocab.setFlagsStub.returns(_flagged(starred: true));
      await _pump(tester, backend);

      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      expect(
        backend.vocab.setFlagsStub.calls.single.last,
        const VocabFlagsDto(known: false, starred: true),
      );
    });

    testWidgets('寫入失敗時維持原狀，可重試', (tester) async {
      final backend = _backend();
      backend.vocab.setFlagsStub.throws(const StorageFailure());
      await _pump(tester, backend);

      await tester.tap(find.text('收藏'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsOneWidget);
      final toggle = tester.getSemantics(find.text('收藏'));
      expect(toggle, isNotNull);
      expect(
        tester
            .widget<Semantics>(
              find
                  .ancestor(
                    of: find.text('收藏'),
                    matching: find.byWidgetPredicate(
                      (w) => w is Semantics && w.properties.toggled != null,
                    ),
                  )
                  .first,
            )
            .properties
            .toggled,
        isFalse,
      );

      backend.vocab.setFlagsStub.returns(_flagged(starred: true));
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsNothing);
      expect(backend.vocab.setFlagsStub.calls, hasLength(2));
      expect(
        backend.vocab.setFlagsStub.calls.last.last,
        const VocabFlagsDto(known: false, starred: true),
      );
    });

    testWidgets('寫入中重複點擊只送一次', (tester) async {
      final backend = _backend();
      final gate = Completer<void>();
      backend.vocab.setFlagsStub
        ..gate = gate.future
        ..returns(_flagged(starred: true));
      await _pump(tester, backend);

      await tester.tap(find.text('收藏'));
      await tester.pump();
      await tester.tap(find.text('收藏'));
      await tester.pump();

      expect(backend.vocab.setFlagsStub.calls, hasLength(1));
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('旗標更新後，列表的那一列跟著更新', (tester) async {
      final backend = _backend(detail: detailFixture(summary: wordAt(3)));
      backend.vocab.pageStub.answers((args) => pageOf([wordAt(3)], args));
      backend.vocab.setFlagsStub.returns(wordAt(3, known: true));

      await pumpApp(tester, backend: backend, location: AppRoutes.vocabList());
      await tester.tap(find.text('語3'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('已會'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('返回'));
      await tester.pumpAndSettle();

      expect(find.byType(VocabRow), findsOneWidget);
      expect(find.text('已會'), findsOneWidget);
      expect(backend.vocab.pageStub.calls, hasLength(1));
    });
  });

  testWidgets('載入中顯示骨架', (tester) async {
    final backend = _backend();
    final gate = Completer<void>();
    backend.vocab.detailStub.gate = gate.future;

    await pumpApp(tester, backend: backend, child: _screen, settle: false);
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byType(SkeletonLines), findsOneWidget);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('猫'), findsOneWidget);
  });

  testWidgets('載入失敗顯示 ErrorSlip，重試成功', (tester) async {
    final backend = _backend();
    backend.vocab.detailStub.throws(const NotFoundFailure());

    await _pump(tester, backend);
    expect(find.byType(ErrorSlip), findsOneWidget);

    backend.vocab.detailStub.returns(detailFixture());
    await tester.tap(find.text('重試'));
    await tester.pumpAndSettle();

    expect(find.text('猫'), findsOneWidget);
  });

  testWidgets('顯示規則讀取失敗時顯示 ErrorSlip，不閃退', (tester) async {
    final backend = _backend();
    backend.settings.displayPolicyStub.throws(const StorageFailure());

    await _pump(tester, backend);

    expect(find.byType(ErrorSlip), findsOneWidget);
  });

  testWidgets('320 寬、字級 2.0 倍不溢位', (tester) async {
    await _pump(
      tester,
      _backend(
        detail: detailFixture(
          accent: 1,
          useLevel: UseLevelDto.friendsOnly,
          notes: const [falseFriendNote],
          conjugations: const [
            ConjugationDto(form: '{ja:て}形', surface: '猫て', kana: 'ねこて'),
          ],
        ),
      ),
      width: 320,
      textScale: 2,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('標記鈕互動目標至少 48dp', (tester) async {
    await _pump(tester, _backend());
    final handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
  });
}
