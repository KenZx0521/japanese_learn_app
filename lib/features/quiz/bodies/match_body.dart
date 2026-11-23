import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/text/ja_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/choice_tile.dart';
import '../model/match_board.dart';
import '../model/quiz_run_state.dart';

/// 配對題（§3.3）：左假名、右讀音，答對的對變淡；計時只在答後顯示。
class MatchBody extends StatefulWidget {
  const MatchBody({
    required this.body,
    required this.seedKey,
    required this.phase,
    required this.onAnswer,
    super.key,
  });

  final QuestionBodyDto_Match body;

  /// 同一題重開時右欄順序相同。
  final String seedKey;
  final QuizPhase phase;
  final ValueChanged<AnswerPayload> onAnswer;

  @override
  State<MatchBody> createState() => _MatchBodyState();
}

class _MatchBodyState extends State<MatchBody> {
  late MatchBoard _board = MatchBoard.start(
    widget.body.pairs,
    seed: sessionSeed(widget.seedKey),
  );

  bool get _editable => widget.phase is QuizAnswering;

  void _update(MatchBoard next) {
    setState(() => _board = next);
    if (next.isComplete) {
      widget.onAnswer(AnswerPayload.match(allCorrect: next.allCorrect));
    }
  }

  /// 一列一對左右格等高；兩欄分開排的話左右行高不同，會越往下越錯開。
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var row = 0; row < _board.pairs.length; row++) ...[
        if (row > 0) const SizedBox(height: AppSpace.s2),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _leftTile(row, _board.pairs[row])),
              const SizedBox(width: AppSpace.s3),
              Expanded(child: _rightTile(_board.rightOrder[row])),
            ],
          ),
        ),
      ],
    ],
  );

  Widget _leftTile(int index, MatchPairDto pair) {
    final matched = _board.isMatched(index);
    return ChoiceTile(
      state: matched
          ? ChoiceTileState.dimmed
          : index == _board.selectedLeft
          ? ChoiceTileState.selected
          : ChoiceTileState.idle,
      onTap: matched || !_editable
          ? null
          : () => _update(_board.tapLeft(index)),
      child: JaText(
        pair.left,
        scale: TypeScale.jaSentence,
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _rightTile(int index) {
    final matched = _board.isMatched(index);
    return ChoiceTile(
      state: matched
          ? ChoiceTileState.dimmed
          : index == _board.wrongRight
          ? ChoiceTileState.wrong
          : ChoiceTileState.idle,
      onTap: matched || !_editable
          ? null
          : () => _update(_board.tapRight(index)),
      child: AppText(
        _board.pairs[index].right,
        scale: TypeScale.title,
        textAlign: TextAlign.center,
      ),
    );
  }
}
