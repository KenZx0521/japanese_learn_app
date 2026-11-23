// rust-core.md §11.4：載入真實 .so 跑主要 API。先執行 cargo build --release。
import 'dart:io';

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/src/rust/api/core.dart';
import 'package:japanese_learn_app/src/rust/api/dto_content.dart';
import 'package:japanese_learn_app/src/rust/api/dto_plan.dart';
import 'package:japanese_learn_app/src/rust/api/dto_study.dart';
import 'package:japanese_learn_app/src/rust/api/error.dart';
import 'package:japanese_learn_app/src/rust/api/tools_api.dart';
import 'package:japanese_learn_app/src/rust/frb_generated.dart';

const _libraryPath = 'rust/target/release/libjp_core.so';
const _taipeiOffsetMinutes = 480;
const _seed = 42;
const _parallelWrites = 300;

/// 2026-03-02（週一）台北 09:00。
final _firstDay = DateTime.utc(2026, 3, 2, 1);

/// chrono 的上限約在西元 262142 年，Dart 的 DateTime 可以超過它，解碼時會 panic。
final _beyondChronoRange = DateTime.utc(275000);

PlanInputDto _planInput() => PlanInputDto(
  dailyMinutes: 20,
  weekdays: Uint32List.fromList(const [1, 2, 3, 4, 5, 6, 7]),
  startLevel: StartLevel.zero,
  knownKanaLessons: const [],
);

SettingsPatchDto _settingsPatch({bool? autoplay}) => SettingsPatchDto(
  autoplay: autoplay,
  clearRomajiOverride: false,
  clearFuriganaOverride: false,
  clearVoiceId: false,
);

AnswerPayload _correctPayload(QuestionDto question) => switch (question.body) {
  QuestionBodyDto_Choice(:final correctOptionId) => AnswerPayload.choice(
    optionId: correctOptionId,
  ),
  QuestionBodyDto_Reorder(:final acceptOrders) => AnswerPayload.reorder(
    order: acceptOrders.first,
  ),
  QuestionBodyDto_Typing(:final expectedReading) => AnswerPayload.typing(
    input: expectedReading,
  ),
  QuestionBodyDto_Match() => const AnswerPayload.match(allCorrect: true),
  QuestionBodyDto_SelfGrade() => const AnswerPayload.selfGrade(
    rating: Rating.good,
  ),
  QuestionBodyDto_Shadow() => const AnswerPayload.shadow(
    level: ShadowLevel.kept,
  ),
};

AnswerDto _answerFor(SessionCardDto card) => AnswerDto(
  reference: card.question.reference,
  expectedReps: card.expectedReps,
  response: _correctPayload(card.question),
  hintUsed: false,
  attempts: 1,
  durationMs: 2000,
);

SessionCardDto _expectCard(SessionNextDto next) => switch (next) {
  SessionNextDto_Card(:final card) => card,
  SessionNextDto_Done() => throw StateError('佇列應有卡片'),
};

