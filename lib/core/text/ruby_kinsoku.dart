import 'package:flutter/foundation.dart' show immutable;

/// 行首行尾禁則（JIS X 4051）的純計算。
///
/// `WidgetSpan` 前後都可換行，文字引擎的禁則管不到盒子的邊界，
/// 所以不能落在行首、行尾的字要併進相鄰的 `RubyBox`，和盒子一起換行。

// 這些表只用來比對，字本身不畫。內容用不到、字型子集也沒有的字寫成跳脫，
// 否則 `content_tool verify` 的 F04 會把原始碼裡的字當成要顯示的字。
const _closing = '。、，．！？：；）」』】〉》\u3015\uFF3D\uFF5D…,.!?:;)]}\uFF63';
const _smallKana = 'ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ';
const _prolongedAndIteration = 'ー\u3005ゝゞヽヾ';
const _joinedToPrevious = '$_smallKana$_prolongedAndIteration';
const _noLineStart = '$_closing$_joinedToPrevious';
const _noLineEnd = '「『（【〈《\u3014\uFF3B\uFF5B([{\uFF62';
const _wordJoiner = '\u2060';
const _noBreakSpace = '\u00A0';

/// [text] 開頭不能落在行首的字。
String noLineStartPrefix(String text) {
  var end = 0;
  while (end < text.length && _noLineStart.contains(text[end])) {
    end++;
  }
  return text.substring(0, end);
}

/// [text] 結尾不能落在行尾的字。
String noLineEndSuffix(String text) {
  var start = text.length;
  while (start > 0 && _noLineEnd.contains(text[start - 1])) {
    start--;
  }
  return text.substring(start);
}

bool startsNoLineStart(String text) => noLineStartPrefix(text).isNotEmpty;

/// 全部都是開括號（`RubyLine` 的標點詞）。
bool isOpeningText(String text) =>
    text.isNotEmpty && noLineEndSuffix(text).length == text.length;

/// 文字引擎會在小書き假名、長音、疊字前換行，用 WORD JOINER（零寬）擋住。
/// 開頭的字預設不加：段落第一個字本來就在行首。[afterText] 表示前面還有同一段落的文字，
/// 開頭也要加，否則中文後面的「{ja:って}」會落在行首。
/// 標點不必加，引擎自己守。顯示用；報讀與比對都用原文。
String withLineStartJoiners(String text, {bool afterText = false}) {
  final joined = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if ((i > 0 || afterText) && _joinedToPrevious.contains(text[i])) {
      joined.write(_wordJoiner);
    }
    joined.write(text[i]);
  }
  return joined.toString();
}

/// 空白剛好超出行寬時，引擎在空白之後換行，WORD JOINER 擋不住，
/// 所以空白後面接不能在行首的字時，換成不換行的空白。
/// [next] 是緊接在這段後面的文字。顯示用；報讀與比對都用原文。
String withNoBreakSpaces(String text, {String next = ''}) {
  final replaced = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    final following = i + 1 < text.length ? text[i + 1] : next;
    final isBeforeNoStart = text[i] == ' ' && startsNoLineStart(following);
    replaced.write(isBeforeNoStart ? _noBreakSpace : text[i]);
  }
  return replaced.toString();
}

/// 排成一列的一小段文字。
@immutable
final class KinsokuAtom {
  const KinsokuAtom(this.text, {this.isBox = false, this.isFixed = false});

  final String text;

  /// 畫成盒子，可以收相鄰的字。
  final bool isBox;

  /// 文字不能被切走（有 ruby 的底字）。
  final bool isFixed;
}

/// 從第 [atom] 段移進盒子的字。
typedef KinsokuMove = ({int atom, String text});

/// 一段切完的結果。
@immutable
final class KinsokuCut {
  const KinsokuCut({
    required this.body,
    required this.tail,
    required this.leading,
    required this.trailing,
  });

  /// 留在原位的文字。
  final String body;

  /// 被後一個盒子拿走的結尾（報讀時仍算這段的文字）。
  final String tail;

  /// 這個盒子收到、排在底字前後的字。
  final List<KinsokuMove> leading, trailing;
}

/// 每個盒子把後面不能在行首的字、前面不能在行尾的字收進來。
/// 被整段拿走的盒子不再收字；拿完一段還沒遇到別的字時繼續往外拿。
List<KinsokuCut> kinsokuCuts(List<KinsokuAtom> atoms) {
  final bodies = [for (final atom in atoms) atom.text];
  final tails = List.filled(atoms.length, '');
  final trailing = [for (final _ in atoms) <KinsokuMove>[]];
  final leading = [for (final _ in atoms) <KinsokuMove>[]];
  bool isOpenBox(int index) => atoms[index].isBox && bodies[index].isNotEmpty;

  for (var box = 0; box < atoms.length; box++) {
    if (!isOpenBox(box)) continue;
    for (var i = box + 1; i < atoms.length && !atoms[i].isFixed; i++) {
      final head = noLineStartPrefix(bodies[i]);
      if (head.isNotEmpty) trailing[box].add((atom: i, text: head));
      bodies[i] = bodies[i].substring(head.length);
      if (bodies[i].isNotEmpty) break;
    }
  }
  for (var box = 0; box < atoms.length; box++) {
    if (!isOpenBox(box)) continue;
    for (var i = box - 1; i >= 0 && !atoms[i].isFixed; i--) {
      final tail = noLineEndSuffix(bodies[i]);
      if (tail.isNotEmpty) leading[box].insert(0, (atom: i, text: tail));
      bodies[i] = bodies[i].substring(0, bodies[i].length - tail.length);
      tails[i] = tail;
      if (bodies[i].isNotEmpty) break;
    }
  }
  return [
    for (var i = 0; i < atoms.length; i++)
      KinsokuCut(
        body: bodies[i],
        tail: tails[i],
        leading: List.unmodifiable(leading[i]),
        trailing: List.unmodifiable(trailing[i]),
      ),
  ];
}
