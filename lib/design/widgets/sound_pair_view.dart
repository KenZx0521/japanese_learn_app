import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'speak_button.dart';

/// A/B 語音示範（§3.7 S2、§3.3 K3 共用）。`listen_disabled` 時只顯示文字。
class SoundPairView extends StatelessWidget {
  const SoundPairView({required this.pair, required this.pairId, super.key});

  final SoundPairDto pair;
  final String pairId;

  /// 內容寬足以讓字和播放鈕同排時改橫排，避免大框內只有左上角有東西。
  static const _wideMinWidth = 520.0;

  Widget _side(SoundSideDto side, String key, {required bool wide}) => _Side(
    side: side,
    speechId: '$pairId.$key',
    listenDisabled: pair.listenDisabled,
    horizontal: wide,
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= _wideMinWidth;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _side(pair.a, 'a', wide: wide)),
          const SizedBox(width: AppSpace.s3),
          Expanded(child: _side(pair.b, 'b', wide: wide)),
        ],
      );
    },
  );
}

class _Side extends StatelessWidget {
  const _Side({
    required this.side,
    required this.speechId,
    required this.listenDisabled,
    required this.horizontal,
  });

  final SoundSideDto side;
  final String speechId;
  final bool listenDisabled, horizontal;

  Widget _texts(AppTokens t) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      JaText(side.text, scale: TypeScale.jaSentence),
      if (side.kana != null) JaText(side.kana!, color: t.ink.secondary),
      AppText(side.zh, scale: TypeScale.caption, color: t.ink.secondary),
    ],
  );

  Widget get _speak =>
      SpeakButton(request: SpeechRequest.fromDto(speechId, side.speech));

  Widget _body(AppTokens t) {
    if (horizontal && !listenDisabled) {
      return Row(
        children: [
          Expanded(child: _texts(t)),
          const SizedBox(width: AppSpace.s2),
          _speak,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _texts(t),
        if (!listenDisabled) ...[const SizedBox(height: AppSpace.s2), _speak],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpace.s3),
      decoration: BoxDecoration(
        border: Border.all(color: t.line.strong),
        borderRadius: AppRadii.r1,
      ),
      child: _body(t),
    );
  }
}
