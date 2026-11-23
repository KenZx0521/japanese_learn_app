// 用真實畫面把任務跑完：從畫面上的 DTO 找正解，一律點真實 UI 作答。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/app/app.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';
import 'package:japanese_learn_app/design/widgets/choice_tile.dart';
import 'package:japanese_learn_app/design/widgets/rating_bar.dart';
import 'package:japanese_learn_app/design/widgets/ruled_list.dart';
import 'package:japanese_learn_app/design/widgets/word_tile.dart';
import 'package:japanese_learn_app/features/quiz/bodies/choice_body.dart';
import 'package:japanese_learn_app/features/quiz/bodies/match_body.dart';
import 'package:japanese_learn_app/features/quiz/bodies/reorder_body.dart';
import 'package:japanese_learn_app/features/quiz/bodies/shadow_body.dart';
import 'package:japanese_learn_app/features/quiz/bodies/typing_body.dart';
import 'package:japanese_learn_app/features/quiz/model/quiz_run_state.dart';
import 'package:japanese_learn_app/features/quiz/view/question_view.dart';
import 'package:japanese_learn_app/features/quiz/view/quiz_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'e2e_harness.dart';

const _maxBotSteps = 3000;
const _idleLimit = Duration(seconds: 40);

/// 一題實際作答的紀錄：題型、作答方式、畫面判定。
final class AnsweredQuestion {
  const AnsweredQuestion({
    required this.type,
    required this.body,
    required this.contentId,
    required this.judgedCorrect,
    required this.showedFurigana,
    this.answeredCorrectly = true,
  });

  final QuestionType type;
  final String body;
  final String contentId;

  /// 檢定題中途不顯示對錯，判定為 null。
  final bool? judgedCorrect;
  final bool showedFurigana;

  /// 測試故意選錯時為 false。
  final bool answeredCorrectly;
}

String _bodyName(QuestionBodyDto body) => switch (body) {
  QuestionBodyDto_Choice() => 'choice',
  QuestionBodyDto_Reorder() => 'reorder',
  QuestionBodyDto_Typing() => 'typing',
  QuestionBodyDto_Match() => 'match',
  QuestionBodyDto_SelfGrade() => 'self_grade',
  QuestionBodyDto_Shadow() => 'shadow',
};

/// 從當前畫面判斷下一個動作，反覆執行到 [until] 成立。
final class StudyBot {
  StudyBot(this.tester);

  final WidgetTester tester;
  final List<AnsweredQuestion> answered = [];

  /// 還要故意選錯幾題選擇題（驗證 Rust 判錯與畫面一致）。
  int wrongChoicesToGive = 0;

  /// 走過的畫面文字，檢查文案用。
  final List<String> seenTexts = [];

  /// 依序按過的流程按鈕（教學「下一步」、過場「繼續」、O6 等）。
  final List<String> advancedThrough = [];
  final Map<String, AnsweredQuestion> _pendingVerdict = {};
  bool _lastChoiceWasWrong = false;

  static const _advanceLabels = [
    '知道了，繼續',
    '做題目',
    '下一段',
    '完成這段',
    '下一步',
    '考一題',
    '開始拼句',
    '下一句',
    '完成',
    '繼續',
    '開始',
  ];

  ProviderContainer get _container =>
      ProviderScope.containerOf(tester.element(find.byType(App)));

  Finder get _feedback => find.byType(QuizFeedback);
  Finder get _question => find.byType(QuestionView);

  Future<void> runUntil(bool Function() until, {String reason = '流程跑完'}) async {
    var idleSince = DateTime.now();
    for (var step = 0; step < _maxBotSteps; step++) {
      if (until()) return;
      if (await _act()) {
        idleSince = DateTime.now();
        continue;
      }
      if (DateTime.now().difference(idleSince) > _idleLimit) {
        fail(
          '$reason：畫面停住超過 ${_idleLimit.inSeconds} 秒\n'
          '${tester.visibleTexts().join('\n')}',
        );
      }
      await tester.pump(const Duration(milliseconds: 60));
    }
    fail('$reason：超過 $_maxBotSteps 步');
  }

