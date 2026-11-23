import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/tts/audio_available.dart';
import '../../../core/tts/tts_controller.dart';
import '../../../core/tts/tts_engine.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/speak_button.dart';
import '../model/feedback_plan.dart';

/// 答後並排比較（§3.3 `MinimalPair`）：各播一次。
class AnswerCompare extends ConsumerStatefulWidget {
  const AnswerCompare({
    required this.sides,
    required this.speechScope,
    super.key,
  });

  final List<CompareSide> sides;
  final String speechScope;

  @override
  ConsumerState<AnswerCompare> createState() => _AnswerCompareState();
}

class _AnswerCompareState extends ConsumerState<AnswerCompare> {
  static const _gap = Duration(milliseconds: 400);
  static const _sideBySideWidth = 480.0;

  bool _autoplayChecked = false;

  SpeechRequest _requestOf(int index) => SpeechRequest.fromDto(
    '${widget.speechScope}/compare$index',
    widget.sides[index].speech,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_autoplayChecked) return;
    _autoplayChecked = true;
    // 條件與 `AutoplayOnce` 相同，只是要連播
    final allowed =
        ref.read(audioAvailableProvider) &&
        (ref.read(settingsProvider).value?.autoplay ?? false) &&
        !MediaQuery.accessibleNavigationOf(context);
    if (allowed) WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  void _play() {
    if (!mounted) return;
    final tts = ref.read(ttsControllerProvider.notifier);
    final requests = [
      for (var i = 0; i < widget.sides.length; i++)
        tts.atUserSpeed(_requestOf(i)),
    ];
    unawaited(tts.playSequence(requests, fixedGap(_gap)));
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final cells = [
        for (var i = 0; i < widget.sides.length; i++)
          _CompareCell(side: widget.sides[i], request: _requestOf(i)),
      ];
      if (constraints.maxWidth < _sideBySideWidth) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: cells,
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final cell in cells) Expanded(child: cell)],
      );
    },
  );
}

class _CompareCell extends StatelessWidget {
  const _CompareCell({required this.side, required this.request});

  final CompareSide side;
  final SpeechRequest request;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Row(
      children: [
        SpeakButton(request: request),
        const SizedBox(width: AppSpace.s2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(
                side.label,
                scale: TypeScale.label,
                color: AppTokens.of(context).ink.secondary,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
