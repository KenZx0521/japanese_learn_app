import 'package:flutter/services.dart' show LengthLimitingTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/ja_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../model/quiz_run_state.dart';

/// 打字題（§3.6）：輸入羅馬字，上方即時顯示假名，不需要日文輸入法。
class TypingBody extends ConsumerStatefulWidget {
  const TypingBody({
    required this.body,
    required this.phase,
    required this.onAnswer,
    super.key,
  });

  final QuestionBodyDto_Typing body;
  final QuizPhase phase;
  final ValueChanged<AnswerPayload> onAnswer;

  @override
  ConsumerState<TypingBody> createState() => _TypingBodyState();
}

class _TypingBodyState extends ConsumerState<TypingBody> {
  static const _maxInputLength = 64;

  final TextEditingController _controller = TextEditingController();

  bool get _editable => widget.phase is QuizAnswering;

  bool get _canSubmit => _editable && _controller.text.trim().isNotEmpty;

  /// 送使用者打的原文，正規化由 Rust 處理（architecture §5.3）。
  void _submit() {
    if (_canSubmit) {
      widget.onAnswer(AnswerPayload.typing(input: _controller.text));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview = ref
        .watch(textToolsProvider)
        .romajiInputPreview(_controller.text);
    final canSubmit = _canSubmit;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 34),
          child: JaText(preview, scale: TypeScale.jaSentence),
        ),
        const SizedBox(height: AppSpace.s2),
        _field(),
        if (_editable) ...[
          const SizedBox(height: AppSpace.s4),
          InkButton(
            label: '確認',
            expanded: true,
            onPressed: canSubmit ? _submit : null,
          ),
        ],
      ],
    );
  }

  /// §3.6：`visiblePassword` 讓注音鍵盤的使用者直接得到 Latin 鍵盤。
  Widget _field() => TextField(
    controller: _controller,
    readOnly: !_editable,
    autofocus: !MediaQuery.accessibleNavigationOf(context),
    keyboardType: TextInputType.visiblePassword,
    autocorrect: false,
    enableSuggestions: false,
    enableIMEPersonalizedLearning: false,
    textCapitalization: TextCapitalization.none,
    textInputAction: TextInputAction.done,
    inputFormatters: [LengthLimitingTextInputFormatter(_maxInputLength)],
    decoration: InputDecoration(hintText: widget.body.placeholderZh),
    style: TypeScale.body.style(AppTokens.of(context).ink.primary),
    onChanged: (_) => setState(() {}),
    onSubmitted: (_) => _submit(),
  );
}
