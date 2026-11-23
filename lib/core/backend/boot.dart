import 'package:material_ui/material_ui.dart' show immutable;

import '../tts/tts_engine.dart';
import 'first_run_marker.dart';
import 'frb/dto.dart';
import 'repositories.dart';

/// 啟動所需的全部結果（architecture §5.4 的順序）。
@immutable
final class BootResult {
  const BootResult({
    required this.repositories,
    required this.settings,
    required this.onboardingDone,
    required this.ttsEngine,
    required this.firstRunMarker,
  });

  final BackendRepositories repositories;
  final SettingsDto settings;
  final bool onboardingDone;
  final TtsEngine ttsEngine;
  final FirstRunMarker firstRunMarker;
}

/// 啟動步驟的介面，方便測試 DB 打不開時的救援畫面。
/// `open` 失敗拋 `AppFailure`；`resetDatabase` 只呼叫 `delete_database`，不需要 `AppCore`。
abstract interface class BootGateway {
  Future<BootResult> open();
  Future<void> resetDatabase();
}
