import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/pressable.dart';
import '../onboarding_draft.dart';
import '../onboarding_frame.dart';
import '../plan_estimate_copy.dart';

final _planPreviewProvider = FutureProvider.autoDispose
    .family<PlanViewDto, PlanPreviewKey>(
      (ref, key) =>
          ref.watch(planRepositoryProvider).preview(planInputFromKey(key)),
    );

final _contentStageProvider = FutureProvider.autoDispose<ContentStage>(
  (ref) async =>
      (await ref.watch(courseRepositoryProvider).overview()).contentStage,
);

/// O4 每天多久（§3.1）。粗估完成日即時更新，一律標明「粗估」。
class TimeStep extends ConsumerWidget {
  const TimeStep({super.key});

  static const _targets = [(0, '不設定'), (3, '三個月後'), (6, '半年後'), (12, '一年後')];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return OnboardingFrame(
      step: 3,
      title: '每天多久？',
      bottom: InkButton(
        label: '下一步',
        expanded: true,
        onPressed: draft.weekdays.isEmpty
            ? null
            : () => unawaited(context.push(AppRoutes.welcomeStep('o5'))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MinutesRow(),
          const SizedBox(height: AppSpace.s5),
          const EyebrowText('學習日'),
          const SizedBox(height: AppSpace.s2),
          const _WeekdayChoices(),
          const SizedBox(height: AppSpace.s5),
          const EyebrowText('目標（可不選）'),
          const SizedBox(height: AppSpace.s2),
          _TargetChoices(
            targets: _targets,
            selected: draft.targetDate,
            onSelect: notifier.setTargetDate,
          ),
          const SizedBox(height: AppSpace.s5),
          _Estimate(previewKey: draft.previewKey),
        ],
      ),
    );
  }
}

class _MinutesRow extends ConsumerWidget {
  const _MinutesRow();

  static const _minutes = [10, 20, 30, 45];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(
      onboardingDraftProvider.select((d) => d.dailyMinutes),
    );
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Row(
      children: [
        for (final (index, minutes) in _minutes.indexed) ...[
          if (index > 0) const SizedBox(width: AppSpace.s2),
          Expanded(
            child: _Choice(
              label: '$minutes 分鐘',
              selected: selected == minutes,
              compact: true,
              onTap: () => notifier.setDailyMinutes(minutes),
            ),
          ),
        ],
      ],
    );
  }
}

class _WeekdayChoices extends ConsumerWidget {
  const _WeekdayChoices();

  static const _weekdays = [
    (1, '一'),
    (2, '二'),
    (3, '三'),
    (4, '四'),
    (5, '五'),
    (6, '六'),
    (7, '日'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(onboardingDraftProvider.select((d) => d.weekdays));
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [
            for (final (day, label) in _weekdays)
              _Choice(
                label: '週$label',
                selected: days.contains(day),
                onTap: () => notifier.toggleWeekday(day),
              ),
          ],
        ),
        if (days.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.s2),
            child: AppText(
              '至少選一天',
              scale: TypeScale.caption,
              color: AppTokens.of(context).kincha,
            ),
          ),
      ],
    );
  }
}

/// 精簡的單選／複選格：`ChoiceTile` 會撐滿整行，這裡要像稿紙格一樣排開。
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 等分欄位內用：窄螢幕與大字級時縮小，不在「分鐘」中間換行。
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      selected: selected,
      builder: (context, state) => Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? AppSpace.s1 : AppSpace.s3,
          vertical: AppSpace.s2,
        ),
        decoration: BoxDecoration(
          color: selected
              ? t.ink.primary
              : (state.hovered ? t.paper.raised : t.paper.base),
          borderRadius: AppRadii.r1,
          border: Border.all(color: selected ? t.ink.primary : t.line.strong),
        ),
        // widthFactor／heightFactor：在 Wrap 裡仍依文字寬，只把文字垂直置中
        child: compact
            ? Center(
                child: FittedBox(fit: BoxFit.scaleDown, child: _label(t)),
              )
            : Align(widthFactor: 1, heightFactor: 1, child: _label(t)),
      ),
    );
  }

  Widget _label(AppTokens t) => AppText(
    label,
    scale: TypeScale.label,
    textAlign: TextAlign.center,
    color: selected ? t.paper.base : t.ink.primary,
  );
}

class _TargetChoices extends StatefulWidget {
  const _TargetChoices({
    required this.targets,
    required this.selected,
    required this.onSelect,
  });

  final List<(int, String)> targets;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<_TargetChoices> createState() => _TargetChoicesState();
}

class _TargetChoicesState extends State<_TargetChoices> {
  int _months = 0;

  void _choose(int months) {
    setState(() => _months = months);
    widget.onSelect(months == 0 ? null : targetDateAfterMonths(months));
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s2,
    children: [
      for (final (months, label) in widget.targets)
        _Choice(
          label: label,
          selected: _months == months,
          onTap: () => _choose(months),
        ),
    ],
  );
}

/// 粗估完成日；算不出來時不擋下一步，提供重試。
class _Estimate extends ConsumerWidget {
  const _Estimate({required this.previewKey});

  final PlanPreviewKey previewKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final preview = ref.watch(_planPreviewProvider(previewKey));
    final stage = ref.watch(_contentStageProvider).value;
    return preview.when(
      loading: () =>
          AppText('正在估算…', scale: TypeScale.caption, color: t.ink.secondary),
      error: (_, _) => Row(
        children: [
          Expanded(
            child: AppText(
              '粗估暫時算不出來，不影響開始。',
              scale: TypeScale.caption,
              color: t.ink.secondary,
            ),
          ),
          GhostButton(
            label: '重試',
            onPressed: () => ref.invalidate(_planPreviewProvider(previewKey)),
          ),
        ],
      ),
      data: (plan) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in estimateLines(plan, stage))
            AppText(line, color: t.ink.secondary),
        ],
      ),
    );
  }
}
