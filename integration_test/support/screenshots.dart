// 旅程中的截圖：給 `--dart-define=JLA_SHOTS_DIR=<目錄>` 才寫檔，平常執行什麼都不做。
// 截的是真實引擎畫出來的圖層（真字型、真內容），用來人工檢查缺字、溢位、字形。
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'e2e_harness.dart';

const _shotsDir = String.fromEnvironment('JLA_SHOTS_DIR');

/// 放大兩倍光柵化，筆畫細節才看得清楚。
const _pixelRatio = 2.0;

/// 同一個旅程在不同尺寸下各截一份，檔名前綴區分尺寸。
final class ShotBook {
  const ShotBook(this.prefix);

  final String prefix;

  static bool get enabled => _shotsDir.isNotEmpty;

  Future<void> take(WidgetTester tester, String name) async {
    if (!enabled) return;
    // 等轉場與淡入走完
    await tester.pumpFor(const Duration(milliseconds: 400));
    final view = tester.binding.renderViews.first;
    final layer = view.debugLayer;
    if (layer is! OffsetLayer) {
      fail('根圖層不是 OffsetLayer，無法截圖：$layer');
    }
    final bounds = Offset.zero & view.size;
    final file = File('$_shotsDir/${prefix}_$name.png');
    final written = await tester.runAsync(() async {
      final image = await layer.toImage(bounds, pixelRatio: _pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) return false;
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return true;
    });
    expect(written, isTrue, reason: '截圖 ${file.path} 沒有寫出');
  }
}
