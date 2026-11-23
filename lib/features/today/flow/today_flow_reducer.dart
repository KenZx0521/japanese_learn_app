import 'package:material_ui/material_ui.dart' show immutable;

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';

/// T2 目前停在哪一步（§3.2）。純狀態，副作用在 controller。
@immutable
sealed class FlowPhase {
  const FlowPhase();
}

final class FlowLoading extends FlowPhase {
  const FlowLoading();
}

final class FlowLoadError extends FlowPhase {
  const FlowLoadError(this.failure);
  final AppFailure failure;
}

/// 沒有要做的事（例如深層連結或狀態剛變），不是「完成」。
final class FlowNothing extends FlowPhase {
  const FlowNothing();
}

final class FlowRunning extends FlowPhase {
  const FlowRunning(this.task);
  final TaskDto task;
}

/// `complete_task` 進行中。
final class FlowClosing extends FlowPhase {
  const FlowClosing(this.task);
  final TaskDto task;
}

/// `complete_task` 失敗：留在此處重試，不前進（§5.4）。
final class FlowClosePending extends FlowPhase {
  const FlowClosePending(this.task, this.failure, this.durationMs);
  final TaskDto task;
  final AppFailure failure;
  final int durationMs;
}

final class FlowTransition extends FlowPhase {
  const FlowTransition(this.next, {this.skipped = false});
  final TaskDto next;

  /// 上一項是略過的，不是完成，過場不蓋章。
  final bool skipped;
}

/// 清單跑完但有略過的項目：不是「今天完成了」（§3.2）。
final class FlowIncomplete extends FlowPhase {
  const FlowIncomplete();
}

/// 開著 T2 跨過換日：昨天的任務不能再結案到今天的快照上。
final class FlowDayChanged extends FlowPhase {
  const FlowDayChanged();
}

final class FlowShowExpectation extends FlowPhase {
  const FlowShowExpectation();
}

final class FlowTail extends FlowPhase {
  const FlowTail();
}

final class FlowDone extends FlowPhase {
  const FlowDone();
}

@immutable
final class TodayFlowState {
  const TodayFlowState({
    required this.phase,
    this.view,
    this.skipped = const {},
  });

  static const initial = TodayFlowState(phase: FlowLoading());

  final FlowPhase phase;
  final TodayViewDto? view;

  /// 取題為空而略過的任務，不呼叫 `complete_task`（§3.2）。
  final Set<String> skipped;

  TodayFlowState copy({
    FlowPhase? phase,
    TodayViewDto? view,
    Set<String>? skipped,
  }) => TodayFlowState(
    phase: phase ?? this.phase,
    view: view ?? this.view,
    skipped: skipped ?? this.skipped,
  );
}

@immutable
sealed class FlowEvent {
  const FlowEvent();
}

final class FlowViewLoaded extends FlowEvent {
  const FlowViewLoaded(this.view, {this.start});
  final TodayViewDto view;
  final String? start;
}

final class FlowViewLoading extends FlowEvent {
  const FlowViewLoading();
}

final class FlowLoadFailed extends FlowEvent {
  const FlowLoadFailed(this.failure);
  final AppFailure failure;
}

final class FlowClosingStarted extends FlowEvent {
  const FlowClosingStarted(this.task);
  final TaskDto task;
}

final class FlowCloseFailed extends FlowEvent {
  const FlowCloseFailed(this.task, this.failure, this.durationMs);
  final TaskDto task;
  final AppFailure failure;
  final int durationMs;
}

final class FlowTaskClosed extends FlowEvent {
  const FlowTaskClosed(this.view, {this.showExpectation = false});
  final TodayViewDto view;
  final bool showExpectation;
}

final class FlowExpectationSeen extends FlowEvent {
  const FlowExpectationSeen();
}

final class FlowTaskSkipped extends FlowEvent {
  const FlowTaskSkipped(this.key);
  final String key;
}

final class FlowContinued extends FlowEvent {
  const FlowContinued();
}

final class FlowTailFinished extends FlowEvent {
  const FlowTailFinished();
}

/// 語音可用性改變後以同 seed 重取的今日資料（§6.6）。
final class FlowViewRefreshed extends FlowEvent {
  const FlowViewRefreshed(this.view);
  final TodayViewDto view;
}

