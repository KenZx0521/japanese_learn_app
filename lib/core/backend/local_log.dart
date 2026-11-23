import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:material_ui/material_ui.dart' show immutable;

/// 本機環狀日誌（≤256KB），只寫到本機，不上傳任何資料（architecture §5.4）。
final class RingLog {
  RingLog({this.maxBytes = 256 * 1024});

  final int maxBytes;
  final Queue<String> _lines = Queue<String>();
  int _bytes = 0;
  File? _file;
  Future<void> _pending = Future<void>.value();

  void attach(File file) => _file = file;

  void add(String line) {
    final entry = line.length > 2048 ? line.substring(0, 2048) : line;
    _lines.addLast(entry);
    _bytes += utf8.encode(entry).length + 1;
    while (_bytes > maxBytes && _lines.isNotEmpty) {
      _bytes -= utf8.encode(_lines.removeFirst()).length + 1;
    }
    _pending = _pending.then((_) => _flush());
  }

  String snapshot() => _lines.join('\n');

  Future<void> _flush() async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString(snapshot());
    } on FileSystemException {
      // 寫不進日誌時沒有其他地方可以回報，記憶體內的內容仍可複製
    }
  }
}

@immutable
final class LocalLog {
  const LocalLog._();

  static final RingLog ring = RingLog();
}

void logLocal(Object error, StackTrace? stack) {
  final when = DateTime.now().toUtc().toIso8601String();
  LocalLog.ring.add('[$when] ${error.runtimeType}: $error\n${stack ?? ''}');
}
