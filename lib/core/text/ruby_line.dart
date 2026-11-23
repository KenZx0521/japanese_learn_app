import 'package:flutter/semantics.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/pressable.dart';
import '../backend/frb/dto.dart';
import 'ja_text.dart';
import 'romaji_scope.dart';
import 'ruby_box.dart';
import 'ruby_kinsoku.dart';
import 'ruby_neighbor.dart';

/// 帶振假名的句子（§7.3）。`Wrap` 排詞，換行只發生在詞界，
/// 每段一律保留 ruby 列高度，基線自然對齊。ruby 比底字寬時懸在相鄰、
/// 沒有 ruby 的字（送り仮名、助詞、標點、分詞空格）上（`RubyBox`）。
class RubyLine extends StatefulWidget {
  const RubyLine({
    required this.words,
    required this.policy,
    this.semanticLabel,
    this.blankWordIndex,
    this.onWordTap,
    this.baseSize = 24,
    super.key,
  });

  /// 取 [SentenceDto] 的便利建構子。
  RubyLine.sentence(
    SentenceDto sentence, {
    required DisplayPolicyDto policy,
    int? blankWordIndex,
    ValueChanged<WordDto>? onWordTap,
    Key? key,
  }) : this(
         words: sentence.words,
         policy: policy,
         semanticLabel: sentence.display,
         blankWordIndex: blankWordIndex,
         onWordTap: onWordTap,
         key: key,
       );

  final List<WordDto> words;
  final DisplayPolicyDto policy;

  /// 句子表層文字，預設由詞組合。
  final String? semanticLabel;

  /// 把該詞畫成稿紙空格，答案不放進 widget tree。
  final int? blankWordIndex;

  /// 點字查詢；null 時不可點（例如聽力作答前，§3.7）。
  final ValueChanged<WordDto>? onWordTap;
  final double baseSize;

  @override
  State<RubyLine> createState() => _RubyLineState();
}

class _RubyLineState extends State<RubyLine> {
  bool _revealed = false;
  final Set<int> _longPressed = {};

  @override
  void didUpdateWidget(RubyLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 換題時重置「顯示羅馬字」（§3.7：下一題重置）
    if (!identical(oldWidget.words, widget.words)) {
      _revealed = false;
      _longPressed.clear();
    }
  }

  bool _showRomajiFor(int index, bool collapsed) =>
      switch (widget.policy.romaji) {
        RomajiMode.shown => true,
        RomajiMode.shownToggleable => !collapsed,
        RomajiMode.tapToReveal => _revealed,
        RomajiMode.longPressOnly => _longPressed.contains(index),
        RomajiMode.hidden => false,
      };

  bool _hideRuby(WordDto word) =>
      widget.policy.furigana == FuriganaMode.unknownOnly && word.isKnown;

  void _reveal(int index) => setState(() => _longPressed.add(index));

  /// 收尾標點黏在前一個詞後面、開括號黏在下一個詞前面，
  /// 行首不會出現「。」，行尾不會出現「「」。
  List<_Cluster> _clusters() {
    final clusters = <_Cluster>[];
    var opening = const <WordDto>[];
    for (final (index, word) in widget.words.indexed) {
      if (word.isPunct && isOpeningText(word.surface)) {
        opening = [...opening, word];
      } else if (word.isPunct && opening.isEmpty && clusters.isNotEmpty) {
        clusters.add(clusters.removeLast().withPunct(word));
      } else {
        clusters.add(_Cluster(index, word, leading: opening));
        opening = const [];
      }
    }
    return _withHeadsMoved(_withDanglingOpening(clusters, opening));
  }

  /// 開頭不能在行首的字（って 的 っ）併進前一個詞的盒子，和前一個詞一起換行。
  /// 挖空的詞不拆（答案不進樹），前一個詞挖空時也沒有盒子可以收。
  List<_Cluster> _withHeadsMoved(List<_Cluster> clusters) {
    final moved = <_Cluster>[];
    for (final cluster in clusters) {
      final head = cluster.movableHead;
      final previous = moved.lastOrNull;
      if (head.isEmpty ||
          previous == null ||
          !previous.canBorrow ||
          _isBlank(previous) ||
          _isBlank(cluster)) {
        moved.add(cluster);
        continue;
      }
      moved
        ..removeLast()
        ..add(previous.borrowing(cluster, head))
        ..add(cluster.giving(head));
    }
    return moved;
  }

