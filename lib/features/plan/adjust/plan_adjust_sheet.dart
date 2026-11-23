import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/failures.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../plan_providers.dart';
import '../scope_copy.dart';
import 'plan_adjust_fields.dart';
import 'plan_draft.dart';
import 'plan_preview_block.dart';

/// 調整計畫（§3.8 第 4 點）：套用前顯示影響，只影響之後的安排。
class PlanAdjustSheet extends ConsumerStatefulWidget {
  const PlanAdjustSheet({
    required this.current,
    required this.stage,
    super.key,
  });

  final PlanViewDto current;
  final ContentStage stage;

  @override
  ConsumerState<PlanAdjustSheet> createState() => _PlanAdjustSheetState();
}

class _PlanAdjustSheetState extends ConsumerState<PlanAdjustSheet> {
  late PlanDraft _draft = PlanDraft.of(widget.current.input);
  late PlanInputDto _input = widget.current.input;
  bool _submitting = false;
  String? _error;

  PlanInputDto get _base => widget.current.input;

  void _update(PlanDraft next) => setState(() {
    _draft = next;
    _input = next.toInput(_base);
    _error = null;
  });

  Future<void> _apply() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await applyPlanInput(ref, _input);
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = failure.userMessage;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).maybePop();
  }

  bool get _canApply => _draft.isValid && !_draft.sameAs(_base) && !_submitting;

  DateTime _today(int rolloverHour) =>
      DateTime.parse(logicalDateOf(DateTime.now(), rolloverHour));

  Widget _weekdayField(AppTokens t) => _Field(
    label: '學習日',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WeekdayPicker(
          selected: _draft.weekdays,
          onToggle: (d) => _update(_draft.toggledDay(d)),
        ),
        if (!_draft.isValid) ...[
          const SizedBox(height: AppSpace.s2),
          Semantics(
            liveRegion: true,
            child: AppText('至少要選一天', scale: TypeScale.caption, color: t.shu),
          ),
        ],
      ],
    ),
  );

  Widget _footer(AppTokens t) {
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (error != null) ...[
          Semantics(liveRegion: true, child: AppText(error, color: t.shu)),
          const SizedBox(height: AppSpace.s3),
        ],
        InkButton(
          label: '套用',
          expanded: true,
          onPressed: _canApply ? () => unawaited(_apply()) : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final rollover = ref.watch(
      settingsProvider.select((s) => s.value?.dayRolloverHour ?? 4),
    );
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('調整計畫', scale: TypeScale.title),
          AppText(
            '只影響之後的安排，不會重置進度',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
          const SizedBox(height: AppSpace.s5),
          _Field(
            label: '每天多久',
            child: MinutesPicker(
              selected: _draft.minutes,
              onChanged: (m) => _update(_draft.withMinutes(m)),
            ),
          ),
          _weekdayField(t),
          _Field(
            label: '目標日期（選填）',
            child: TargetDateField(
              target: _draft.targetDate,
              today: _today(rollover),
              onChanged: (v) => _update(_draft.withTarget(v)),
            ),
          ),
          if (_draft.isValid)
            _Field(
              label: '套用後的影響',
              child: PlanPreviewBlock(
                input: _input,
                current: widget.current,
                stage: widget.stage,
                onUseSuggested: (m) => _update(_draft.withMinutes(m)),
              ),
            ),
          _footer(t),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: EyebrowText(label)),
        const SizedBox(height: AppSpace.s2),
        child,
      ],
    ),
  );
}