/// 重取今日資料時發現 `logical_date` 已經換了。
final class FlowDayRolled extends FlowEvent {
  const FlowDayRolled();
}

TaskDto? _firstUndone(TodayViewDto view, Set<String> skipped) {
  for (final task in view.tasks) {
    if (!task.done && !skipped.contains(task.key)) return task;
  }
  return null;
}

/// 「再學一批」與引導結束時決定下一次進 T2 從哪開始。
String? firstRunnableKey(TodayViewDto view) =>
    _firstUndone(view, const {})?.key;

/// 清單跑完：有收尾先收尾；有略過的項目就不算完成。
FlowPhase _ending(TodayViewDto view, Set<String> skipped) {
  if (view.learningTail > 0) return const FlowTail();
  return skipped.isEmpty ? const FlowDone() : const FlowIncomplete();
}

/// 任務結案或略過後的下一步：有下一項就過場，清單跑完才進收尾或結尾（§3.2）。
FlowPhase _afterTask(
  TodayViewDto view,
  Set<String> skipped, {
  bool justSkipped = false,
}) {
  final next = _firstUndone(view, skipped);
  if (next != null) return FlowTransition(next, skipped: justSkipped);
  return _ending(view, skipped);
}

FlowPhase _entryPhase(TodayViewDto view, String? start) {
  final picked = view.tasks.where((t) => t.key == start && !t.done).firstOrNull;
  final first = picked ?? _firstUndone(view, const {});
  if (first != null) return FlowRunning(first);
  return view.learningTail > 0 ? const FlowTail() : const FlowNothing();
}

TaskDto? _findTask(TodayViewDto view, String key) {
  for (final task in view.tasks) {
    if (task.key == key) return task;
  }
  return null;
}

FlowPhase _afterRefresh(TodayFlowState state, TodayViewDto view) {
  final phase = state.phase;
  if (phase is! FlowRunning) return phase;
  final updated = _findTask(view, phase.task.key);
  if (updated != null && !updated.done) return FlowRunning(updated);
  final next = _firstUndone(view, state.skipped);
  if (next != null) return FlowRunning(next);
  return _ending(view, state.skipped);
}

TodayFlowState reduceTodayFlow(
  TodayFlowState state,
  FlowEvent event,
) => switch (event) {
  FlowViewLoaded(:final view, :final start) => state.copy(
    phase: _entryPhase(view, start),
    view: view,
  ),
  FlowViewLoading() => state.copy(phase: const FlowLoading()),
  FlowLoadFailed(:final failure) => state.copy(phase: FlowLoadError(failure)),
  FlowClosingStarted(:final task) => state.copy(phase: FlowClosing(task)),
  FlowCloseFailed(:final task, :final failure, :final durationMs) => state.copy(
    phase: FlowClosePending(task, failure, durationMs),
  ),
  FlowTaskClosed(:final view, :final showExpectation) => state.copy(
    view: view,
    phase: showExpectation
        ? const FlowShowExpectation()
        : _afterTask(view, state.skipped),
  ),
  FlowExpectationSeen() =>
    state.phase is FlowShowExpectation
        ? state.copy(phase: _afterTask(state.view!, state.skipped))
        : state,
  FlowTaskSkipped(:final key) => _skip(state, key),
  FlowContinued() => _continued(state),
  FlowTailFinished() => state.copy(
    phase: state.skipped.isEmpty ? const FlowDone() : const FlowIncomplete(),
  ),
  FlowViewRefreshed(:final view) => state.copy(
    view: view,
    phase: _afterRefresh(state, view),
  ),
  FlowDayRolled() => state.copy(phase: const FlowDayChanged()),
};

TodayFlowState _skip(TodayFlowState state, String key) {
  final skipped = {...state.skipped, key};
  return state.copy(
    skipped: skipped,
    phase: _afterTask(state.view!, skipped, justSkipped: true),
  );
}

TodayFlowState _continued(TodayFlowState state) {
  final phase = state.phase;
  return phase is FlowTransition
      ? state.copy(phase: FlowRunning(phase.next))
      : state;
}
