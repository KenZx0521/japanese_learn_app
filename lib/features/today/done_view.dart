import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/failures.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/today_view_provider.dart';
import '../../design/motion.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/hanko_badge.dart';
import '../../design/widgets/ink_buttons.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/stamp_overlay.dart';
import 'today_copy.dart';
import 'today_providers.dart';

/// T3 完成頁（§3.2）：大朱印、本週已學天數為主視覺，資料已寫入所以沒有錯誤狀態。
class DoneView extends ConsumerStatefulWidget {
  const DoneView({super.key});

  @override
  ConsumerState<DoneView> createState() => _DoneViewState();
}

class _DoneViewState extends ConsumerState<DoneView> {
  static const _stampSize = 96.0;

  bool _settled = false;
  bool _learningMore = false;
  bool _leaving = false;
  AppFailure? _failure;

  /// 結案在進這一頁之前，T1 還掛著時本週天數的快取不會自己失效。
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(weekStudiedDaysProvider);
    });
  }

  /// 殼層只有一把 GlobalKey：T2 從 T1 推入時，完成頁一進來殼層就開始淡出；
  /// 淡出途中回到殼層會有兩棵樹同時用那把 key，所以等本頁轉場結束才走。
  void _backToToday() {
    if (_leaving) return;
    _leaving = true;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      context.go(AppRoutes.today);
      return;
    }
    void onStatus(AnimationStatus status) {
      if (!status.isCompleted) return;
      animation.removeStatusListener(onStatus);
      if (mounted) context.go(AppRoutes.today);
    }

    animation.addStatusListener(onStatus);
  }

  Future<void> _learnMore() async {
    setState(() {
      _learningMore = true;
      _failure = null;
    });
    try {
      final start = await learnMoreStart(ref);
      if (!mounted) return;
      if (start == null) {
        context.go(AppRoutes.today);
      } else {
        context.go(AppRoutes.sessionToday(start: start));
      }
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _failure = failure);
    } finally {
      if (mounted) setState(() => _learningMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = AppMotion.of(context);
    final view = ref.watch(todayViewProvider).value;
    // 印章在 PaperScaffold 外，自己提供 Material，否則文字會帶黃色底線
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PaperScaffold(body: _content(view)),
          Align(
            alignment: Alignment.topRight,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpace.s5),
                child: AnimatedOpacity(
                  opacity: _settled ? 1 : 0,
                  duration: motion.base.duration,
                  child: const HankoBadge(
                    '済',
                    size: _stampSize,
                    semanticLabel: '今天完成了',
                  ),
                ),
              ),
            ),
          ),
          StampOverlay(
            play: true,
            onDone: () {
              if (mounted) setState(() => _settled = true);
            },
          ),
        ],
      ),
    );
  }

  Widget _content(TodayViewDto? view) {
    final t = AppTokens.of(context);
    final failure = _failure;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: _stampSize + AppSpace.s5),
        const EyebrowText('今天完成了'),
        const SizedBox(height: AppSpace.s2),
        if (view != null) _Summary(logicalDate: view.logicalDate),
        const SizedBox(height: AppSpace.s6),
        if (view?.canLearnMore ?? false) ...[
          InkButton(
            label: '再學一批',
            onPressed: _learningMore ? null : () => unawaited(_learnMore()),
          ),
          const SizedBox(height: AppSpace.s1),
          AppText('不影響明天的安排', scale: TypeScale.caption, color: t.ink.secondary),
          const SizedBox(height: AppSpace.s3),
        ],
        if (failure != null) ...[
          ErrorSlip(failure: failure, onRetry: () => unawaited(_learnMore())),
          const SizedBox(height: AppSpace.s3),
        ],
        GhostButton(label: '回到今日', autofocus: true, onPressed: _backToToday),
      ],
    );
  }
}

class _Summary extends ConsumerWidget {
  const _Summary({required this.logicalDate});

  final String logicalDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final days = ref.watch(weekStudiedDaysProvider(logicalDate)).value;
    final activity = ref.watch(todayActivityProvider(logicalDate)).value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (days != null) AppText('本週已學 $days 天', scale: TypeScale.displayL),
        if (activity != null) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(
            '今天學了 ${studyTimeLabel(activity.studyMinutes)}，答了 ${activity.answers} 題',
            color: t.ink.secondary,
          ),
        ],
      ],
    );
  }
}
