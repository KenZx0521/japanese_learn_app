import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/backend/today_view_provider.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/tts/stop_speech_on_leave.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/error_slip.dart';
import '../../../design/widgets/esc_to_leave.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/paper_scaffold.dart';
import '../../../design/widgets/pressable.dart';
import '../../../design/widgets/skeleton_lines.dart';
import '../../../design/widgets/stamp_overlay.dart';
import '../../session/cards/card_runner.dart';
import '../today_copy.dart';
import 'runners/task_runner.dart';
import 'today_flow_controller.dart';
import 'today_flow_reducer.dart';

/// T2 今日連續流程（§3.2）：同一路由內依序換元件，中途離開不需確認。
class TodayFlowView extends ConsumerStatefulWidget {
  const TodayFlowView({this.start, super.key});

  final String? start;

  @override
  ConsumerState<TodayFlowView> createState() => _TodayFlowViewState();
}

class _TodayFlowViewState extends ConsumerState<TodayFlowView> {
  late final AppLifecycleListener _lifecycle;

  TodayFlowController get _controller =>
      ref.read(todayFlowProvider(widget.start).notifier);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () => _controller.pauseClock(),
      onShow: () => _controller.resumeClock(),
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _leave() {
    ref.invalidate(todayViewProvider);
    context.go(AppRoutes.today);
  }

  Future<void> _showExpectation() async {
    await context.push(AppRoutes.sessionExpectation);
    if (mounted) _controller.expectationSeen();
  }

  void _onPhase(FlowPhase? previous, FlowPhase next) {
    if (next is FlowShowExpectation && previous is! FlowShowExpectation) {
      unawaited(_showExpectation());
    } else if (next is FlowDone && previous is! FlowDone) {
      ref.invalidate(todayViewProvider);
      context.go(AppRoutes.sessionDone);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = todayFlowProvider(widget.start);
    ref.listen(provider.select((s) => s.phase), _onPhase);
    final state = ref.watch(provider);
    return EscToLeave(
      onEscape: _leave,
      child: StopSpeechOnLeave(
        child: PaperScaffold(
          scrollable: false,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FlowHeader(phase: state.phase, onLeave: _leave),
              const SizedBox(height: AppSpace.s4),
              Expanded(child: _body(state)),
            ],
          ),
        ),
      ),
    );
  }

  int _seed(TodayFlowState state) => sessionSeed(state.view?.logicalDate ?? '');

  Widget _body(TodayFlowState state) => switch (state.phase) {
    FlowLoading() ||
    FlowClosing() ||
    FlowShowExpectation() ||
    FlowDone() => const DelayedReveal(child: SkeletonLines()),
    FlowLoadError(:final failure) => ErrorSlip(
      failure: failure,
      onRetry: () => unawaited(_controller.reload()),
    ),
    FlowNothing() => _EndNote(title: '現在沒有要做的任務。', onBack: _leave),
    FlowIncomplete() => _EndNote(
      title: '今天有項目沒做完。',
      note: '略過的項目還在今日清單上，之後可以回來做。',
      onBack: _leave,
    ),
    FlowDayChanged() => _EndNote(
      title: '日期已經換了。',
      note: '今天的任務重新排好了，回到今日再開始。',
      onBack: _leave,
    ),
    FlowRunning(:final task) => TaskRunner(
      key: ValueKey(task.key),
      task: task,
      seed: _seed(state),
      onFinished: () => unawaited(_controller.finishTask(task)),
      onSkip: () => _controller.skipTask(task),
      onDismissCheckpoint: _controller.dismissCheckpoint,
    ),
    FlowClosePending(:final failure) => ErrorSlip(
      failure: failure,
      onRetry: () => unawaited(_controller.retryClose()),
    ),
    FlowTransition(:final next, :final skipped) => _Transition(
      next: next,
      skipped: skipped,
      onContinue: _controller.continueToNext,
      onLeave: _leave,
    ),
    FlowTail() => CardRunner(
      seed: _seed(state),
      onDone: (_) => _controller.tailFinished(),
    ),
  };
}

class _FlowHeader extends StatelessWidget {
  const _FlowHeader({required this.phase, required this.onLeave});

  final FlowPhase phase;
  final VoidCallback onLeave;

  String? get _label => switch (phase) {
    FlowRunning(:final task) || FlowClosing(:final task) => taskTitle(task),
    FlowTail() => '收尾',
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final label = _label;
    return Row(
      children: [
        Expanded(
          child: label == null
              ? const SizedBox.shrink()
              : MixedText(
                  label,
                  scale: TypeScale.label,
                  color: t.ink.secondary,
                ),
        ),
        _LeaveLink(onTap: onLeave),
      ],
    );
  }
}

class _LeaveLink extends StatelessWidget {
  const _LeaveLink({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        color: state.hovered ? t.paper.raised : Colors.transparent,
        child: AppText('今天先到這', scale: TypeScale.label, color: t.ink.secondary),
      ),
    );
  }
}

/// 流程結束但不是「完成」的出口。
class _EndNote extends StatelessWidget {
  const _EndNote({required this.title, required this.onBack, this.note});

  final String title;
  final String? note;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final detail = note;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(title, scale: TypeScale.title),
        if (detail != null) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(detail, color: AppTokens.of(context).ink.secondary),
        ],
        const SizedBox(height: AppSpace.s4),
        GhostButton(label: '回到今日', onPressed: onBack),
      ],
    );
  }
}

/// 任務之間的過場：上一項完成蓋章，略過不蓋章，不用倒數自動跳轉（§3.2）。
class _Transition extends StatelessWidget {
  const _Transition({
    required this.next,
    required this.skipped,
    required this.onContinue,
    required this.onLeave,
  });

  final TaskDto next;
  final bool skipped;
  final VoidCallback onContinue, onLeave;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(skipped ? '這一項先略過。' : '這一項完成了。', scale: TypeScale.title),
          const SizedBox(height: AppSpace.s6),
          EyebrowText('下一項'),
          const SizedBox(height: AppSpace.s2),
          MixedText(transitionLabel(next), scale: TypeScale.title),
          const SizedBox(height: AppSpace.s6),
          InkButton(label: '繼續', onPressed: onContinue, autofocus: true),
          const SizedBox(height: AppSpace.s2),
          GhostButton(label: '今天先到這', onPressed: onLeave),
        ],
      ),
      if (!skipped)
        const Positioned.fill(child: StampOverlay(play: true, size: 96)),
    ],
  );
}
