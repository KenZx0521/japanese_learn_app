import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/backend/failures.dart';
import '../../../core/backend/local_log.dart';
import '../../../core/backend/providers.dart';
import '../../../core/settings/settings_controller.dart';
import '../../../core/text/ja_text.dart';
import '../../../core/tts/audio_available.dart';
import '../../../core/tts/autoplay.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../core/tts/voice_help.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/error_slip.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/skeleton_lines.dart';
import '../../../design/widgets/speak_button.dart';
import '../first_lesson_starter.dart';
import '../onboarding_draft.dart';
import '../onboarding_frame.dart';

const _helloId = 'onboarding.hello';
const _hello = SpeechRequest(id: _helloId, text: 'こんにちは', kana: 'こんにちは');

/// O5 語音檢查（§3.1）：失敗時停在本步，必須明確選一個出口。
class VoiceStep extends ConsumerStatefulWidget {
  const VoiceStep({super.key});

  @override
  ConsumerState<VoiceStep> createState() => _VoiceStepState();
}

class _VoiceStepState extends ConsumerState<VoiceStep> {
  final _starter = FirstLessonStarter();
  bool _heard = false;
  bool _cantHear = false;
  bool _starting = false;
  int _playRound = 0;
  AppFailure? _failure;

  /// 上一輪的 `TtsError` 是全域狀態，不清掉就永遠回不到試聽。
  void _replay() {
    unawaited(ref.read(ttsControllerProvider.notifier).stop());
    setState(() {
      _cantHear = false;
      _heard = false;
      _playRound++;
    });
  }

  /// 現在設定：開 `VoiceHelpSheet`，回到本頁時重新探測（§3.1）。
  Future<void> _openSetup() async {
    await showVoiceHelpSheet(context, onReady: _replay);
    if (!mounted) return;
    await ref.read(ttsAvailabilityProvider.notifier).reprobe();
    if (!mounted) return;
    if (ref.read(ttsAvailabilityProvider).isReady) _replay();
  }

  Future<void> _chooseSilent() async {
    setState(() => _failure = null);
    try {
      await ref
          .read(settingsProvider.notifier)
          .patch(settingsPatch(silentMode: true));
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) setState(() => _failure = failure);
    }
  }

  Future<void> _begin() async {
    setState(() {
      _starting = true;
      _failure = null;
    });
    try {
      final key = await _starter.start(ref);
      if (!mounted) return;
      ref.read(onboardingDoneProvider).value = true;
      ref.invalidate(onboardingDraftProvider);
      context.go(
        key == null ? AppRoutes.today : AppRoutes.sessionToday(start: key),
      );
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) {
        setState(() {
          _failure = failure;
          _starting = false;
        });
      }
    }
  }

  bool _playbackFailed(TtsPlayback playback) =>
      playback is TtsError && playback.id == _helloId;

  @override
  Widget build(BuildContext context) {
    final tts = ref.watch(ttsAvailabilityProvider);
    final silent = ref.watch(
      settingsProvider.select((s) => s.value?.silentMode ?? false),
    );
    final failed = ref.watch(ttsControllerProvider.select(_playbackFailed));
    final canBegin = silent || (_heard && tts.isReady);
    return OnboardingFrame(
      step: 4,
      title: '聽得到聲音嗎？',
      bottom: canBegin
          ? InkButton(
              label: '開始第一課',
              expanded: true,
              autofocus: true,
              onPressed: _starting ? null : () => unawaited(_begin()),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panel(tts, silent, failed),
          if (_failure != null) ...[
            const SizedBox(height: AppSpace.s3),
            ErrorSlip(failure: _failure!, onRetry: () => unawaited(_begin())),
          ],
        ],
      ),
    );
  }

  Widget _panel(TtsAvailability tts, bool silent, bool failed) {
    if (silent) return const _SilentChosen();
    if (tts.kind == TtsAvailabilityKind.unknown) return const _Probing();
    if (!tts.isReady || _cantHear || failed) {
      return _VoiceProblem(
        onSetup: () => unawaited(_openSetup()),
        onSilent: () => unawaited(_chooseSilent()),
      );
    }
    if (_heard) return const AppText('很好，語音沒問題。');
    return _ListenTest(
      key: ValueKey(_playRound),
      onHeard: () => setState(() => _heard = true),
      onCantHear: () => setState(() => _cantHear = true),
    );
  }
}

class _Probing extends StatelessWidget {
  const _Probing();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(liveRegion: true, child: const AppText('正在確認語音')),
      const SizedBox(height: AppSpace.s3),
      const SkeletonLines(lines: 1),
    ],
  );
}

class _ListenTest extends StatelessWidget {
  const _ListenTest({
    required this.onHeard,
    required this.onCantHear,
    super.key,
  });

  final VoidCallback onHeard, onCantHear;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AutoplayOnce(request: _hello),
      Row(
        children: [
          const JaText('こんにちは', scale: TypeScale.jaSentence),
          const SizedBox(width: AppSpace.s3),
          const SpeakButton(request: _hello),
        ],
      ),
      const SizedBox(height: AppSpace.s5),
      InkButton(
        label: '聽得到',
        expanded: true,
        autofocus: true,
        onPressed: onHeard,
      ),
      const SizedBox(height: AppSpace.s2),
      GhostButton(label: '聽不到', expanded: true, onPressed: onCantHear),
    ],
  );
}

class _VoiceProblem extends StatelessWidget {
  const _VoiceProblem({required this.onSetup, required this.onSilent});

  final VoidCallback onSetup, onSilent;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(liveRegion: true, child: const AppText('現在聽不到日語語音。')),
      const SizedBox(height: AppSpace.s1),
      AppText(
        '假名要配聲音學。可以現在設定；也可以先用無聲模式，聽力題暫時不出現，之後隨時可以在設定開回來。',
        color: AppTokens.of(context).ink.secondary,
      ),
      const SizedBox(height: AppSpace.s4),
      InkButton(label: '現在設定', expanded: true, onPressed: onSetup),
      const SizedBox(height: AppSpace.s2),
      GhostButton(label: '先用無聲模式', expanded: true, onPressed: onSilent),
    ],
  );
}

class _SilentChosen extends StatelessWidget {
  const _SilentChosen();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('已改用無聲模式。'),
      const SizedBox(height: AppSpace.s1),
      AppText(
        '聽力題暫時不出現，之後隨時可以在設定開回來。',
        color: AppTokens.of(context).ink.secondary,
      ),
    ],
  );
}
