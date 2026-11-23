import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/text/ja_text.dart';
import '../../core/text/mixed_text.dart';
import '../../core/tts/autoplay.dart';
import '../../core/tts/tts_engine.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';
import 'ruled_list.dart';
import 'speak_button.dart';
import 'speed_toggle.dart';

/// 新內容的假名呈現（§3.10）：大字、自動播一次、romaji、字源、例字。
class KanaTeachCard extends StatelessWidget {
  const KanaTeachCard({required this.detail, this.onNext, super.key});

  final KanaDetailDto detail;
  final VoidCallback? onNext;

  SpeechRequest get _request =>
      SpeechRequest.fromDto(detail.cell.id, detail.cell.speech);

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final listenDisabled = detail.cell.listenDisabled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AutoplayOnce(request: _request, enabled: !listenDisabled),
        JaText(detail.cell.ch, scale: TypeScale.jaHero),
        AppText(
          detail.cell.romaji,
          scale: TypeScale.title,
          color: t.ink.secondary,
        ),
        const SizedBox(height: AppSpace.s3),
        if (!listenDisabled)
          Row(
            children: [
              SpeakButton(request: _request),
              const SizedBox(width: AppSpace.s2),
              const SpeedToggle(),
            ],
          )
        else
          AppText('單獨唸不準，看例字', color: t.ink.secondary),
        if (detail.originKanji != null) ...[
          const SizedBox(height: AppSpace.s3),
          Row(
            children: [
              AppText(
                '來自漢字：',
                scale: TypeScale.caption,
                color: t.ink.secondary,
              ),
              JaText(detail.originKanji!, color: t.ink.secondary),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s3),
        MixedText(detail.hintZh),
        if (detail.exampleWords.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s4),
          _examples(),
        ],
        const SizedBox(height: AppSpace.s5),
        InkButton(label: '下一步', onPressed: onNext, autofocus: true),
      ],
    );
  }

  Widget _examples() => RuledList(
    children: [
      for (final (index, example) in detail.exampleWords.indexed)
        _ExampleRow(example: example, speechId: '${detail.cell.id}.ex$index'),
    ],
  );
}

class _ExampleRow extends StatelessWidget {
  const _ExampleRow({required this.example, required this.speechId});
  final KanaExampleDto example;
  final String speechId;

  @override
  Widget build(BuildContext context) => RuledTile(
    title: JaText(example.surface, scale: TypeScale.jaBody),
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
