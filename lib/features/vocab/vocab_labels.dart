import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';

/// 課次標示（§3.4），規則同 [lessonNumberLabel]。不認得的 ID 回空字串，呼叫端不顯示。
String lessonLabelOf(String lessonId) {
  final label = lessonNumberLabel(lessonId);
  return label == lessonId ? '' : label;
}

String srsLabelOf(SrsStateLabel state) => switch (state) {
  SrsStateLabel.notStarted => '未學',
  SrsStateLabel.learning => '學習中',
  SrsStateLabel.review => '複習中',
  SrsStateLabel.mastered => '熟練',
};

/// URL 的 `srs` 參數值就是列舉名稱；不認得時視為沒有篩選。
SrsStateLabel? srsFromQuery(String? value) =>
    value == null ? null : SrsStateLabel.values.asNameMap()[value];

/// §3.4：`P0a` 只標 N5，N4 與 Beyond 不顯示（O7）。
/// Beyond 代表參考詞表未收錄，不表示比 N4 難。
String? jlptLabelOf(JlptLevel level, ContentStage stage) {
  if (stage == ContentStage.p0A && level != JlptLevel.n5) return null;
  return switch (level) {
    JlptLevel.n5 => '參考 N5',
    JlptLevel.n4 => '參考 N4',
    JlptLevel.beyond => '未列入參考詞表',
  };
}

String? useLevelLabelOf(UseLevelDto level) => switch (level) {
  UseLevelDto.safe => null,
  UseLevelDto.friendsOnly => '非正式用語',
  UseLevelDto.recognizeOnly => '聽懂就好',
};

String transitivityLabelOf(TransitivityDto trans) => switch (trans) {
  TransitivityDto.transitive => '他動詞',
  TransitivityDto.intransitive => '自動詞',
  TransitivityDto.both => '自他兩用',
};
