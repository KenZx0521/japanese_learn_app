import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/backend/providers.dart';
import '../../../core/tts/audio_available.dart';
import '../today_providers.dart';
import 'today_flow_reducer.dart';

final todayFlowProvider = NotifierProvider.autoDispose
    .family<TodayFlowController, TodayFlowState, String?>(
      TodayFlowController.new,
    );

AppFailure _asFailure(Exception error) =>
    error is AppFailure ? error : const UnexpectedFailure();

/// T2 的副作用：取今日資料、`complete_task`、O6 旗標與計時（§3.2）。
class TodayFlowController extends Notifier<TodayFlowState> {
  TodayFlowController(this.start);

  final String? start;
  final Stopwatch _taskClock = Stopwatch();
  bool _loadStarted = false;
  bool _clockPaused = false;

  @override
  TodayFlowState build() {
    ref.listen(audioResolvedProvider, (_, resolved) {
      if (resolved) unawaited(_loadOnce());
    });
    ref.listen(audioAvailableProvider, (previous, next) {
      if (previous != next && state.view != null) unawaited(_refreshView());
    });
    ref.listen(resumeTickProvider, (_, _) => unawaited(_checkDayChange()));
    if (ref.read(audioResolvedProvider)) {
      unawaited(Future.microtask(_loadOnce));
    }
    return TodayFlowState.initial;
  }

  void _dispatch(FlowEvent event) {
    final before = state.phase;
    state = reduceTodayFlow(state, event);
    _syncClock(before, state.phase);
  }

  void _syncClock(FlowPhase before, FlowPhase after) {
    final restart = switch ((before, after)) {
      (FlowRunning(task: final a), FlowRunning(task: final b)) =>
        a.key != b.key,
      (_, FlowRunning()) => true,
      _ => false,
    };
    if (restart) {
      _taskClock
        ..reset()
        ..start();
      _clockPaused = false;
    }
    if (after is FlowRunning) {
      ref.read(taskInProgressProvider.notifier).mark(after.task.key);
    } else if (after is! FlowClosing && after is! FlowClosePending) {
      _taskClock.stop();
    }
  }

  /// App 進背景時暫停計時（§3.2）。
  void pauseClock() {
    if (!_taskClock.isRunning) return;
    _taskClock.stop();
    _clockPaused = true;
  }

  void resumeClock() {
    if (_clockPaused && state.phase is FlowRunning) _taskClock.start();
    _clockPaused = false;
  }

  Future<void> _loadOnce() async {
    if (_loadStarted) return;
    _loadStarted = true;
    await _load();
  }

  Future<void> reload() async {
    _dispatch(const FlowViewLoading());
    await _load();
  }

  Future<TodayViewDto> _fetchToday() =>
      ref.read(todayRepositoryProvider).today(ref.read(audioAvailableProvider));

  bool _dayChanged(TodayViewDto view) =>
      state.view != null && view.logicalDate != state.view?.logicalDate;

  void _rollDay() {
    ref.read(taskInProgressProvider.notifier).clear();
    _dispatch(const FlowDayRolled());
  }

  Future<void> _load() async {
    try {
      final view = await _fetchToday();
      if (ref.mounted) _dispatch(FlowViewLoaded(view, start: start));
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      if (ref.mounted) _dispatch(FlowLoadFailed(_asFailure(error)));
    }
  }

  /// 語音改變時以同 seed 重取；失敗只記錄，畫面維持現狀（§6.6）。
  Future<void> _refreshView() async {
    try {
      final view = await _fetchToday();
      if (!ref.mounted) return;
      _dayChanged(view) ? _rollDay() : _dispatch(FlowViewRefreshed(view));
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  /// 回前景時確認還是同一天；讀不到就維持現狀，下一次回前景再確認。
  Future<void> _checkDayChange() async {
    if (state.view == null || state.phase is FlowClosing) return;
    try {
      final view = await _fetchToday();
      if (ref.mounted && _dayChanged(view)) _rollDay();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
    }
  }

  void skipTask(TaskDto task) => _dispatch(FlowTaskSkipped(task.key));

  void continueToNext() => _dispatch(const FlowContinued());

  void expectationSeen() => _dispatch(const FlowExpectationSeen());

  void tailFinished() => _dispatch(const FlowTailFinished());

  /// 只結案一次：連點或元件重複回報時，第二次已不在 `FlowRunning`。
  Future<void> finishTask(TaskDto task) async {
    final phase = state.phase;
    if (phase is! FlowRunning || phase.task.key != task.key) return;
    _taskClock.stop();
    await _close(task, _taskClock.elapsedMilliseconds);
  }

  Future<void> retryClose() async {
    final phase = state.phase;
    if (phase is FlowClosePending) await _close(phase.task, phase.durationMs);
  }

  Future<void> _close(TaskDto task, int durationMs) async {
    _dispatch(FlowClosingStarted(task));
    try {
      final view = await ref
          .read(todayRepositoryProvider)
          .completeTask(task.key, durationMs, ref.read(audioAvailableProvider));
      if (!ref.mounted) return;
      final showExpectation = task is TaskDto_NewContent && await _hasMarker();
      if (!ref.mounted) return;
      ref.read(taskInProgressProvider.notifier).clear();
      _dispatch(FlowTaskClosed(view, showExpectation: showExpectation));
    } on NotFoundFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (ref.mounted) await _leaveMissingTask();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      if (ref.mounted) {
        _dispatch(FlowCloseFailed(task, _asFailure(error), durationMs));
      }
    }
  }

  /// 這一項已不在今日快照（換日或計畫重排）：重試永遠不會成功，重新載入。
  Future<void> _leaveMissingTask() async {
    try {
      final view = await _fetchToday();
      if (!ref.mounted) return;
      ref.read(taskInProgressProvider.notifier).clear();
      _dayChanged(view) ? _rollDay() : _dispatch(FlowViewLoaded(view));
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      if (ref.mounted) _dispatch(FlowLoadFailed(_asFailure(error)));
    }
  }

  Future<bool> _hasMarker() async {
    try {
      return await ref.read(firstRunMarkerProvider).exists();
    } on Exception catch (error, stack) {
      logLocal(error, stack);
      return false;
    }
  }

  /// 「先略過」：回傳的清單已不含此項，不呼叫 `complete_task`（§3.2）。
  Future<void> dismissCheckpoint(String milestoneId) async {
    final view = await ref
        .read(drillRepositoryProvider)
        .checkpointDismiss(milestoneId, ref.read(audioAvailableProvider));
    if (ref.mounted) _dispatch(FlowTaskClosed(view));
  }
}
