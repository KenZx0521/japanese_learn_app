import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

/// 文字欄（扣掉右側按鈕後）放不下這麼多個字時，按鈕改放到文字下方。
const _minCharsBeside = 12;

const _dismissLabel = '知道了';
const _borderWidth = 3.0;

/// 題型首次操作提示（§3.12），不擋作答。窄寬或大字級時「知道了」
/// 移到文字下方，否則 320 寬＋2 倍字級時文字會被擠成一行約 5 個字。
class QuestionHintStrip extends StatelessWidget {
  const QuestionHintStrip({
    required this.hint,
    required this.onDismiss,
    super.key,
  });

  final String hint;
  final VoidCallback onDismiss;

  /// 依可用寬度與實際字級判斷；字級各自受該級的縮放上限限制。
  static bool _stacksBelow(BuildContext context, double maxWidth) {
    final em = TypeScale.body.scaler(context).scale(TypeScale.body.size);
    final label = TypeScale.label.scaler(context).scale(TypeScale.label.size);
    final button = label * _dismissLabel.length + 2 * AppSpace.s3;
    final beside = maxWidth - _borderWidth - AppSpace.s3 - button;
    return beside < em * _minCharsBeside;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final text = Semantics(
      liveRegion: true,
      child: AppText(hint, color: t.ink.secondary),
    );
    final button = _DismissButton(onDismiss: onDismiss);
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpace.s3, 0, 0, 0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: t.ai, width: _borderWidth),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) =>
            // constraints 已扣掉左側框線與內距，這裡補回去比較整條的寬度
            _stacksBelow(
              context,
              constraints.maxWidth + _borderWidth + AppSpace.s3,
            )
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  text,
                  // 按鈕的 Container 有 alignment，寬鬆約束下會撐滿整列；縮成內容寬度才靠右
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: IntrinsicWidth(child: button),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: text),
                  button,
                ],
              ),
      ),
    );
  }
}

class _DismissButton extends StatelessWidget {
  const _DismissButton({required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onDismiss,
      builder: (context, state) => Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s3),
        color: state.hovered ? t.paper.raised : Colors.transparent,
        child: AppText(
          _dismissLabel,
          scale: TypeScale.label,
          color: state.pressed ? t.ink.primary : t.ai,
        ),
      ),
    );
  }
}
