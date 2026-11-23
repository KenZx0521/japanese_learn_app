import 'package:material_ui/material_ui.dart';

/// 所有日文的語言標註（flutter-app.md §7.2）。
const jaLocale = Locale('ja', 'JP');

abstract final class AppFonts {
  static const ja = 'KleeOneJP';
  static const sans = 'NotoSansTC';
  static const serif = 'NotoSerifTC';
}

@immutable
final class PaperColors {
  const PaperColors({
    required this.base,
    required this.raised,
    required this.sunken,
  });
  final Color base, raised, sunken;

  static PaperColors lerp(PaperColors a, PaperColors b, double t) =>
      PaperColors(
        base: Color.lerp(a.base, b.base, t)!,
        raised: Color.lerp(a.raised, b.raised, t)!,
        sunken: Color.lerp(a.sunken, b.sunken, t)!,
      );
}

@immutable
final class InkColors {
  const InkColors({
    required this.primary,
    required this.secondary,
    required this.tertiary,
  });
  final Color primary, secondary, tertiary;

  static InkColors lerp(InkColors a, InkColors b, double t) => InkColors(
    primary: Color.lerp(a.primary, b.primary, t)!,
    secondary: Color.lerp(a.secondary, b.secondary, t)!,
    tertiary: Color.lerp(a.tertiary, b.tertiary, t)!,
  );
}

@immutable
final class LineColors {
  const LineColors({required this.grid, required this.strong});
  final Color grid, strong;

  static LineColors lerp(LineColors a, LineColors b, double t) => LineColors(
    grid: Color.lerp(a.grid, b.grid, t)!,
    strong: Color.lerp(a.strong, b.strong, t)!,
  );
}

/// 色彩與紙質，掛在 `ThemeData.extensions`。元件一律透過 [AppTokens.of] 取用，
/// 不得判斷亮暗（§4.5）。
@immutable
final class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.paper,
    required this.ink,
    required this.line,
    required this.shu,
    required this.onShu,
    required this.ai,
    required this.moegi,
    required this.kincha,
    required this.shadow1,
    required this.shadow2,
    required this.raisedBorder,
    required this.textureOpacity,
    required this.brightness,
  });

  final PaperColors paper;
  final InkColors ink;
  final LineColors line;
  final Color shu, onShu, ai, moegi, kincha;

  /// 深色模式為空，改用 [raisedBorder]。
  final List<BoxShadow> shadow1, shadow2;
  final Color? raisedBorder;
  final double textureOpacity;
  final Brightness brightness;

  static const light = AppTokens(
    paper: PaperColors(
      base: Color(0xFFF5EFE0),
      raised: Color(0xFFFBF7EC),
      sunken: Color(0xFFEBE3CF),
    ),
    ink: InkColors(
      primary: Color(0xFF1E1A15),
      secondary: Color(0xFF5B5346),
      tertiary: Color(0xFF675E50),
    ),
    line: LineColors(grid: Color(0xFFCFA08F), strong: Color(0xFF8A6A5C)),
    shu: Color(0xFFA92716),
    onShu: Color(0xFFFFF8EE),
    ai: Color(0xFF24466F),
    moegi: Color(0xFF3F6212),
    kincha: Color(0xFF7A4F05),
    shadow1: [
      BoxShadow(offset: Offset(0, 1), color: Color(0x101E1A15)),
      BoxShadow(offset: Offset(0, 2), blurRadius: 6, color: Color(0x141E1A15)),
    ],
    shadow2: [
      BoxShadow(offset: Offset(0, 6), blurRadius: 16, color: Color(0x201E1A15)),
    ],
    raisedBorder: null,
    textureOpacity: 0.05,
    brightness: Brightness.light,
  );

  static const dark = AppTokens(
    paper: PaperColors(
      base: Color(0xFF17140F),
      raised: Color(0xFF221E18),
      sunken: Color(0xFF100E0A),
    ),
    ink: InkColors(
      primary: Color(0xFFEFE8D8),
      secondary: Color(0xFFB9AF9D),
      tertiary: Color(0xFF9A907F),
    ),
    line: LineColors(grid: Color(0xFF4A3B33), strong: Color(0xFF8C7768)),
    shu: Color(0xFFEC7560),
    onShu: Color(0xFF1B0F0A),
    ai: Color(0xFF93B3DE),
    moegi: Color(0xFFA9C873),
    kincha: Color(0xFFE0B45C),
    shadow1: [],
    shadow2: [],
    raisedBorder: Color(0xFF4A3B33),
    textureOpacity: 0.03,
    brightness: Brightness.dark,
  );

  /// `MediaQuery.highContrastOf` 為真時使用（§4.5）。
  AppTokens get highContrast => AppTokens(
    paper: paper,
    ink: InkColors(
      primary: ink.primary,
      secondary: ink.primary,
      tertiary: ink.primary,
    ),
    line: LineColors(grid: line.strong, strong: line.strong),
    shu: shu,
    onShu: onShu,
    ai: ai,
    moegi: moegi,
    kincha: kincha,
    shadow1: shadow1,
    shadow2: shadow2,
    raisedBorder: raisedBorder == null ? null : line.strong,
    textureOpacity: 0,
    brightness: brightness,
  );

  static AppTokens of(BuildContext context) {
    final tokens = Theme.of(context).extension<AppTokens>() ?? AppTokens.light;
    return MediaQuery.highContrastOf(context) ? tokens.highContrast : tokens;
  }

  /// 字卡、面板等「拿在手上」的物件；其餘版面不用陰影（§4.1）。
  BoxDecoration raised({bool strong = false}) => BoxDecoration(
    color: paper.raised,
    boxShadow: strong ? shadow2 : shadow1,
    border: raisedBorder == null ? null : Border.all(color: raisedBorder!),
  );

  @override
  AppTokens copyWith({PaperColors? paper, InkColors? ink}) => AppTokens(
    paper: paper ?? this.paper,
    ink: ink ?? this.ink,
    line: line,
    shu: shu,
    onShu: onShu,
    ai: ai,
    moegi: moegi,
    kincha: kincha,
    shadow1: shadow1,
    shadow2: shadow2,
    raisedBorder: raisedBorder,
    textureOpacity: textureOpacity,
    brightness: brightness,
  );

  @override
  AppTokens lerp(covariant AppTokens? other, double t) {
    if (other == null) return this;
    final end = t < 0.5 ? this : other;
    return AppTokens(
      paper: PaperColors.lerp(paper, other.paper, t),
      ink: InkColors.lerp(ink, other.ink, t),
      line: LineColors.lerp(line, other.line, t),
      shu: Color.lerp(shu, other.shu, t)!,
      onShu: Color.lerp(onShu, other.onShu, t)!,
      ai: Color.lerp(ai, other.ai, t)!,
      moegi: Color.lerp(moegi, other.moegi, t)!,
      kincha: Color.lerp(kincha, other.kincha, t)!,
      shadow1: end.shadow1,
      shadow2: end.shadow2,
      raisedBorder: end.raisedBorder,
      textureOpacity: end.textureOpacity,
      brightness: end.brightness,
    );
  }
}

