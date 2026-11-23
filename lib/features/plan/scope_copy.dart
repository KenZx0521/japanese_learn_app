import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';

// 依 content_stage 宣稱的範圍只寫在這裡（§3.1 O7），測試逐字檢查。
// p0a 不得提及 N4；p0 不得宣稱 N4 或 L31 以後的內容（課綱 §1.3）。

@immutable
final class ScopeGoal {
  const ScopeGoal(this.goal, this.reach, this.limit);
  final String goal;

  /// 課綱 §1.3 該版本欄的實際狀態。
  final String reach;

  /// 課綱 §1.3「做不到的部分」。
  final String limit;
}

@immutable
final class ScopeCopy {
  const ScopeCopy({
    required this.opening,
    required this.canDo,
    required this.cannotDo,
    this.goals = const [],
    this.references = const [],
    this.notCovered,
  });

  /// O6 與 P2 的開頭。
  final String opening;
  final String canDo;
  final String cannotDo;
  final List<ScopeGoal> goals;

  /// 課綱 §1.2 的參考基準。
  final List<String> references;
  final String? notCovered;
}

const _p0aCopy = ScopeCopy(
  opening: '這一版涵蓋假名與入門七課。',
  canDo: '讀出全部假名、聽辨清濁長短；用背好的句型打招呼、自我介紹、約人',
  cannotDo: '沒有真人對話對象，口說只有跟讀與選擇回應；語音由裝置合成',
);

const _speakingLimit = 'App 沒有真人對話對象，口說只有跟讀與選擇回應，不評分發音。流暢度必須靠外部練習';
const _noOfficialList = 'JLPT 自 2010 年改制後沒有官方單字與文法清單，本 App 標示的級別只是參考，不是官方資料。';
const _notCovered = '明確不做：漢字手寫課程、自由作文批改、口說評分、N3 以上文法、真實影音素材。';

const _p0Copy = ScopeCopy(
  opening: '本版到 L30，涵蓋參考 N5 範圍。',
  canDo: '在自我介紹、點餐、購物、問路、看診等預期場景完成簡單問答；開始讀懂朋友間的常體',
  cannotDo: _speakingLimit,
  goals: [
    ScopeGoal(
      '日常對話',
      '自我介紹、點餐、購物、問路、看診等預期場景能完成簡單問答；開始讀懂朋友間的常體',
      _speakingLimit,
    ),
    ScopeGoal('JLPT', '涵蓋參考 N5 範圍', '不保證通過測驗，閱讀與聽力仍需額外輸入'),
  ],
  references: [
    'JLPT 自 2025 年 12 月的測驗起，在合格者的成績單標示 CEFR 參考：N5 總分 80 以上為 A1。',
    _noOfficialList,
    '舊制規格常被引用的數字：4 級（約當 N5）約 800 字、100 漢字、學習約 150 小時。學習時數本身也是估計值。',
  ],
  notCovered: _notCovered,
);

const _fullCopy = ScopeCopy(
  opening: '完整版到 L48。',
  canDo: '在預期場景之外，加上打電話與基本敬語；熟悉話題能來回幾句',
  cannotDo: _speakingLimit,
  goals: [
    ScopeGoal('日常對話', '再加上打電話與基本敬語；熟悉話題能來回幾句', _speakingLimit),
    ScopeGoal(
      'JLPT',
      '主線覆蓋 N5 全部與 N4 主要句型',
      '完整版主線依方案約 110–165 小時，低於 N4 常見的約 300 小時估計。不保證通過 N4，閱讀與聽力仍需額外輸入',
    ),
  ],
  references: [
    'JLPT 自 2025 年 12 月的測驗起，在合格者的成績單標示 CEFR 參考：N5 總分 80 以上為 A1，N4 總分 90 以上為 A2。',
    _noOfficialList,
    '舊制規格常被引用的數字：4 級（約當 N5）約 800 字、100 漢字、學習約 150 小時；'
        '3 級（約當 N4）約 1,500 字、300 漢字、學習約 300 小時。學習時數本身也是估計值。',
  ],
  notCovered: _notCovered,
);

ScopeCopy scopeCopyOf(ContentStage stage) => switch (stage) {
  ContentStage.p0A => _p0aCopy,
  ContentStage.p0 => _p0Copy,
  ContentStage.full => _fullCopy,
};

/// §3.8 文案表。[isoDate] 為 `main_forecast_end`；階段還沒載入（O4）時只說日期。
String forecastLine(ContentStage? stage, String isoDate) {
  final date = monthDayOf(isoDate);
  return switch (stage) {
    ContentStage.p0A => '假名與入門七課約在 $date 完成（粗估）',
    ContentStage.p0 => '本版到 L30，約在 $date 完成（粗估）',
    ContentStage.full => '完整版到 L48，約在 $date 完成（粗估）',
    null => '約在 $date 完成（粗估）',
  };
}

const voiceLimitCopy = '語音由裝置合成，音調可能不完全正確，也沒有真人的情緒與語速。';

String monthDayOf(String isoDate) {
  final date = DateTime.parse(isoDate);
  return '${date.month}/${date.day}';
}

String isoDateOf(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// 換日時間之前仍算前一天，與 Rust 的 logical_date 同規則（rust-core §2）。
String logicalDateOf(DateTime now, int rolloverHour) =>
    isoDateOf(now.subtract(Duration(hours: rolloverHour)));

int daysBetween(String fromIso, String toIso) =>
    DateTime.parse(toIso).difference(DateTime.parse(fromIso)).inDays;

final _lessonId = RegExp(r'^le\.(kk|k|l)(\d+)$');

/// `le.k03`→「假名 第 3 課」，`le.kk02`→「片假名 第 2 課」，`le.l07`→「第 7 課」。
String? lessonOrdinalOf(String lessonId) {
  final match = _lessonId.firstMatch(lessonId);
  if (match == null) return null;
  final number = int.parse(match.group(2)!);
  return switch (match.group(1)) {
    'k' => '假名 第 $number 課',
    'kk' => '片假名 第 $number 課',
    _ => '第 $number 課',
  };
}
