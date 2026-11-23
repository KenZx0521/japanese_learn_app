import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../backend/frb/dto.dart';
import '../backend/providers.dart';
import 'ja_text.dart';
import 'ruby_box.dart';
import 'ruby_kinsoku.dart';
import 'ruby_neighbor.dart';

/// 中文解說夾日文，解析全交給 Rust 的 `parse_mixed_text`（§7.3），
/// Dart 不做任何自動判定。
class MixedText extends ConsumerWidget {
  const MixedText(
    this.source, {
    this.scale = TypeScale.body,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
    super.key,
  });

  final String source;
  final TypeScale scale;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final spans = ref.watch(textToolsProvider).parseMixedText(source);
    final styles = _MixedStyles(scale, color ?? t.ink.primary, t.ink.secondary);
    // 行首、行尾的 ruby 不懸出這個容器
    return RubyOverhangBoundary(
      child: Text.rich(
        TextSpan(children: styles.inlineSpans(spans)),
        textScaler: scale.scaler(context),
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
      ),
    );
  }
}

bool _isRuby(MixedSpanDto span) =>
    span is MixedSpanDto_Ja && span.ruby.any((part) => part.ruby != null);

/// 攤平後的一小段：中文、沒有讀音的日文，或 ruby 段的一個 part（[part] 非 null，畫成盒子）。
@immutable
final class _Atom {
  const _Atom(this.span, this.text, this.style, {this.part, this.locale});

  /// 屬於第幾個 Rust 段。
  final int span;
  final String text;
  final TextStyle style;
  final RubyPartDto? part;
  final Locale? locale;

  bool get isBox => part != null;
  bool get hasRuby => part?.ruby != null;
}

@immutable
final class _MixedStyles {
  const _MixedStyles(this.scale, this.color, this.rubyColor);

  final TypeScale scale;
  final Color color, rubyColor;

  TextStyle get zh => scale.style(color);

  double get jaFontSize => scale.size * 1.05;

  /// 粗體的中文（title、label）旁邊用 Klee 600，否則假名細到像被淡化（Klee 只有 400、600）。
  FontWeight get _jaWeight =>
      scale.weight == FontWeight.w700 ? FontWeight.w600 : FontWeight.w400;

  /// §7.2 第 4 條：字形與螢幕報讀兩個 locale 都要設（實證 #12）。
  TextStyle get ja => jaStyle(TypeScale.jaBody, color).copyWith(
    fontSize: jaFontSize,
    height: scale.lineHeight / jaFontSize,
    fontWeight: _jaWeight,
    locale: jaLocale,
  );

  /// ruby 段的底字與讀音；量寬度也用同一份，鄰居才估得準。
  TextStyle get rubyBase => ja.copyWith(height: 1.15);

  TextStyle get rubyText => ja.copyWith(
    fontSize: RubyMetrics.rubySize(jaFontSize),
    fontWeight: FontWeight.w600,
    color: rubyColor,
    height: 1.1,
  );

  List<InlineSpan> inlineSpans(List<MixedSpanDto> spans) {
    final atoms = _atomsOf(spans);
    final cuts = kinsokuCuts([
      for (final atom in atoms)
        KinsokuAtom(atom.text, isBox: atom.isBox, isFixed: atom.hasRuby),
    ]);
    final pieces = _piecesOf(atoms, cuts);
    return [
      for (final (index, atom) in atoms.indexed)
        if (!atom.isBox)
          _textSpan(
            atom,
            cuts[index],
            afterText: _followsText(atoms, cuts, index),
            next: _nextText(atoms, cuts, index),
          )
        else if (cuts[index].body.isNotEmpty)
          _boxSpan(spans, atoms, cuts, pieces, index),
    ];
  }

  List<_Atom> _atomsOf(List<MixedSpanDto> spans) => [
    for (final (index, span) in spans.indexed)
      ...switch (span) {
        MixedSpanDto_Zh(:final text) => [_Atom(index, text, zh)],
        MixedSpanDto_Ja(:final text) when !_isRuby(span) => [
          _Atom(index, text, ja, locale: jaLocale),
        ],
        MixedSpanDto_Ja(:final ruby) => [
          for (final part in ruby)
            _Atom(index, part.base, rubyBase, part: part),
        ],
      },
  ];

  /// 攤平成一列，才知道每段 ruby 前後有哪些沒有 ruby 的字可以懸掛。
  /// 併進盒子的字不算鄰居，盒子自己量。
  List<RubyPiece> _piecesOf(List<_Atom> atoms, List<KinsokuCut> cuts) => [
    for (final (index, atom) in atoms.indexed)
      RubyPiece(
        TextSpan(text: cuts[index].body, style: atom.style),
        hasRuby: atom.hasRuby,
        ruby: switch (atom.part?.ruby) {
          final reading? => TextSpan(text: reading, style: rubyText),
          null => null,
        },
      ),
  ];

  /// 緊接在前面的是文字（不是盒子，盒子自己會把開頭的字收走）。
  bool _followsText(List<_Atom> atoms, List<KinsokuCut> cuts, int index) =>
      index > 0 && !atoms[index - 1].isBox && cuts[index - 1].body.isNotEmpty;

  /// 緊接在後面的文字；盒子的邊界引擎管不到，這裡只看純文字。
  String _nextText(List<_Atom> atoms, List<KinsokuCut> cuts, int index) =>
      index + 1 < atoms.length && !atoms[index + 1].isBox
      ? cuts[index + 1].body
      : '';

