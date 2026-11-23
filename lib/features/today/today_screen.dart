import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../core/backend/today_view_provider.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/hanko_badge.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/refresh_on_return.dart';
import '../../design/widgets/skeleton_lines.dart';
import '../../design/widgets/voice_banner.dart';
import 'romaji_confirm_line.dart';
import 'today_copy.dart';
import 'today_providers.dart';
import 'today_task_list.dart';

/// T1 今日（§3.2）：一張由上而下的稿紙清單，不是卡片。
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(todayViewProvider, (_, next) {
      if (next.error is NoPlanFailure) {
        ref.read(onboardingDoneProvider).value = false;
      }
    });
    // Android 返回鍵由 go_router 直接 pop，T2 來不及通知，所以回來時自己重取
    return RefreshOnReturn(
      onReturn: () => refreshTodayData(ref),
      child: PaperScaffold(
        body: AsyncBody(
          value: ref.watch(todayViewProvider),
          loading: const DelayedReveal(child: SkeletonLines(lines: 5)),
          onRetry: () => ref.invalidate(todayViewProvider),
          data: (view) => _TodayBody(view: view),
        ),
      ),
    );
  }
}

class _TodayBody extends ConsumerWidget {
  const _TodayBody({required this.view});

  final TodayViewDto view;

  bool get _allDone =>
      view.tasks.isNotEmpty && view.tasks.every((task) => task.done);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovery = view.recoveryReason;
    final hasRows = visibleTasks(view).isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(view: view, allDone: _allDone, showStamp: _allDone && hasRows),
        const SizedBox(height: AppSpace.s4),
        const VoiceBanner(),
        const RomajiConfirmLine(),
        // 清單是空的（休息日沒有複習）時沒有事可做，不叫人「今天先看完」
        if (recovery != null && hasRows) ...[
          const SizedBox(height: AppSpace.s3),
          AppText(
            recoveryMessage(
              recovery,
              minimalNew: view.minimalNew,
              hasMainSlice: hasMainSlice(view),
            ),
            color: AppTokens.of(context).ink.secondary,
          ),
        ],
        const SizedBox(height: AppSpace.s5),
        if (hasRows) TodayTaskList(view: view) else const _FreePractice(),
        if (_allDone && view.canLearnMore) const _LearnMore(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({
    required this.view,
    required this.allDone,
    required this.showStamp,
  });

  final TodayViewDto view;
  final bool allDone, showStamp;

  static const _stampSize = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final studied = ref.watch(weekStudiedDaysProvider(view.logicalDate));
    final week = studied.value;
    final meta = [
      // 全部做完就不估時間，「約 0 分鐘」沒有意義
      if (view.isStudyDay && !allDone) estimatedLabel(view.estimatedMinutes),
      if (week != null) '本週已學 $week 天',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                weekdayLabel(view.logicalDate),
                scale: TypeScale.label,
                color: t.ink.secondary,
              ),
              AppText(dateLabel(view.logicalDate), scale: TypeScale.displayL),
              const SizedBox(height: AppSpace.s2),
              if (view.isStudyDay)
                MixedText(todayHeadline(view), scale: TypeScale.title)
              else
                ..._rest(t),
              if (meta.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s1),
                AppText(meta, scale: TypeScale.caption, color: t.ink.secondary),
              ],
            ],
          ),
        ),
        if (showStamp)
          const HankoBadge('済', size: _stampSize, semanticLabel: '今天完成了'),
      ],
    );
  }

  List<Widget> _rest(AppTokens t) => [
    const AppText('今天休息', scale: TypeScale.displayM),
    if (view.nextStudyDate != null)
      AppText(
        '下次學習：${shortDateLabel(view.nextStudyDate!)}',
        color: t.ink.secondary,
      ),
  ];
}

class _FreePractice extends StatelessWidget {
  const _FreePractice();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        '今天沒有排定的任務。想練的話，隨時可以從學習頁開始。',
        color: AppTokens.of(context).ink.secondary,
      ),
      const SizedBox(height: AppSpace.s4),
      GhostButton(label: '自由練習', onPressed: () => context.go(AppRoutes.learn)),
    ],
  );
}

class _LearnMore extends ConsumerStatefulWidget {
  const _LearnMore();

  @override
  ConsumerState<_LearnMore> createState() => _LearnMoreState();
}

class _LearnMoreState extends ConsumerState<_LearnMore> {
  bool _busy = false;
  AppFailure? _failure;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _failure = null;
    });
    try {
      final start = await learnMoreStart(ref);
      if (mounted && start != null) {
        unawaited(context.push(AppRoutes.sessionToday(start: start)));
      }
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkButton(label: '再學一批', onPressed: _busy ? null : _run),
        const SizedBox(height: AppSpace.s1),
        AppText(
          '不影響明天的安排',
          scale: TypeScale.caption,
          color: AppTokens.of(context).ink.secondary,
        ),
        if (_failure != null) ...[
          const SizedBox(height: AppSpace.s3),
          ErrorSlip(failure: _failure!, onRetry: _run),
        ],
      ],
    ),
  );
}
