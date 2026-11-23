import 'dart:io';

/// §3.1 的 O6 旗標檔：`create_plan` 成功時建立，看完 O6 後刪除。
abstract interface class FirstRunMarker {
  Future<bool> exists();
  Future<void> create();
  Future<void> delete();
}

final class FileFirstRunMarker implements FirstRunMarker {
  FileFirstRunMarker(String directoryPath)
    : _file = File('$directoryPath/pending_expectation');

  final File _file;

  @override
  Future<bool> exists() => _file.exists();

  @override
  Future<void> create() async {
    await _file.create(recursive: true);
  }

  @override
  Future<void> delete() async {
    if (await _file.exists()) await _file.delete();
  }
}