  /// 被下一個盒子拿走的結尾從這段的文字移走，但仍由這段念出來。
  /// 日文段的零寬字只影響換行，報讀用原文。
  TextSpan _textSpan(
    _Atom atom,
    KinsokuCut cut, {
    required bool afterText,
    required String next,
  }) {
    final body = withNoBreakSpaces(cut.body, next: next);
    final text = atom.locale == null
        ? body
        : withLineStartJoiners(body, afterText: afterText);
    final spoken = '${cut.body}${cut.tail}';
    return TextSpan(
      text: text,
      locale: atom.locale,
      style: atom.style,
      semanticsLabel: spoken == text ? null : spoken,
    );
  }

  /// 每段各一個 WidgetSpan，段與段之間才能換行；整段一個 Row 會溢位。
  InlineSpan _boxSpan(
    List<MixedSpanDto> spans,
    List<_Atom> atoms,
    List<KinsokuCut> cuts,
    List<RubyPiece> pieces,
    int index,
  ) {
    final atom = atoms[index];
    final cut = cuts[index];
    final part = atom.part;
    final span = spans[atom.span];
    final isFirst = !_hasEarlierBox(atoms, cuts, index);
    return WidgetSpan(
      alignment: PlaceholderAlignment.baseline,
      baseline: TextBaseline.alphabetic,
      child: _InlineRuby(
        part: RubyPartDto(base: cut.body, ruby: part?.ruby),
        semanticText: isFirst && span is MixedSpanDto_Ja ? span.text : null,
        semanticTrailing: isFirst ? _semanticTrailing(atoms, cuts, index) : '',
        styles: this,
        leading: _affix(cut.leading, atoms),
        trailing: _affix(cut.trailing, atoms),
        edges: part?.ruby == null ? noRubyEdges : rubyEdgesOf(pieces, index),
      ),
    );
  }

  /// 同一個 Rust 段前面還有沒有畫出來的盒子；整段文字只在第一個盒子念一次。
  bool _hasEarlierBox(List<_Atom> atoms, List<KinsokuCut> cuts, int index) => [
    for (var i = index - 1; i >= 0 && atoms[i].span == atoms[index].span; i--)
      if (atoms[i].isBox && cuts[i].body.isNotEmpty) i,
  ].isNotEmpty;

  /// 這個 Rust 段的盒子收走的、段外文字的開頭，接在整段文字後面念一次。
  String _semanticTrailing(
    List<_Atom> atoms,
    List<KinsokuCut> cuts,
    int index,
  ) => [
    for (
      var i = index;
      i < atoms.length && atoms[i].span == atoms[index].span;
      i++
    )
      for (final move in cuts[i].trailing)
        if (!atoms[move.atom].isBox) move.text,
  ].join();

  /// 併進盒子的字，保留各自原本的樣式。
  Widget? _affix(List<KinsokuMove> moves, List<_Atom> atoms) {
    if (moves.isEmpty) return null;
    final isSameStyle = moves.every(
      (move) => atoms[move.atom].style == atoms[moves.first.atom].style,
    );
    final first = atoms[moves.first.atom];
    if (isSameStyle) {
      return Text(
        moves.map((move) => move.text).join(),
        locale: first.isBox ? jaLocale : first.locale,
        style: first.style,
        textScaler: TextScaler.noScaling,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          for (final move in moves)
            TextSpan(
              text: move.text,
              style: atoms[move.atom].style,
              locale: atoms[move.atom].isBox
                  ? jaLocale
                  : atoms[move.atom].locale,
            ),
        ],
      ),
      textScaler: TextScaler.noScaling,
    );
  }
}

class _InlineRuby extends StatelessWidget {
  const _InlineRuby({
    required this.part,
    required this.semanticText,
    required this.semanticTrailing,
    required this.styles,
    required this.leading,
    required this.trailing,
    required this.edges,
  });

  final RubyPartDto part;

  /// 整段的文字，只放在第一段，螢幕報讀才不會逐段念。
  final String? semanticText;

  /// 併進最後一段盒子的收尾標點，接在整段文字後面念一次（不帶 ja locale）。
  final String semanticTrailing;
  final _MixedStyles styles;

  /// 併進這個盒子、排在底字前後的字；null 表示沒有。
  final Widget? leading, trailing;

  /// 前後可以讓 ruby 懸掛的文字。
  final RubyEdges edges;

  @override
  Widget build(BuildContext context) {
    final segment = ExcludeSemantics(
      child: RubyBox(
        base: part.ruby == null
            ? plainRubyBaseText(
                part.base,
                style: styles.rubyBase,
                textScaler: TextScaler.noScaling,
              )
            : _text(part.base, styles.rubyBase),
        ruby: _text(part.ruby ?? ' ', styles.rubyText),
        leading: leading,
        trailing: trailing,
        baseLength: part.base.runes.length,
        rubyLength: part.ruby?.runes.length ?? 0,
        start: edges.start,
        end: edges.end,
      ),
    );
    final label = semanticText;
    return label == null
        ? segment
        : Semantics(
            attributedLabel: jaSemantics(label, suffix: semanticTrailing),
            child: segment,
          );
  }

  /// 縮放由外層 WidgetSpan 統一處理，這裡不再縮放。
  static Widget _text(String data, TextStyle style) => Text(
    data,
    locale: jaLocale,
    style: style,
    textScaler: TextScaler.noScaling,
  );
}
