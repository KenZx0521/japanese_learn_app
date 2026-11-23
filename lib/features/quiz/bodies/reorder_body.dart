import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/answer_line.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../../../design/widgets/word_tile.dart';
import '../model/quiz_run_state.dart';
import '../model/reorder_draft.dart';

/// 排序題（§3.6）。`audio_first` 時先只有播放鈕，播過一次才按「開始拼句」。
class ReorderBody extends StatefulWidget {
  const ReorderBody({
    required this.body,
    required this.phase,
    required this.audioFirst,
    required this.promptPlayed,
    required this.onAnswer,
    super.key,
  });

  final QuestionBodyDto_Reorder body;
  final QuizPhase phase;
  final bool audioFirst;
  final bool promptPlayed;
  final ValueChanged<AnswerPayload> onAnswer;

  @override
  State<ReorderBody> createState() => _ReorderBodyState();
}

class _ReorderBodyState extends State<ReorderBody> {
  ReorderDraft _draft = const ReorderDraft();
  late bool _started = !widget.audioFirst;

  bool get _editable => widget.phase is QuizAnswering;

  List<ChunkDto> get _chunks => widget.body.chunks;

  String _textOf(int chunkIndex) =>
      _chunks.firstWhere((chunk) => chunk.index == chunkIndex).text;

  void _toggle(int chunkIndex) =>
      setState(() => _draft = _draft.toggle(chunkIndex));

  void _submit() => widget.onAnswer(
    AnswerPayload.reorder(order: Uint32List.fromList(_draft.placed)),
  );

  @override
  Widget build(BuildContext context) {
    if (!_started) {
      return _StartGate(
        played: widget.promptPlayed,
        onStart: () => setState(() => _started = true),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnswerLine(
          children: [
            for (final index in _draft.placed)
              IntrinsicWidth(
                child: WordTile(
                  text: _textOf(index),
                  placed: true,
                  onTap: _editable ? () => _toggle(index) : null,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s4),
        Wrap(
          spacing: AppSpace.s2,
          runSpacing: AppSpace.s2,
          children: [for (final chunk in _chunks) _bankTile(chunk)],
        ),
        if (_editable) ...[
          const SizedBox(height: AppSpace.s4),
          InkButton(
            label: '確認',
            expanded: true,
            onPressed: _draft.isComplete(_chunks.length) ? _submit : null,
          ),
        ],
      ],
    );
  }

  /// 放上去的詞塊留下同尺寸的空位，其他詞塊不跳動。
  Widget _bankTile(ChunkDto chunk) {
    final placed = _draft.isPlaced(chunk.index);
    final tile = WordTile(
      text: chunk.text,
      placed: false,
      onTap: placed || !_editable ? null : () => _toggle(chunk.index),
    );
    // `WordTile` 的 Container 會撐滿，Wrap 裡要收成文字寬
    return IntrinsicWidth(
      child: Visibility(
        visible: !placed,
        maintainSize: true,
        maintainAnimation: true,
        maintainState: true,
        child: tile,
      ),
    );
  }
}

class _StartGate extends StatelessWidget {
  const _StartGate({required this.played, required this.onStart});
  final bool played;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(
        played ? '聽好了就開始拼句。' : '先聽一次，再開始拼句。',
        color: AppTokens.of(context).ink.secondary,
      ),
      const SizedBox(height: AppSpace.s3),
      InkButton(label: '開始拼句', onPressed: played ? onStart : null),
    ],
  );
}
