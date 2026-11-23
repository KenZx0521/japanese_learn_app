import 'package:material_ui/material_ui.dart';

import '../tokens.dart';
import 'paper_texture.dart';

/// 所有畫面的根：`Material(transparency)`、紙底、紙紋、SafeArea、最大寬（§4.4）。
/// 內容一律靠左，右上角留給印章（§4.1 不對稱版面）。
class PaperScaffold extends StatelessWidget {
  const PaperScaffold({
    required this.body,
    this.aside,
    this.bottom,
    this.scrollable = true,
    super.key,
  });

  final Widget body;

  /// ≥1024 寬時放右欄，較窄時不顯示（呼叫端要有替代入口）。
  final Widget? aside;

  /// 固定在底部（例如「開始」按鈕），不隨內容捲動。
  final Widget? bottom;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: t.paper.base,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const PaperTexture(),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) =>
                    _layout(constraints.maxWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _layout(double width) {
    final margin = PaperLayout.sideMargin(width);
    final hasAside = aside != null && width >= PaperLayout.wideBreakpoint;
    final main = _mainColumn(margin);
    if (!hasAside) return main;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: PaperLayout.maxContentWidth + margin * 2, child: main),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(0, margin, margin, margin),
            child: aside,
          ),
        ),
      ],
    );
  }

  Widget _mainColumn(double margin) {
    final padding = EdgeInsets.all(margin);
    final content = Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: PaperLayout.maxContentWidth,
        ),
        child: body,
      ),
    );
    return Column(
      children: [
        Expanded(
          child: scrollable
              ? SingleChildScrollView(padding: padding, child: content)
              : Padding(padding: padding, child: content),
        ),
        if (bottom != null)
          Padding(
            padding: EdgeInsets.fromLTRB(margin, 0, margin, margin),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: PaperLayout.maxContentWidth,
                ),
                child: bottom,
              ),
            ),
          ),
      ],
    );
  }
}
