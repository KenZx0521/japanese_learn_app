import 'package:material_ui/material_ui.dart';

import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/pressable.dart';

/// V1 的搜尋框（§3.4）。比照答題線，只有底線，聚焦時底線轉為 ai 色。
class VocabSearchField extends StatefulWidget {
  const VocabSearchField({required this.controller, super.key});

  final TextEditingController controller;

  @override
  State<VocabSearchField> createState() => _VocabSearchFieldState();
}

class _VocabSearchFieldState extends State<VocabSearchField> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Focus(
      onFocusChange: (focused) => setState(() => _focused = focused),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: _focused ? t.ai : t.line.strong,
              width: _focused ? 2 : 1.5,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _field(t)),
            _ClearButton(controller: widget.controller),
          ],
        ),
      ),
    );
  }

  Widget _field(AppTokens t) => TextField(
    controller: widget.controller,
    autocorrect: false,
    textInputAction: TextInputAction.search,
    cursorColor: t.ai,
    style: TypeScale.body.style(t.ink.primary),
    decoration: InputDecoration(
      isDense: true,
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
      hintText: '搜尋：中文、假名、漢字或羅馬字',
      hintMaxLines: 2,
      hintStyle: TypeScale.body.style(t.ink.tertiary),
    ),
  );
}

class _ClearButton extends StatelessWidget {
  const _ClearButton({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: controller,
    builder: (context, value, _) {
      if (value.text.isEmpty) {
        return const SizedBox(height: PaperLayout.minTarget);
      }
      return Pressable(
        onTap: controller.clear,
        semanticLabel: '清除搜尋',
        builder: (context, state) => Center(
          widthFactor: 1,
          child: PressNudge(
            pressed: state.pressed,
            child: AppText(
              '×',
              scale: TypeScale.title,
              color: AppTokens.of(context).ink.secondary,
            ),
          ),
        ),
      );
    },
  );
}
