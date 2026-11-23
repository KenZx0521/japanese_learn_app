// U4：Linux 優先載入 App 打包的 libjp_core.so，不讓 FRB 先撿到工作目錄下的舊建置。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/frb/native_library.dart';

const _executable =
    '/home/me/app/build/linux/x64/debug/bundle/japanese_learn_app';
const _bundled = '/home/me/app/build/linux/x64/debug/bundle/lib/libjp_core.so';

void main() {
  test('Linux 上打包的函式庫存在時用它', () {
    final checked = <String>[];

    final path = bundledCoreLibraryPath(
      operatingSystem: 'linux',
      resolvedExecutable: _executable,
      exists: (path) {
        checked.add(path);
        return true;
      },
    );

    expect(path, _bundled);
    expect(checked, [_bundled]);
  });

  test('Linux 上打包的函式庫不存在時交回 FRB 預設', () {
    final path = bundledCoreLibraryPath(
      operatingSystem: 'linux',
      resolvedExecutable: _executable,
      exists: (_) => false,
    );

    expect(path, isNull);
  });

  test('其他平台一律交回 FRB 預設，不查檔案', () {
    for (final os in ['android', 'ios', 'macos', 'windows']) {
      final path = bundledCoreLibraryPath(
        operatingSystem: os,
        resolvedExecutable: _executable,
        exists: (_) => fail('$os 不該查檔案'),
      );

      expect(path, isNull, reason: os);
    }
  });

  test('執行檔路徑沒有目錄時交回 FRB 預設', () {
    final path = bundledCoreLibraryPath(
      operatingSystem: 'linux',
      resolvedExecutable: 'japanese_learn_app',
      exists: (_) => true,
    );

    expect(path, isNull);
  });
}
