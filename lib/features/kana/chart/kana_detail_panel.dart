import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/text/ja_text.dart';
import '../../../core/text/mixed_text.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/error_slip.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/kana_cell.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/skeleton_lines.dart';
import '../../../design/widgets/speak_button.dart';
import '../../../design/widgets/speed_toggle.dart';
import 'kana_chart_providers.dart';

const _memberCellSide = 56.0;
const _stripMaxHeightRatio = 0.3;

/// 窄螢幕的底部詳情條：內容在條內捲動，操作固定在下緣。
class KanaBottomStrip extends StatelessWidget {
  const KanaBottomStrip({
    required this.content,
    required this.actions,
    super.key,
  });

  final Widget content, actions;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * _stripMaxHeightRatio;
    return Container(
      width: double.infinity,
      decoration: t.raised(),
      padding: const EdgeInsets.all(AppSpace.s4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(child: content),
          ),
          actions,
        ],
      ),
    );
  }
}

/// 詳情條內容（窄螢幕底部、寬螢幕右欄共用）。沒有選字時是提示。
class KanaDetailPanel extends ConsumerWidget {
  const KanaDetailPanel({
    required this.cell,
    required this.onSelectCell,
    super.key,
  });

  final KanaCellDto? cell;
  final ValueChanged<KanaCellDto> onSelectCell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = cell;
    if (current == null) return const _Prompt();
    final provider = kanaDetailProvider(current.id);
    final detail = ref.watch(provider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CellHeader(cell: current),
        const SizedBox(height: AppSpace.s3),
        detail.when(
          data: (value) =>
              _DetailBody(detail: value, onSelectCell: onSelectCell),
          loading: () => const DelayedReveal(child: SkeletonLines(lines: 2)),
          error: (error, _) => ErrorSlip.fromObject(
            error,
            onRetry: () => ref.invalidate(provider),
          ),
        ),
      ],
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt();

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return AppText(
      '點任一格，可以聽發音、看字源和例字。',
      color: t.ink.secondary,
      scale: TypeScale.caption,
    );
  }
}

class _CellHeader extends StatelessWidget {
  const _CellHeader({required this.cell});

  final KanaCellDto cell;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final request = SpeechRequest.fromDto(cell.id, cell.speech);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Wrap(
                spacing: AppSpace.s3,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  JaText(cell.ch, scale: TypeScale.jaHero, height: 1.1),
                  AppText(
                    cell.romaji,
                    scale: TypeScale.title,
                    color: t.ink.secondary,
                  ),
                ],
              ),
            ),
            if (!cell.listenDisabled) ...[
              SpeakButton(request: request),
              const SizedBox(width: AppSpace.s2),
              const SpeedToggle(),
            ],
          ],
        ),
        if (cell.listenDisabled) ...[
          const SizedBox(height: AppSpace.s1),
          AppText('單獨唸不準，看例字', color: t.ink.secondary),
        ],
      ],
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.detail, required this.onSelectCell});

  final KanaDetailDto detail;
  final ValueChanged<KanaCellDto> onSelectCell;

  @override
  Widget build(BuildContext context) {
    final origin = detail.originKanji;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (origin != null) ...[
          _OriginRow(origin: origin),
          const SizedBox(height: AppSpace.s2),
        ],
        MixedText(detail.hintZh),
        if (detail.exampleWords.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s3),
          RuledList(
            children: [
              for (final (index, example) in detail.exampleWords.indexed)
                _ExampleTile(
                  example: example,
                  speechId: '${detail.cell.id}.ex$index',
                ),
            ],
          ),
        ],
        if (detail.confusables.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s4),
          _ConfusableSection(
            groups: detail.confusables,
            currentId: detail.cell.id,
            onSelectCell: onSelectCell,
          ),
        ],
      ],
    );
  }
}

class _OriginRow extends StatelessWidget {
  const _OriginRow({required this.origin});

  final String origin;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Row(
      children: [
        AppText('來自漢字：', scale: TypeScale.caption, color: t.ink.secondary),
        JaText(origin, color: t.ink.secondary),
      ],
    );
  }
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({required this.example, required this.speechId});

  final KanaExampleDto example;
  final String speechId;

  @override
  Widget build(BuildContext context) => RuledTile(
    title: JaText(example.surface),
    subtitle: AppText(
      example.zh,
      scale: TypeScale.caption,
      color: AppTokens.of(context).ink.secondary,
    ),
    trailing: SpeakButton(
      request: SpeechRequest.fromDto(speechId, example.speech),
    ),
  );
}

class _ConfusableSection extends StatelessWidget {
  const _ConfusableSection({
    required this.groups,
    required this.currentId,
    required this.onSelectCell,
  });

  final List<ConfusableDto> groups;
  final String currentId;
  final ValueChanged<KanaCellDto> onSelectCell;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      const EyebrowText('容易混淆'),
      const SizedBox(height: AppSpace.s2),
      for (final group in groups)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s3),
          child: _ConfusableGroup(
            group: group,
            currentId: currentId,
            onSelectCell: onSelectCell,
          ),
        ),
    ],
  );
}

class _ConfusableGroup extends StatelessWidget {
  const _ConfusableGroup({
    required this.group,
    required this.currentId,
    required this.onSelectCell,
  });

  final ConfusableDto group;
  final String currentId;
  final ValueChanged<KanaCellDto> onSelectCell;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Wrap(
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s2,
        children: [
          for (final member in group.members)
            SizedBox.square(
              dimension: _memberCellSide,
              child: KanaCell(
                kana: member.ch,
                romaji: member.romaji,
                status: member.status,
                selected: member.id == currentId,
                onTap: () => onSelectCell(member),
              ),
            ),
          for (final literal in group.literals)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JaText(literal.text, scale: TypeScale.jaSentence),
                AppText(
                  literal.zh,
                  scale: TypeScale.caption,
                  color: AppTokens.of(context).ink.secondary,
                ),
              ],
            ),
        ],
      ),
      const SizedBox(height: AppSpace.s1),
      MixedText(group.diffZh),
    ],
  );
}

/// 詳情條下緣的操作：練習、規則卡；沒有選字且進度全空時給第一課入口。
class KanaPanelActions extends ConsumerWidget {
  const KanaPanelActions({required this.cell, this.startLessonId, super.key});

  final KanaCellDto? cell;
  final String? startLessonId;

  void _openLesson(BuildContext context, String lessonId) =>
      unawaited(context.push<void>(AppRoutes.kanaSession(lessonId)));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = cell;
    final start = startLessonId;
    if (current == null) {
      if (start == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: AppSpace.s3),
        child: InkButton(
          label: '從第一課開始',
          expanded: true,
          onPressed: () => _openLesson(context, start),
        ),
      );
    }
    final detail = ref.watch(kanaDetailProvider(current.id)).value;
    if (detail == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s3),
      child: Wrap(
        spacing: AppSpace.s3,
        runSpacing: AppSpace.s2,
        children: [
          InkButton(
            label: '練習這一課',
            onPressed: () => _openLesson(context, detail.lessonId),
          ),
          if (detail.ruleId case final ruleId?)
            GhostButton(
              label: '看規則卡',
              onPressed: () =>
                  unawaited(context.push<void>(AppRoutes.kanaRule(ruleId))),
            ),
        ],
      ),
    );
  }
}