void main() {
  late Directory tempDir;
  late String dbPath;

  Future<AppCore> openAt(DateTime now) => AppCore.open(
    config: CoreConfig(
      dbPath: dbPath,
      utcOffsetMinutes: _taipeiOffsetMinutes,
      fixedNowUtc: now,
    ),
  );

  setUpAll(() async {
    await RustLib.init(externalLibrary: ExternalLibrary.open(_libraryPath));
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('jp_core_ffi');
    dbPath = '${tempDir.path}/jp_core.db';
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  /// 建計畫、學完第一批 3 字，回到隔天的 `AppCore`。
  Future<AppCore> finishFirstDay() async {
    final core = await openAt(_firstDay);
    await core.createPlan(input: _planInput());
    final today = await core.todayView(audioAvailable: true);
    final task = today.tasks.whereType<TaskDto_NewContent>().single;
    final session = await core.newContentSession(
      taskKey: task.key,
      sessionSeed: _seed,
      audioAvailable: true,
    );
    for (final step in session.steps.whereType<NewContentStepDto_KanaQuiz>()) {
      for (final question in step.questions) {
        await core.kanaSubmit(
          reference: question.reference,
          response: _correctPayload(question),
          durationMs: 1500,
        );
      }
    }
    await core.completeTask(
      taskKey: task.key,
      durationMs: 60000,
      audioAvailable: true,
    );
    return openAt(_firstDay.add(const Duration(days: 1)));
  }

  group('新使用者流程', () {
    test('open → create_plan → today_view 回傳 sealed 任務', () async {
      final core = await openAt(_firstDay);

      final plan = await core.createPlan(input: _planInput());
      final today = await core.todayView(audioAvailable: true);

      expect(plan.currentLessonId, 'le.k01');
      expect(today.logicalDate, '2026-03-02');
      final labels = [
        for (final task in today.tasks)
          switch (task) {
            TaskDto_Review() => 'review',
            TaskDto_NewContent(:final kana) => 'new:$kana',
            TaskDto_Integration() => 'integration',
            TaskDto_Drill() => 'drill',
            TaskDto_Listen() => 'listen',
            TaskDto_Checkpoint() => 'checkpoint',
          },
      ];
      expect(labels, ['review', 'new:3']);
    });

    test('new_content_session 先呈現再出題', () async {
      final core = await openAt(_firstDay);
      await core.createPlan(input: _planInput());
      final today = await core.todayView(audioAvailable: true);
      final key = today.tasks.whereType<TaskDto_NewContent>().single.key;

      final session = await core.newContentSession(
        taskKey: key,
        sessionSeed: _seed,
        audioAvailable: true,
      );

      expect(
        session.steps.take(3),
        everyElement(isA<NewContentStepDto_Kana>()),
      );
      expect(session.steps[3], isA<NewContentStepDto_KanaQuiz>());
    });

    test('隔日 session_next 取到前一天的假名卡，作答後寫入', () async {
      final core = await finishFirstDay();

      final today = await core.todayView(audioAvailable: true);
      final review = today.tasks.whereType<TaskDto_Review>().single;
      final card = _expectCard(
        await core.sessionNext(sessionSeed: _seed, audioAvailable: true),
      );
      final result = await core.submitAnswer(answer: _answerFor(card));
      final stats = await core.statsOverview();

      expect(today.logicalDate, '2026-03-03');
      expect(review.newCards, 3);
      expect(card.question.questionType, QuestionType.kanaRead);
      expect(card.ratingPreviews, hasLength(4));
      expect(result.isCorrect, isTrue);
      expect(stats.totalReviews, 1);
    });
  });

  group('內容與工具', () {
    test('五十音表與課程總覽可讀，Option 列表保留空格', () async {
      final core = await openAt(_firstDay);

      final chart = await core.kanaChart(script: KanaScript.hiragana);
      final overview = await core.courseOverview();

      expect(chart.first.columns, 5);
      expect(chart.first.rows.first.cells.first?.id, 'ka.hira.a');
      // 預設建置嵌入 p0（jp_content build.rs 的 DEFAULT_STAGE）：到 L30，筆記入口露出。
      expect(overview.contentStage, ContentStage.p0);
      expect(overview.notesAvailable, isTrue);
      expect(overview.lessons.map((l) => l.id), contains('le.l30'));
      expect(overview.lessons.map((l) => l.id), isNot(contains('le.l31')));
    });

    test('#[frb(sync)] 工具函式同步回傳', () {
      expect(romajiInputPreview(input: 'kya'), 'きゃ');
      expect(
        romanizeReading(reading: 'わたし', mode: ReadingMode.word),
        'watashi',
      );
      final spans = parseMixedText(input: '看{ja:あ}');
      expect(spans[0], isA<MixedSpanDto_Zh>());
      expect(spans[1], isA<MixedSpanDto_Ja>());
    });

    test('設定更新來回', () async {
      final core = await openAt(_firstDay);

      final updated = await core.updateSettings(
        patch: _settingsPatch(autoplay: false),
      );

      expect(updated.autoplay, isFalse);
      expect((await core.settings()).autoplay, isFalse);
    });
  });

  group('併發與錯誤', () {
    test('並行寫入全部成功', () async {
      final core = await openAt(_firstDay);

      await Future.wait([
        for (var i = 0; i < _parallelWrites; i++)
          core.updateSettings(patch: _settingsPatch(autoplay: i.isEven)),
      ]);

      expect(await core.settings(), isA<SettingsDto>());
    });

    test('CoreError 變體可依型別捕捉', () async {
      final core = await openAt(_firstDay);

      await expectLater(
        core.planView(),
        throwsA(isA<CoreError_NoActivePlan>()),
      );
      await expectLater(
        core.peek(refId: 'vo.nope'),
        throwsA(isA<CoreError_NotFound>()),
      );
      await expectLater(
        core.setUtcOffset(minutes: 9999),
        throwsA(isA<CoreError_InvalidInput>()),
      );
    });

    test('連點回 StaleCard', () async {
      final core = await finishFirstDay();
      final card = _expectCard(
        await core.sessionNext(sessionSeed: _seed, audioAvailable: true),
      );
      await core.submitAnswer(answer: _answerFor(card));

      await expectLater(
        core.submitAnswer(answer: _answerFor(card)),
        throwsA(isA<CoreError_StaleCard>()),
      );
    });

    test('panic 轉成 PanicException，之後仍可用', () async {
      final core = await openAt(_firstDay);

      await expectLater(
        AppCore.open(
          config: CoreConfig(
            dbPath: dbPath,
            utcOffsetMinutes: 0,
            fixedNowUtc: _beyondChronoRange,
          ),
        ),
        throwsA(isA<PanicException>()),
      );

      expect((await core.settings()).dayRolloverHour, 4);
    });

    test('DateTime 來回都是 UTC', () async {
      final secondDay = _firstDay.add(const Duration(days: 1));
      var core = await finishFirstDay();
      for (var i = 0; i < 3; i++) {
        final card = _expectCard(
          await core.sessionNext(sessionSeed: _seed, audioAvailable: true),
        );
        await core.submitAnswer(answer: _answerFor(card));
      }

      // 時鐘倒退一小時：學習中的卡還沒到，也超過提前學習的 20 分鐘
      core = await openAt(secondDay.subtract(const Duration(hours: 1)));
      final next = await core.sessionNext(
        sessionSeed: _seed,
        audioAvailable: true,
      );

      final done = next as SessionNextDto_Done;
      expect(done.nextDueAt, isNotNull);
      expect(done.nextDueAt!.isUtc, isTrue);
      expect(done.nextDueAt!.isAfter(secondDay), isTrue);
    });

    test('delete_database 不需要 AppCore', () async {
      final core = await openAt(_firstDay);
      await core.resetAll();
      core.dispose();

      await deleteDatabase(dbPath: dbPath);

      expect(File(dbPath).existsSync(), isFalse);
    });
  });
}
