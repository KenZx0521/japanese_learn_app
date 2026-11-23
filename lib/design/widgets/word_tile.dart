import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/text/ja_text.dart';
import '../tokens.dart';
import 'pressable.dart';

/// reorder 詞塊（§3.6）：高 ≥48，點一下移動，再點移回。
class WordTile extends StatelessWidget {
  const WordTile({
    required this.text,
    required this.placed,
    this.onTap,
    super.key,
  });

  final String text;

  /// true 時在答題線上，動作語意變成「移回詞庫」。
  final bool placed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final action = placed ? '移回詞庫' : '移到答案';
    final tap = onTap;
    return Pressable(
      onTap: tap,
      attributedLabel: jaSemantics(text),
      semanticHint: action,
      customActions: tap == null
          ? null
          : {CustomSemanticsAction(label: action): tap},
      builder: (context, state) => PressNudge(
        pressed: state.pressed,
        child: Container(
          alignment: Alignment.center,
          constraints: const BoxConstraints(minHeight: PaperLayout.minTarget),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s3,
            vertical: AppSpace.s2,
          ),
          decoration: BoxDecoration(
            color: state.hovered ? t.paper.base : t.paper.raised,
            borderRadius: AppRadii.r1,
            border: Border.all(color: t.line.strong),
          ),
          child: JaText(text, scale: TypeScale.jaBody),
        ),
      ),
    );
  }
}