/// §4.2 的字級表。`maxScale` 是該級的字級縮放上限（clamp）。
enum TypeScale {
  displayL(AppFonts.serif, 36, 46, FontWeight.w800, 1.3),
  displayM(AppFonts.serif, 28, 36, FontWeight.w800, 1.3),
  title(AppFonts.sans, 20, 28, FontWeight.w700, 1.5),
  body(AppFonts.sans, 16, 26, FontWeight.w400, 2.0),
  label(AppFonts.sans, 14, 20, FontWeight.w700, 1.5),
  caption(AppFonts.sans, 13, 20, FontWeight.w400, 2.0),
  jaHero(AppFonts.ja, 56, 72, FontWeight.w600, 1.2),
  jaSentence(AppFonts.ja, 24, 34, FontWeight.w400, 1.6),
  jaBody(AppFonts.ja, 18, 30, FontWeight.w400, 2.0);

  const TypeScale(
    this.family,
    this.size,
    this.lineHeight,
    this.weight,
    this.maxScale,
  );

  final String family;
  final double size, lineHeight;
  final FontWeight weight;
  final double maxScale;

  bool get isJapanese => family == AppFonts.ja;

  TextStyle style(Color color) => TextStyle(
    fontFamily: family,
    fontFamilyFallback: const [],
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    color: color,
    locale: isJapanese ? jaLocale : null,
    leadingDistribution: TextLeadingDistribution.even,
  );

  TextScaler scaler(BuildContext context) =>
      MediaQuery.textScalerOf(context).clamp(maxScaleFactor: maxScale);
}

/// 振假名與羅馬字的字級規則（§4.2）。
abstract final class RubyMetrics {
  static const minRubySize = 12.0;
  static const minRomajiSize = 12.0;
  static const minRubyLineBase = 22.0;
  static const romajiMaxScale = 1.5;

  static double rubySize(double base) =>
      (base * 0.48).clamp(minRubySize, double.infinity);
  static double romajiSize(double base) =>
      (base * 0.46).clamp(minRomajiSize, double.infinity);
}

abstract final class AppSpace {
  static const s1 = 4.0;
  static const s2 = 8.0;
  static const s3 = 12.0;
  static const s4 = 16.0;
  static const s5 = 24.0;
  static const s6 = 32.0;
  static const s7 = 48.0;
  static const s8 = 72.0;
}

abstract final class AppRadii {
  static const r0 = BorderRadius.zero;
  static const r1 = BorderRadius.all(Radius.circular(2));
  static BorderRadius stamp(double side) => BorderRadius.circular(side * 0.12);
}

/// 版面格線（§4.2）：稿紙模組、側邊距、內容寬。
abstract final class PaperLayout {
  static const maxContentWidth = 720.0;
  static const compactBreakpoint = 360.0;
  static const wideBreakpoint = 1024.0;
  static const railWidth = 88.0;
  static const genkoColumns = 5;
  static const genkoRowGap = 6.0;
  static const minTarget = 48.0;

  static double sideMargin(double width) =>
      width < compactBreakpoint ? AppSpace.s4 : AppSpace.s5;

  static double cell(double contentWidth, {int columns = genkoColumns}) =>
      (contentWidth / columns).floorToDouble();
}

/// WCAG 2.x 對比度（§4.6 在 token 層用公式測）。
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final high = la > lb ? la : lb;
  final low = la > lb ? lb : la;
  return (high + 0.05) / (low + 0.05);
}