  Future<bool> _act() async {
    if (await _continueFromFeedback()) return true;
    if (await _answerCurrentQuestion()) return true;
    if (await _pickRole()) return true;
    if (await _rateShadow()) return true;
    return _tapAdvance();
  }

  Future<bool> _continueFromFeedback() async {
    if (_feedback.evaluate().isEmpty) return false;
    final view = tester.widget<QuizFeedback>(_feedback);
    final pending = _pendingVerdict.remove(_key(view.question));
    if (pending != null) {
      answered.add(
        AnsweredQuestion(
          type: pending.type,
          body: pending.body,
          contentId: pending.contentId,
          judgedCorrect: view.verdict.isCorrect,
          showedFurigana: pending.showedFurigana,
          answeredCorrectly: pending.answeredCorrectly,
        ),
      );
    }
    final next = find.descendant(
      of: _feedback,
      matching: tester.enabledButton('繼續'),
    );
    if (next.evaluate().isEmpty) return false;
    await tester.tapWidget(next.first);
    return true;
  }

  String _key(QuestionDto question) =>
      '${question.reference.questionType.name}/${question.reference.contentId}'
      '/${question.reference.variant}/${question.reference.cardId}';

  Future<bool> _answerCurrentQuestion() async {
    if (_question.evaluate().isEmpty) return false;
    final view = tester.widget<QuestionView>(_question.last);
    if (view.phase is! QuizAnswering) return false;
    final question = view.question;
    final didAnswer = await switch (question.body) {
      final QuestionBodyDto_Choice body => _answerChoice(body),
      final QuestionBodyDto_Reorder body => _answerReorder(body),
      final QuestionBodyDto_Typing body => _answerTyping(body),
      final QuestionBodyDto_Match body => _answerMatch(body),
      QuestionBodyDto_SelfGrade() => _answerSelfGrade(),
      QuestionBodyDto_Shadow() => _answerShadow(),
    };
    if (didAnswer) {
      final record = AnsweredQuestion(
        type: question.questionType,
        body: _bodyName(question.body),
        contentId: question.reference.contentId,
        judgedCorrect: null,
        showedFurigana: _hasFurigana(question),
        answeredCorrectly: !_lastChoiceWasWrong,
      );
      _lastChoiceWasWrong = false;
      // 自評與跟讀答完直接下一題，沒有回饋條，也就沒有對錯判定（§3.4）
      if (_skipsFeedback(question.body)) {
        answered.add(record);
      } else {
        _pendingVerdict[_key(question)] = record;
      }
    }
    return didAnswer;
  }

  bool _skipsFeedback(QuestionBodyDto body) =>
      body is QuestionBodyDto_SelfGrade || body is QuestionBodyDto_Shadow;

  /// 題幹的振假名要真的畫在畫面上（隱藏文字的聽力題作答前不算）。
  bool _hasFurigana(QuestionDto question) {
    final prompt = question.prompt;
    final sentence = prompt.text;
    if (sentence == null || prompt.hideTextUntilAnswered) return false;
    final rubies = [
      for (final word in sentence.words)
        for (final part in word.ruby)
          if (part.ruby != null) part.ruby!,
    ];
    final visible = tester.visibleTexts();
    return rubies.isNotEmpty && rubies.any(visible.contains);
  }

  Future<bool> _answerChoice(QuestionBodyDto_Choice body) async {
    final tiles = find.descendant(
      of: find.byType(ChoiceBody).last,
      matching: find.byType(ChoiceTile),
    );
    if (tiles.evaluate().length != body.options.length) return false;
    final wrong = wrongChoicesToGive > 0 && body.options.length > 1;
    final index = wrong
        ? body.options.indexWhere((o) => o.id != body.correctOptionId)
        : body.options.indexWhere((o) => o.id == body.correctOptionId);
    if (wrong) wrongChoicesToGive--;
    await tester.tapWidget(tiles.at(index));
    _lastChoiceWasWrong = wrong;
    return true;
  }

