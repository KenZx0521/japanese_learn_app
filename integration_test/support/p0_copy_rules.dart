// O7 文案守門（RULINGS O7、flutter-app §3.1）的純文字規則。不依賴 Flutter，
// p0_copy_rules_test.dart 不開 App 就能驗；旅程裡由 journeys.dart 套到畫面文字上。

/// p0 主線的最後一課。
const lastP0Lesson = 30;

/// V3 單字詳情的參考級別標籤（`vocab_labels.dart` 的 `jlptLabelOf`）。
/// 這是單字逐字的標示，不是這一版的範圍宣稱（RULINGS O7 附註）。
const jlptWordLabels = {'參考 N5', '參考 N4', 'N4 以外'};

/// 畫面上的一段文字；[inWordDetail] 表示它在 V3 單字詳情頁上。
typedef ShownText = ({String text, bool inWordDetail});

/// 範圍連接號：「第 31～48 課」「L21-L48」。
const _dash = r'\s*[～〜~\-－–—至到]\s*';

/// 「第 31 課」「第31～48課」「31～48 課」「第 21 至第 31 課」。
final _lessonNumbers = RegExp('(\\d+)(?:$_dash(?:第\\s*)?(\\d+))?\\s*課');

/// 「L31」「L21～L48」「L21～48」；前面是英文字母的不算（不是課號）。
final _lessonCodes = RegExp(
  '(?<![A-Za-z])L\\s?(\\d+)(?:${_dash}L?\\s?(\\d+))?',
);

final _n4 = RegExp(r'[NＮnｎ]\s?[4４]');

/// 全形數字轉半形，「第３１課」與「第 31 課」同樣處理。
String _halfWidthDigits(String text) => text.replaceAllMapped(
  RegExp('[０-９]'),
  (m) => String.fromCharCode(m[0]!.codeUnitAt(0) - 0xFF10 + 0x30),
);

bool _beyondLastLesson(RegExp pattern, String text) =>
    pattern.allMatches(_halfWidthDigits(text)).any((match) {
      final numbers = [match[1], match[2]].whereType<String>().map(int.parse);
      return numbers.any((n) => n > lastP0Lesson);
    });

/// L31 以後的課（課號、「第 N 課」與範圍寫法）與「完整版」都不屬於 p0。
bool claimsBeyondP0(String text) =>
    text.contains('完整版') ||
    _beyondLastLesson(_lessonNumbers, text) ||
    _beyondLastLesson(_lessonCodes, text);

/// 提到 N4 就算宣稱（p0 只宣稱參考 N5），不論出現在哪一句。
bool mentionsN4(String text) => _n4.hasMatch(text);

/// 整段文字就是一個 V3 級別標籤（不是句子裡提到它）。
bool isJlptWordLabel(String text) => jlptWordLabels.contains(text.trim());

/// O7：p0 只宣稱到 L30、參考 N5。不分畫面，沒有豁免。
List<String> p0CopyViolations(Iterable<String> texts) => [
  for (final text in texts)
    if (mentionsN4(text) || claimsBeyondP0(text)) text,
];

/// 畫面版本：只有 V3 單字詳情頁上、整段就是級別標籤的文字豁免 N4 規則。
List<String> shownCopyViolations(Iterable<ShownText> shown) =>
    p0CopyViolations([
      for (final item in shown)
        if (!(item.inWordDetail && isJlptWordLabel(item.text))) item.text,
    ]);

/// 內容字串的 `{ja:…}` 標記要經 MixedText 轉換，畫面上不得原樣出現（flutter-app §7.3）。
List<String> rawMarkupTexts(Iterable<String> texts) => [
  for (final text in texts)
    if (text.contains('{ja:')) text,
];

/// 課的內部 id（`le.k03`、`le.kk02`、`le.l05`）不得露到畫面（裁決 U11）。
final _lessonId = RegExp(r'(?<![A-Za-z.])le\.(?:kk?|l)\d+');

List<String> rawLessonIdTexts(Iterable<String> texts) => [
  for (final text in texts)
    if (_lessonId.hasMatch(text)) text,
];

/// 裁決 U8 統一前的略過文案；統一後是「略過這一項」。
List<String> retiredSkipTexts(Iterable<String> texts) => [
  for (final text in texts)
    if (text.contains('略過這項')) text,
];

final _zeroCards = RegExp(r'(?<!\d)0 張');

/// T1 不列沒有卡的複習（裁決 U5），「0 張」不得出現。
List<String> zeroReviewTexts(Iterable<String> texts) => [
  for (final text in texts)
    if (_zeroCards.hasMatch(text)) text,
];

final _fractionalStudyTime = RegExp(r'今天學了 \d+\.\d+ 分鐘');

/// T3 的學習時間不顯示小數，不到 1 分鐘寫「不到 1 分鐘」（裁決 U6）。
List<String> fractionalStudyTimeTexts(Iterable<String> texts) => [
  for (final text in texts)
    if (_fractionalStudyTime.hasMatch(text)) text,
];
