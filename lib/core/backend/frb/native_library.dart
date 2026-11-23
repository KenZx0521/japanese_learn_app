import 'package:japanese_learn_app/src/rust/frb_generated.dart';

/// App 打包的函式庫放在執行檔旁的 `lib/`（Flutter Linux bundle 的慣例）。
const _bundleLibDir = 'lib';

/// Linux 上 App 打包的 `<執行檔目錄>/lib/libjp_core.so`；不存在或其他平台回 null，
/// 交回 FRB 預設的載入流程。
///
/// FRB 2.13 在 Linux 會先找「工作目錄」下的 `rust/target/release/libjp_core.so`
/// （`loader/_io.dart`），在專案根目錄 `flutter run -d linux` 時可能載到
/// 舊的 release 建置，而不是這次 build 打包進 bundle 的那一份。
String? bundledCoreLibraryPath({
  required String operatingSystem,
  required String resolvedExecutable,
  required bool Function(String path) exists,
}) {
  if (operatingSystem != 'linux') return null;
  final slash = resolvedExecutable.lastIndexOf('/');
  if (slash <= 0) return null;
  final stem = RustLib.kDefaultExternalLibraryLoaderConfig.stem;
  final directory = resolvedExecutable.substring(0, slash);
  final path = '$directory/$_bundleLibDir/lib$stem.so';
  return exists(path) ? path : null;
}
