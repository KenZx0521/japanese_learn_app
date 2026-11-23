import 'package:material_ui/material_ui.dart' show immutable;

import '../../core/backend/frb/dto.dart';

/// O6 誠實預期（§3.1 的表、O7）。`P0a` 只能說「假名與入門七課」。
@immutable
final class ExpectationCopy {
  const ExpectationCopy({
    required this.intro,
    required this.can,
    required this.cannot,
  });

  final String intro, can, cannot;
}

ExpectationCopy expectationCopy(ContentStage stage) => switch (stage) {
  ContentStage.p0A => const ExpectationCopy(
    intro: '這一版涵蓋假名與入門七課。',
    can: '讀出全部假名、聽辨清濁長短；用背好的句型打招呼、自我介紹、約人。',
    cannot: '沒有真人對話對象，口說只有跟讀與選擇回應；語音由裝置合成。',
  ),
  ContentStage.p0 => const ExpectationCopy(
    intro: '本版到 L30，涵蓋參考 N5 範圍。',
    can: '自我介紹、點餐、購物、問路等預期場景能完成簡單問答；開始讀懂朋友間的常體。',
    cannot: '沒有真人對話對象，口說只有跟讀與選擇回應，不評分發音；語音由裝置合成。',
  ),
  ContentStage.full => const ExpectationCopy(
    intro: '完整版到 L48。',
    can: '再加上打電話與基本敬語，熟悉話題能來回幾句。',
    cannot: '無法做到無字幕追劇；流暢度必須靠外部練習，語音由裝置合成。',
  ),
};
