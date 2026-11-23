import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/settings/settings_controller.dart';

final questionHintsProvider =
    NotifierProvider<QuestionHintsController, Set<QuestionType>>(
      QuestionHintsController.new,
    );

/// 記住本次執行已提示過的題型（§3.12）。寫入失敗或還沒寫完時，靠這份避免重複提示，
/// 也避免連續兩次覆寫把前一筆蓋掉。
class QuestionHintsController extends Notifier<Set<QuestionType>> {
  @override
  Set<QuestionType> build() => const {};

  /// 設定尚未載入時回 false，寧可不提示也不重複提示。
  bool shouldShow(QuestionType type) {
    final seen = ref.read(settingsProvider).value?.seenQuestionHints;
    if (seen == null) return false;
    return !seen.contains(type) && !state.contains(type);
  }

  void markShown(QuestionType type) {
    final seen = ref.read(settingsProvider).value?.seenQuestionHints;
    if (seen == null || state.contains(type)) return;
    state = {...state, type};
    unawaited(_persist({...seen, ...state}.toList()));
  }

  Future<void> _persist(List<QuestionType> all) async {
    try {
      await ref
          .read(settingsProvider.notifier)
          .patch(settingsPatch(seenQuestionHints: all));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
    }
  }
}
