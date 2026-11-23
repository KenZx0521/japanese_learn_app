import 'package:material_ui/material_ui.dart';

import 'tokens.dart';

/// 由 tokens 建立 ThemeData。外觀全部來自 tokens，`Scaffold`、`TextField`、
/// `showModalBottomSheet` 只當基礎設施（architecture §5.5）。
ThemeData buildTheme(AppTokens t) {
  final scheme = _colorScheme(t);
  return ThemeData(
    useMaterial3: true,
    brightness: t.brightness,
    colorScheme: scheme,
    fontFamily: AppFonts.sans,
    scaffoldBackgroundColor: t.paper.base,
    canvasColor: t.paper.base,
    splashFactory: NoSplash.splashFactory,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    hoverColor: t.paper.raised,
    focusColor: t.ai,
    dividerColor: t.line.grid,
    textTheme: _textTheme(t),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: t.ai,
      selectionColor: t.ai.withValues(alpha: 0.25),
      selectionHandleColor: t.ai,
    ),
    inputDecorationTheme: _inputTheme(t),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t.paper.raised,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: t.paper.raised,
      shape: const RoundedRectangleBorder(),
      elevation: 0,
      modalElevation: 0,
      showDragHandle: false,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: t.paper.raised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
    ),
    extensions: [t],
  );
}

ColorScheme _colorScheme(AppTokens t) => ColorScheme(
  brightness: t.brightness,
  primary: t.ink.primary,
  onPrimary: t.paper.base,
  secondary: t.ai,
  onSecondary: t.paper.base,
  error: t.shu,
  onError: t.onShu,
  surface: t.paper.base,
  onSurface: t.ink.primary,
  surfaceContainerHighest: t.paper.sunken,
  outline: t.line.strong,
  outlineVariant: t.line.grid,
);

TextTheme _textTheme(AppTokens t) {
  TextStyle s(TypeScale scale) => scale.style(t.ink.primary);
  return TextTheme(
    displayLarge: s(TypeScale.displayL),
    displayMedium: s(TypeScale.displayM),
    headlineMedium: s(TypeScale.displayM),
    titleLarge: s(TypeScale.title),
    titleMedium: s(TypeScale.title),
    bodyLarge: s(TypeScale.body),
    bodyMedium: s(TypeScale.body),
    bodySmall: s(TypeScale.caption),
    labelLarge: s(TypeScale.label),
    labelMedium: s(TypeScale.label),
    labelSmall: s(TypeScale.caption),
  );
}

InputDecorationTheme _inputTheme(AppTokens t) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: AppRadii.r1,
    borderSide: BorderSide(color: color, width: width),
  );
  return InputDecorationTheme(
    filled: true,
    fillColor: t.paper.sunken,
    hintStyle: TypeScale.body.style(t.ink.tertiary),
    labelStyle: TypeScale.label.style(t.ink.secondary),
    contentPadding: const EdgeInsets.symmetric(
      horizontal: AppSpace.s4,
      vertical: AppSpace.s3,
    ),
    border: border(t.line.strong, 1),
    enabledBorder: border(t.line.strong, 1),
    focusedBorder: border(t.ai, 2),
    errorBorder: border(t.shu, 1),
    focusedErrorBorder: border(t.shu, 2),
  );
}
