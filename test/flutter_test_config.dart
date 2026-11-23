import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _fonts = {
  'KleeOneJP': [
    'assets/fonts/KleeOne-Regular.subset.ttf',
    'assets/fonts/KleeOne-SemiBold.subset.ttf',
  ],
  'NotoSansTC': [
    'assets/fonts/NotoSansTC-Regular.subset.ttf',
    'assets/fonts/NotoSansTC-Bold.subset.ttf',
  ],
  'NotoSerifTC': ['assets/fonts/NotoSerifTC-ExtraBold.subset.ttf'],
};

/// 用 FontLoader 載真字型，否則 Ahem 會顯示方塊（§8）。
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final MapEntry(key: family, value: assets) in _fonts.entries) {
    final loader = FontLoader(family);
    for (final asset in assets) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
  await testMain();
}