  Future<bool> _answerReorder(QuestionBodyDto_Reorder body) async {
    if (tester.hasEnabledButton('開始拼句')) {
      await tester.tapButton('開始拼句');
    }
    Finder bank() => find.descendant(
      of: find.byType(ReorderBody).last,
      matching: find.byWidgetPredicate((w) => w is WordTile && !w.placed),
    );
    if (bank().evaluate().length != body.chunks.length) return false;
    for (final chunkIndex in body.acceptOrders.first) {
      final position = body.chunks.indexWhere((c) => c.index == chunkIndex);
      await tester.tapWidget(bank().at(position));
    }
    await tester.tapButton('確認');
    return true;
  }

  Future<bool> _answerTyping(QuestionBodyDto_Typing body) async {
    final field = find.descendant(
      of: find.byType(TypingBody).last,
      matching: find.byType(TextField),
    );
    if (field.evaluate().isEmpty) return false;
    final romaji = _container
        .read(textToolsProvider)
        .romanizeReading(body.expectedReading, ReadingMode.word);
    await tester.enterText(field.last, romaji ?? body.expectedReading);
    await tester.pump();
    await tester.tapButton('確認');
    return true;
  }

  Future<bool> _answerMatch(QuestionBodyDto_Match body) async {
    final board = find.byType(MatchBody).last;
    final tiles = find.descendant(of: board, matching: find.byType(ChoiceTile));
    if (tiles.evaluate().length != body.pairs.length * 2) return false;
    for (var row = 0; row < body.pairs.length; row++) {
      await tester.tapWidget(tiles.at(row * 2));
      final right = find.descendant(
        of: board,
        matching: find.text(body.pairs[row].right),
      );
      await tester.tapWidget(right.first);
    }
    return true;
  }

  Future<bool> _answerSelfGrade() async {
    final rating = find.byType(RatingBar);
    if (rating.evaluate().isEmpty) {
      final hint = find.text('翻面看答案');
      if (hint.evaluate().isEmpty) return false;
      // 卡片中央可能是播放鈕，點提示字才一定是翻面
      await tester.tapWidget(hint.last);
      await tester.pumpUntilFound(find.byType(RatingBar));
      await tester.pumpFor(const Duration(milliseconds: 450));
    }
    await tester.tapWidget(
      find.descendant(of: rating, matching: find.text('記得')),
    );
    return true;
  }

  Future<bool> _answerShadow() async {
    final kept = find.descendant(
      of: find.byType(ShadowBody).last,
      matching: tester.enabledButton('跟上了'),
    );
    if (kept.evaluate().isEmpty) return false;
    await tester.tapWidget(kept.first);
    return true;
  }

  Future<bool> _pickRole() async {
    if (!tester.hasVisibleText('選一個角色，輪到你時開口說。')) return false;
    final tiles = find.byType(RuledTile);
    if (tiles.evaluate().isEmpty) return false;
    await tester.tapWidget(tiles.first);
    return true;
  }

  Future<bool> _rateShadow() async {
    if (find.byType(QuestionView).evaluate().isNotEmpty) return false;
    if (!tester.hasEnabledButton('跟上了')) return false;
    await tester.tapButton('跟上了');
    return true;
  }

  Future<bool> _tapAdvance() async {
    for (final label in _advanceLabels) {
      if (tester.hasEnabledButton(label)) {
        advancedThrough.add(label);
        seenTexts.addAll(tester.visibleTexts());
        await tester.tapButton(label);
        await _waitPastTap();
        return true;
      }
    }
    return false;
  }

  /// 按鈕按下後等一下轉場，避免把同一個按鈕連點兩次。
  Future<void> _waitPastTap() =>
      tester.pumpFor(const Duration(milliseconds: 320));

  void expectAllCorrect() {
    final mismatched = answered.where(
      (a) => a.judgedCorrect != null && a.judgedCorrect != a.answeredCorrectly,
    );
    expect(
      mismatched.map((a) => '${a.type.name}/${a.body}/${a.contentId}'),
      isEmpty,
      reason: 'Rust 判定與實際作答不一致（點了正解判錯，或點了錯的判對）',
    );
  }
}
