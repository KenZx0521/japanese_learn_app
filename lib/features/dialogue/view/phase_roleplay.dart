import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/pressable.dart';
import '../../../design/widgets/ruled_list.dart';
import '../../../design/widgets/speak_button.dart';
import '../../../design/widgets/speed_toggle.dart';
import '../../../design/widgets/voice_failed_panel.dart';
import '../dialogue_speech.dart';
import 'silent_mode.dart';
import 'turn_view.dart';

/// 第四階段：選角色，對方由 TTS 發聲，輪到自己時留空檔（§3.7）。
/// 無聲模式對方台詞以文字呈現，由使用者自己按下一句。
class RoleplayPhase extends ConsumerStatefulWidget {
  const RoleplayPhase({
    required this.dialogue,
    required this.policy,
    required this.audio,
    required this.onDone,
    super.key,
  });

  final DialogueDto dialogue;
  final DisplayPolicyDto policy;
  final bool audio;
  final VoidCallback onDone;

  @override
  ConsumerState<RoleplayPhase> createState() => _RoleplayPhaseState();
}

class _RoleplayPhaseState extends ConsumerState<RoleplayPhase> {
  static const _minGapMs = 1500;
  static const _msPerCharacter = 220;
  static const _gapRatio = 1.5;

  String? _role;
  int _index = 0;
  bool _hideMine = false;
  bool _finished = false;
  bool _failed = false;

  /// 播放中被 App 進背景打斷，回前景要補播當句。
  bool _interrupted = false;
  Timer? _gapTimer;
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onShow: _replayIfInterrupted,
  );

  DialogueDto get _d => widget.dialogue;
  bool get _isMine => _d.turns[_index].role == _role;
  String get _speechId => turnSpeechId(_d, _index);

  @override
  void initState() {
    super.initState();
    _lifecycle;
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _gapTimer?.cancel();
    super.dispose();
  }

  void _choose(String role) {
    setState(() => _role = role);
    _enterTurnAfterFrame();
  }

  void _enterTurnAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_enterTurn());
    });
  }

  Future<void> _enterTurn() async {
    _gapTimer?.cancel();
    if (_failed) setState(() => _failed = false);
    if (!widget.audio || _finished) return;
    if (_isMine) {
      _gapTimer = Timer(_gapFor(_index), _advance);
      return;
    }
    await _playTurn();
  }

  /// `stop` 同步把狀態轉回 Idle，分不出播完或被打斷，所以看回傳值。
  Future<void> _playTurn() async {
    final turn = _index;
    final tts = ref.read(ttsControllerProvider.notifier);
    final request = tts.atUserSpeed(turnRequest(_d, _index));
    final finished = await tts.playSequence([request], fixedGap(Duration.zero));
    if (!mounted || turn != _index || _finished) return;
    if (finished) {
      _advance();
    } else {
      _interrupted = ref.read(ttsControllerProvider) is! TtsError;
    }
  }

  void _replayIfInterrupted() {
    if (!mounted || !_interrupted || _failed) return;
    _interrupted = false;
    unawaited(_playTurn());
  }

  /// 自己的台詞沒有實測時長，依字數估，再乘跟讀的 1.5 倍（課綱 §10.1）。
  Duration _gapFor(int index) {
    final characters = _d.turns[index].sentence.display.characters.length;
    final spoken = characters * _msPerCharacter;
    return Duration(
      milliseconds: math.max(_minGapMs, (spoken * _gapRatio).round()),
    );
  }

  void _onPlayback(TtsPlayback? previous, TtsPlayback next) {
    if (_role == null || _finished || _isMine) return;
    if (next is TtsError && next.id == _speechId) {
      setState(() => _failed = true);
    }
  }

  void _advance() {
    _gapTimer?.cancel();
    _interrupted = false;
    if (!mounted) return;
    if (_index + 1 >= _d.turns.length) {
      setState(() => _finished = true);
      return;
    }
    setState(() => _index++);
    _enterTurnAfterFrame();
  }

  /// 先換句再停：等播放的那一輪看到句數已變，不會連跳兩句。
  void _skip() {
    _advance();
    unawaited(ref.read(ttsControllerProvider.notifier).stop());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TtsPlayback>(ttsControllerProvider, _onPlayback);
    if (_finished) return _finishedView();
    if (_role == null) return _rolePicker(context);
    return _turnView(context);
  }

  Widget _finishedView() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('角色扮演完成。'),
      const SizedBox(height: AppSpace.s4),
      InkButton(label: '完成這段', onPressed: widget.onDone),
    ],
  );

  Widget _rolePicker(BuildContext context) => SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppText('選一個角色，輪到你時開口說。'),
        const SizedBox(height: AppSpace.s3),
        RuledList(
          children: [
            for (final role in _d.roles)
              RuledTile.text(role.nameZh, onTap: () => _choose(role.id)),
          ],
        ),
      ],
    ),
  );

  Widget _turnView(BuildContext context) {
    final t = AppTokens.of(context);
    final mine = _isMine;
    final showText = mine ? !_hideMine : !widget.audio;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            '第 ${_index + 1}／${_d.turns.length} 句',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
          const SizedBox(height: AppSpace.s3),
          TurnView(
            dialogue: _d,
            index: _index,
            policy: widget.policy,
            showJapanese: showText,
            showChinese: showText,
            showNote: false,
            trailing: widget.audio && !mine
                ? SpeakButton(request: turnRequest(_d, _index))
                : null,
          ),
          const SizedBox(height: AppSpace.s3),
          if (_failed)
            VoiceFailedPanel(
              onRetry: () => unawaited(_enterTurn()),
              onSilent: () => unawaited(useSilentMode(ref)),
            )
          else
            AppText(
              mine ? '換你說。' : (widget.audio ? '先聽對方說。' : '對方的台詞。'),
              color: mine ? t.shu : t.ink.secondary,
            ),
          const SizedBox(height: AppSpace.s4),
          _actions(),
        ],
      ),
    );
  }

  Widget _actions() => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s2,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      InkButton(label: '下一句', onPressed: _skip),
      if (widget.audio) const SpeedToggle(),
      _HideMineToggle(
        hidden: _hideMine,
        onTap: () => setState(() => _hideMine = !_hideMine),
      ),
    ],
  );
}

class _HideMineToggle extends StatelessWidget {
  const _HideMineToggle({required this.hidden, required this.onTap});
  final bool hidden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      toggled: hidden,
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s2),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: hidden ? t.shu : t.line.strong),
          ),
        ),
        child: AppText(
          hidden ? '顯示我的台詞' : '隱藏我的台詞',
          scale: TypeScale.label,
          color: hidden ? t.shu : t.ink.secondary,
        ),
      ),
    );
  }
}