  /// 句尾多出來的開括號沒有下一個詞可黏，黏回前一個詞。
  List<_Cluster> _withDanglingOpening(
    List<_Cluster> clusters,
    List<WordDto> opening,
  ) {
    if (opening.isEmpty || clusters.isEmpty) return clusters;
    return [
      ...clusters.take(clusters.length - 1),
      opening.fold(clusters.last, (cluster, word) => cluster.withPunct(word)),
    ];
  }

  /// 開頭不能在行首的詞（って、っす……）跟前一個詞不分開換行。
  /// 組比一行還寬時才會在組內換行，那時換行點在併走的字之後（`_withHeadsMoved`）。
  List<List<int>> _groupsOf(List<_Cluster> clusters) {
    final groups = <List<int>>[];
    for (final (index, cluster) in clusters.indexed) {
      if (groups.isNotEmpty && cluster.isGluedToPrevious) {
        groups.add([...groups.removeLast(), index]);
      } else {
        groups.add([index]);
      }
    }
    return groups;
  }

  /// 挖空時不用 [RubyLine.semanticLabel]：那是完整句子，報讀會念出答案（§7.3）。
  String get _label {
    final blank = widget.blankWordIndex;
    if (blank == null) {
      return widget.semanticLabel ?? widget.words.map((w) => w.surface).join();
    }
    return [
      for (final (index, word) in widget.words.indexed)
        index == blank ? '空格' : word.surface,
    ].join();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _Metrics.of(context, widget.baseSize);
    final collapsed = RomajiPageScope.collapsedOf(context);
    final spacing = widget.policy.wordSpacing ? metrics.base * 0.32 : 0.0;
    final isTapReveal = widget.policy.romaji == RomajiMode.tapToReveal;
    final clusters = _clusters();
    final edges = _edgesOf(
      clusters,
      _SegmentStyles.of(AppTokens.of(context), metrics),
      spacing,
    );
    return MergeSemantics(
      child: Semantics(
        attributedLabel: jaSemantics(_label),
        customSemanticsActions: _actions(),
        child: ExcludeSemantics(
          // 行首、行尾的 ruby 推回這個容器內
          child: RubyOverhangBoundary(
            child: Wrap(
              spacing: spacing,
              runSpacing: metrics.base * 0.3,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                ..._groupWidgets(clusters, edges, metrics, collapsed, spacing),
                if (isTapReveal)
                  _RevealButton(
                    revealed: _revealed,
                    onTap: () => setState(() => _revealed = !_revealed),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _groupWidgets(
    List<_Cluster> clusters,
    List<List<RubyEdges>> edges,
    _Metrics metrics,
    bool collapsed,
    double spacing,
  ) => [
    for (final group in _groupsOf(clusters))
      _buildGroup(
        [
          for (final index in group)
            _buildCluster(
              clusters[index],
              metrics,
              collapsed,
              edges[index],
              spacing,
            ),
        ],
        // 分詞空格已經畫在併走的字前面
        group.skip(1).every((i) => clusters[i].hasGivenHead) ? 0 : spacing,
      ),
  ];

  /// 比一行還長時才會在組內換行；用 Row 會溢位。
  Widget _buildGroup(List<Widget> words, double spacing) => words.length == 1
      ? words.single
      : Wrap(
          spacing: spacing,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: words,
        );

  bool _isBlank(_Cluster cluster) => cluster.index == widget.blankWordIndex;

  /// 攤平成一列（空格當作有 ruby，不讓別人懸在答案格上），
  /// 算出每個詞每段 ruby 前後可懸掛的文字。
  List<List<RubyEdges>> _edgesOf(
    List<_Cluster> clusters,
    _SegmentStyles styles,
    double spacing,
  ) {
    final pieces = <RubyPiece>[];
    final firsts = <int>[];
    for (final (index, cluster) in clusters.indexed) {
      firsts.add(pieces.length);
      pieces.addAll(
        _piecesOf(
          cluster,
          styles,
          gap: index == 0 || cluster.hasGivenHead ? 0 : spacing,
          borrowedGap: spacing,
        ),
      );
    }
    return [
      for (final (index, cluster) in clusters.indexed)
        _clusterEdges(cluster, pieces, firsts[index]),
    ];
  }

  /// [first] 是這個詞的第一段（含開括號）在 [pieces] 裡的位置。
  List<RubyEdges> _clusterEdges(
    _Cluster cluster,
    List<RubyPiece> pieces,
    int first,
  ) {
    if (_isBlank(cluster)) return const [];
    final parts = cluster.parts;
    final firstPart = first + cluster.leading.length;
    return [
      for (final (at, part) in parts.indexed)
        _visibleRuby(cluster, part.part) == null
            ? noRubyEdges
            : rubyEdgesOf(
                pieces,
                firstPart + at,
                startSkip: at == cluster.firstDrawn
                    ? at + cluster.leading.length
                    : 0,
                endSkip: at == cluster.lastDrawn
                    ? parts.length - 1 - at + cluster.endAffixes
                    : 0,
              ),
    ];
  }

  String? _visibleRuby(_Cluster cluster, RubyPartDto part) =>
      _hideRuby(cluster.word) ? null : part.ruby;

  List<RubyPiece> _piecesOf(
    _Cluster cluster,
    _SegmentStyles styles, {
    required double gap,
    required double borrowedGap,
  }) {
    final pieces = [
      for (final word in cluster.leading)
        RubyPiece(TextSpan(text: word.surface, style: styles.base)),
      if (_isBlank(cluster))
        const RubyPiece(TextSpan(text: ''), hasRuby: true)
      else
        for (final part in cluster.parts)
          RubyPiece(
            TextSpan(text: part.body, style: styles.base),
            // 已知詞隱藏讀音的漢字也擋住懸掛：讀者會把懸上去的讀音當成那個漢字的（JIS X 4051）
            hasRuby: part.part.ruby != null,
            ruby: switch (_visibleRuby(cluster, part.part)) {
              final reading? => TextSpan(text: reading, style: styles.ruby),
              null => null,
            },
          ),
      for (final punct in cluster.punct)
        RubyPiece(TextSpan(text: punct.surface, style: styles.base)),
      if (cluster.borrowed case final borrowed?)
        RubyPiece(
          TextSpan(text: borrowed.text, style: styles.base),
          gapBefore: borrowedGap,
        ),
    ];
    return [
      for (final (index, piece) in pieces.indexed)
        RubyPiece(
          piece.span,
          hasRuby: piece.hasRuby,
          ruby: piece.ruby,
          gapBefore: index == 0 ? gap : piece.gapBefore,
        ),
    ];
  }

  Map<CustomSemanticsAction, VoidCallback>? _actions() {
    final onTap = widget.onWordTap;
    final longPress = widget.policy.romaji == RomajiMode.longPressOnly;
    if (onTap == null && !longPress) return null;
    final blank = widget.blankWordIndex;
    final words = [
      for (final (index, word) in widget.words.indexed)
        if (!word.isPunct && index != blank) (index, word),
    ];
    return {
      for (final (index, word) in words)
        if (onTap != null)
          CustomSemanticsAction(label: '查詢 ${word.surface}（$index）'): () =>
              onTap(word),
      for (final (index, word) in words)
        if (longPress)
          CustomSemanticsAction(label: '顯示羅馬字 ${word.surface}（$index）'): () =>
              _reveal(index),
    };
  }

  Widget _buildCluster(
    _Cluster cluster,
    _Metrics metrics,
    bool collapsed,
    List<RubyEdges> edges,
    double spacing,
  ) {
    final isBlank = _isBlank(cluster);
    final showRomaji = !isBlank && _showRomajiFor(cluster.index, collapsed);
    final word = _WordColumn(
      cluster: cluster,
      metrics: metrics,
      isBlank: isBlank,
      showRomaji: showRomaji,
      hideRuby: _hideRuby(cluster.word),
      edges: edges,
      borrowedGap: spacing,
      wrapBorrowed: _wrapBorrowed,
    );
    return isBlank ? word : _tappable(cluster.index, cluster.word, word);
  }

  /// 併進前一個盒子的字仍屬於原本的詞：點它查那個詞。
  Widget _wrapBorrowed(_Borrowed borrowed, Widget child) =>
      _tappable(borrowed.index, borrowed.word, child);

  Widget _tappable(int index, WordDto word, Widget child) {
    final onTap = widget.onWordTap;
    final longPress = widget.policy.romaji == RomajiMode.longPressOnly;
    if (onTap == null && !longPress) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: onTap == null ? null : () => onTap(word),
      onLongPress: longPress ? () => _reveal(index) : null,
      child: child,
    );
  }
}

/// 從下一個詞收進來的開頭字。
typedef _Borrowed = ({int index, WordDto word, String text});

/// 一個詞的一段，依禁則切好：[body] 是底字，[leading]、[trailing] 併在同一個盒子。
typedef _ClusterPart = ({
  RubyPartDto part,
  String body,
  String leading,
  String trailing,
});

@immutable
final class _Cluster {
  _Cluster(
    this.index,
    this.word, {
    this.leading = const [],
    this.punct = const [],
    this.givenHead = '',
    this.borrowed,
  }) : parts = _partsOf(word.ruby, givenHead.length);

  final int index;
  final WordDto word;

  /// 黏在詞前面的開括號、黏在詞後面的收尾標點。
  final List<WordDto> leading, punct;

  /// 開頭被前一個詞收走的字（空字串表示沒有）。
  final String givenHead;

  /// 從下一個詞收進來、排在標點後面的字。
  final _Borrowed? borrowed;
  final List<_ClusterPart> parts;

  _Cluster withPunct(WordDto next) => _copy(punct: [...punct, next]);

  _Cluster giving(String head) => _copy(givenHead: head);

  _Cluster borrowing(_Cluster next, String head) =>
      _copy(borrowed: (index: next.index, word: next.word, text: head));

  _Cluster _copy({
    List<WordDto>? punct,
    String? givenHead,
    _Borrowed? borrowed,
  }) => _Cluster(
    index,
    word,
    leading: leading,
    punct: punct ?? this.punct,
    givenHead: givenHead ?? this.givenHead,
    borrowed: borrowed ?? this.borrowed,
  );

  bool get hasGivenHead => givenHead.isNotEmpty;

  /// 有畫出來的段可以收字，而且還沒收過。
  bool get canBorrow => lastDrawn >= 0 && borrowed == null;

  /// 最後一段盒子裡，底字後面併了幾段（標點、收進來的字）。
  int get endAffixes => punct.length + (borrowed == null ? 0 : 1);

  /// 可以交給前一個詞的開頭字。第一段有讀音、或整個詞都是這種字時不拆。
  String get movableHead {
    final first = word.ruby.firstOrNull;
    if (!isGluedToPrevious || first == null || first.ruby != null) return '';
    final head = noLineStartPrefix(first.base);
    return head.length == word.surface.length ? '' : head;
  }

  bool get isGluedToPrevious =>
      !word.isPunct && leading.isEmpty && startsNoLineStart(word.surface);

  /// 第一、最後一個畫出來的段（內容被前一段併走的不畫）；都沒有時是 -1。
  int get firstDrawn => parts.indexWhere((part) => part.body.isNotEmpty);
  int get lastDrawn => parts.lastIndexWhere((part) => part.body.isNotEmpty);

  /// 詞內也可能換行（比一行還長的詞），段與段之間一樣守禁則。
  static List<_ClusterPart> _partsOf(List<RubyPartDto> parts, int skip) {
    final cuts = kinsokuCuts([
      for (final (index, part) in parts.indexed)
        KinsokuAtom(
          index == 0 ? part.base.substring(skip) : part.base,
          isBox: true,
          isFixed: part.ruby != null,
        ),
    ]);
    String joined(List<KinsokuMove> moves) =>
        moves.map((move) => move.text).join();
    return [
      for (final (index, part) in parts.indexed)
        (
          part: part,
          body: cuts[index].body,
          leading: joined(cuts[index].leading),
          trailing: joined(cuts[index].trailing),
        ),
    ];
  }
}

@immutable
final class _Metrics {
  const _Metrics(this.base, this.scaler, this.romajiScaler);

  factory _Metrics.of(BuildContext context, double baseSize) {
    final size = baseSize < RubyMetrics.minRubyLineBase
        ? RubyMetrics.minRubyLineBase
        : baseSize;
    final media = MediaQuery.textScalerOf(context);
    return _Metrics(
      size,
      media.clamp(maxScaleFactor: TypeScale.jaSentence.maxScale),
      media.clamp(maxScaleFactor: RubyMetrics.romajiMaxScale),
    );
  }

  final double base;
  final TextScaler scaler, romajiScaler;
  double get rubySize => RubyMetrics.rubySize(base);
  double get romajiSize => RubyMetrics.romajiSize(base);
}

class _WordColumn extends StatelessWidget {
  const _WordColumn({
    required this.cluster,
    required this.metrics,
    required this.isBlank,
    required this.showRomaji,
    required this.hideRuby,
    required this.edges,
    required this.borrowedGap,
    required this.wrapBorrowed,
  });

  final _Cluster cluster;
  final _Metrics metrics;
  final bool isBlank, showRomaji, hideRuby;

  /// 每段 ruby 前後可懸掛的文字，順序同 `cluster.word.ruby`。
  final List<RubyEdges> edges;

  /// 收進來的字前面的分詞空格。
  final double borrowedGap;
  final Widget Function(_Borrowed, Widget) wrapBorrowed;

  String get _punct => cluster.punct.map((word) => word.surface).join();
  String get _opening => cluster.leading.map((word) => word.surface).join();

  /// 開括號、標點放進第一、最後一段的盒子：詞剛好滿行時才不會單獨換行。
  List<Widget> _segments() {
    final punct = _punct;
    final opening = _opening;
    if (isBlank) return [_blankSegment(opening, punct)];
    final parts = cluster.parts;
    if (cluster.lastDrawn < 0) {
      if (punct.isEmpty && opening.isEmpty) return const [];
      return [
        _RubySegment(
          part: RubyPartDto(base: '$opening$punct'),
          metrics: metrics,
          hideRuby: true,
        ),
      ];
    }
    return [
      for (final (index, part) in parts.indexed)
        if (part.body.isNotEmpty)
          _RubySegment(
            part: RubyPartDto(base: part.body, ruby: part.part.ruby),
            metrics: metrics,
            hideRuby: hideRuby,
            leading:
                '${index == cluster.firstDrawn ? opening : ''}${part.leading}',
            trailing:
                '${part.trailing}${index == cluster.lastDrawn ? punct : ''}',
            borrowed: index == cluster.lastDrawn ? _borrowedHead() : null,
            edges: index < edges.length ? edges[index] : noRubyEdges,
          ),
    ];
  }

  _BorrowedHead? _borrowedHead() {
    final borrowed = cluster.borrowed;
    if (borrowed == null) return null;
    return (
      text: borrowed.text,
      gap: borrowedGap,
      wrap: (child) => wrapBorrowed(borrowed, child),
    );
  }

  Widget _blankSegment(String opening, String punct) {
    final blank = _BlankCell(metrics: metrics);
    if (punct.isEmpty && opening.isEmpty) return blank;
    Widget affix(String text) => _RubySegment(
      part: RubyPartDto(base: text),
      metrics: metrics,
      hideRuby: true,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (opening.isNotEmpty) affix(opening),
        Flexible(child: blank),
        if (punct.isNotEmpty) affix(punct),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 比一行還長的詞才會在詞內換行；用 Row 會溢位
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, children: _segments()),
        if (showRomaji)
          Text(
            cluster.word.romaji,
            textScaler: metrics.romajiScaler,
            style: TypeScale.caption
                .style(t.ink.secondary)
                .copyWith(fontSize: metrics.romajiSize, height: 1.3),
          ),
      ],
    );
  }
}

/// 底字與讀音的樣式；量鄰居寬度也用同一份。
@immutable
final class _SegmentStyles {
  const _SegmentStyles(this.base, this.ruby);

  factory _SegmentStyles.of(AppTokens t, _Metrics metrics) => _SegmentStyles(
    jaStyle(
      TypeScale.jaSentence,
      t.ink.primary,
    ).copyWith(fontSize: metrics.base, height: 1.25),
    jaStyle(TypeScale.jaSentence, t.ink.secondary).copyWith(
      fontSize: metrics.rubySize,
      height: 1.15,
      fontWeight: FontWeight.w600,
    ),
  );

  final TextStyle base, ruby;
}

/// 併進盒子尾端的下一個詞開頭：[gap] 是分詞空格，[wrap] 接上那個詞的點擊。
typedef _BorrowedHead = ({
  String text,
  double gap,
  Widget Function(Widget) wrap,
});

class _RubySegment extends StatelessWidget {
  const _RubySegment({
    required this.part,
    required this.metrics,
    required this.hideRuby,
    this.leading = '',
    this.trailing = '',
    this.borrowed,
    this.edges = noRubyEdges,
  });

  final RubyPartDto part;
  final _Metrics metrics;
  final bool hideRuby;

  /// 併進這個盒子、排在底字前後的字；空字串表示沒有。
  final String leading, trailing;
  final _BorrowedHead? borrowed;
  final RubyEdges edges;

  Widget? _trailingOf(TextStyle style) {
    final own = trailing.isEmpty ? null : _text(trailing, style);
    final head = borrowed;
    if (head == null) return own;
    final moved = head.wrap(
      Padding(
        padding: EdgeInsets.only(left: head.gap),
        child: _text(head.text, style),
      ),
    );
    if (own == null) return moved;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [own, moved],
    );
  }

  @override
  Widget build(BuildContext context) {
    final styles = _SegmentStyles.of(AppTokens.of(context), metrics);
    final ruby = hideRuby ? null : part.ruby;
    return RubyBox(
      base: ruby == null
          ? plainRubyBaseText(
              part.base,
              style: styles.base,
              textScaler: metrics.scaler,
            )
          : _text(part.base, styles.base),
      // 無假名也放空白，保留 ruby 列高度
      ruby: _text(ruby ?? ' ', styles.ruby),
      leading: leading.isEmpty ? null : _text(leading, styles.base),
      trailing: _trailingOf(styles.base),
      baseLength: part.base.runes.length,
      rubyLength: ruby?.runes.length ?? 0,
      textScaler: metrics.scaler,
      start: edges.start,
      end: edges.end,
    );
  }

  Widget _text(String data, TextStyle style) =>
      Text(data, locale: jaLocale, textScaler: metrics.scaler, style: style);
}

class _BlankCell extends StatelessWidget {
  const _BlankCell({required this.metrics});
  final _Metrics metrics;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final side = metrics.scaler.scale(metrics.base) * 1.15;
    return Container(
      width: side * 2,
      height: side,
      margin: EdgeInsets.only(top: metrics.rubySize),
      decoration: BoxDecoration(
        color: t.paper.sunken,
        border: Border.all(color: t.line.strong),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({required this.revealed, required this.onTap});
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Pressable(
      onTap: onTap,
      semanticLabel: revealed ? '收起羅馬字' : '顯示羅馬字',
      builder: (context, state) => Padding(
        padding: const EdgeInsets.all(AppSpace.s2),
        child: Container(
          alignment: Alignment.center,
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: state.hovered ? t.paper.raised : t.paper.sunken,
            border: Border.all(
              color: state.pressed ? t.ink.primary : t.line.strong,
            ),
            borderRadius: AppRadii.r1,
          ),
          child: Text(
            'aA',
            textScaler: TextScaler.noScaling,
            style: TypeScale.caption.style(t.ink.secondary),
          ),
        ),
      ),
    );
  }
}
