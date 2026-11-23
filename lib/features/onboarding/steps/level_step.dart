import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/mixed_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/async_body.dart';
import '../../../design/widgets/choice_tile.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../onboarding_draft.dart';
import '../onboarding_frame.dart';

final _kanaLessonsProvider = FutureProvider.autoDispose<List<LessonSummaryDto>>(
  (ref) async {
    final overview = await ref.watch(courseRepositoryProvider).overview();
    return overview.lessons.where((l) => isSkippableKanaLesson(l.id)).toList();
  },
);

/// K10、K16–K19 沒有新字，不列入（§3.1 O3）。
bool isSkippableKanaLesson(String lessonId) {
  final match = RegExp(r'^le\.k(\d+)$').firstMatch(lessonId);
  if (match == null) return false;
  final number = int.parse(match.group(1)!);
  return (number >= 1 && number <= 9) || (number >= 11 && number <= 15);
}

/// O3 程度（§3.1）。
class LevelStep extends ConsumerWidget {
  const LevelStep({super.key});

  static const _options = [
    (LevelChoice.none, '完全沒學過'),
    (LevelChoice.some, '會一點假名'),
    (LevelChoice.hiragana, '平假名都會'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(onboardingDraftProvider);
    final notifier = ref.read(onboardingDraftProvider.notifier);
    final toPlacement = draft.level == LevelChoice.hiragana;
    return OnboardingFrame(
      step: 2,
      title: '你學過日文嗎？',
      bottom: InkButton(
        label: toPlacement ? '去考一次' : '下一步',
        expanded: true,
        onPressed: () => unawaited(
          context.push(
            toPlacement ? AppRoutes.placement : AppRoutes.welcomeStep('o4'),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (level, label) in _options)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s2),
              child: ChoiceTile(
                state: draft.level == level
                    ? ChoiceTileState.selected
                    : ChoiceTileState.idle,
                onTap: () => notifier.setLevel(level),
                child: AppText(label),
              ),
            ),
          if (draft.level == LevelChoice.some) ...[
            const SizedBox(height: AppSpace.s3),
            const _KanaLessonPicker(),
          ],
        ],
      ),
    );
  }
}

class _KanaLessonPicker extends ConsumerWidget {
  const _KanaLessonPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final known = ref.watch(
      onboardingDraftProvider.select((d) => d.knownLessons),
    );
    final notifier = ref.read(onboardingDraftProvider.notifier);
    return AsyncBody(
      value: ref.watch(_kanaLessonsProvider),
      onRetry: () => ref.invalidate(_kanaLessonsProvider),
      data: (lessons) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            '勾選已經會的行，這些課會略過。',
            scale: TypeScale.caption,
            color: AppTokens.of(context).ink.secondary,
          ),
          const SizedBox(height: AppSpace.s2),
          for (final lesson in lessons)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s1),
              child: ChoiceTile(
                state: known.contains(lesson.id)
                    ? ChoiceTileState.selected
                    : ChoiceTileState.idle,
                onTap: () => notifier.toggleKnownLesson(lesson.id),
                child: MixedText(lesson.titleZh),
              ),
            ),
        ],
      ),
    );
  }
}
