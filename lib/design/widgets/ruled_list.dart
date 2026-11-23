import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'app_text.dart';
import 'pressable.dart';

/// 細線列表：以線與留白分隔，不用卡片（§4.1）。
class RuledList extends StatelessWidget {
  const RuledList({required this.children, super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line.grid)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class RuledTile extends StatelessWidget {
  const RuledTile({
    required this.title,
    this.leading,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.semanticLabel,
    super.key,
  });

  final Widget title;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final String? semanticLabel;

  /// 中文單行標題的便利建構子。
  factory RuledTile.text(
    String title, {
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    Key? key,
  }) => RuledTile(
    key: key,
    title: AppText(title),
    subtitle: subtitle == null ? null : _TileCaption(text: subtitle),
    leading: leading,
    trailing: trailing,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line.grid)),
      ),
      child: Pressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        builder: (context, state) => ColoredBox(
          color: _fill(t, state),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpace.s3,
              horizontal: AppSpace.s1,
            ),
            child: PressNudge(pressed: state.pressed, child: _row()),
          ),
        ),
      ),
    );
  }

  Color _fill(AppTokens t, PressState state) {
    if (state.pressed) return t.paper.sunken;
    if (state.hovered) return t.paper.raised;
    return Colors.transparent;
  }

  Widget _row() => Row(
    children: [
      if (leading != null) ...[leading!, const SizedBox(width: AppSpace.s3)],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [title, ?subtitle],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: AppSpace.s3), trailing!],
    ],
  );
}

class _TileCaption extends StatelessWidget {
  const _TileCaption({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => AppText(
    text,
    scale: TypeScale.caption,
    color: AppTokens.of(context).ink.secondary,
  );
}
