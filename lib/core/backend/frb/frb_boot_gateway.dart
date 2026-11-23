import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:japanese_learn_app/src/rust/api/core.dart' as rust;
import 'package:japanese_learn_app/src/rust/frb_generated.dart';
import 'package:material_ui/material_ui.dart' show immutable;
import 'package:path_provider/path_provider.dart';

import '../../tts/fake_tts_engine.dart';
import '../../tts/flutter_tts_engine.dart';
import '../../tts/spd_say_engine.dart';
import '../../tts/tts_engine.dart';
import '../boot.dart';
import '../failures.dart';
import '../first_run_marker.dart';
import '../local_log.dart';
import 'frb_repositories.dart';
import 'native_library.dart';
import '../repositories.dart';

/// `JLA_TTS=unavailable`：模擬裝置沒有日語語音（testing §8）。
const _noVoice = TtsAvailability(TtsAvailabilityKind.noJapaneseVoice);

const _databaseFile = 'jp_core.db';
const _logFile = 'app.log';

/// 只有 `--dart-define=JLA_TEST_HOOKS=true` 時生效；正式建置永遠是 false。
const _testHooksEnabled = bool.fromEnvironment('JLA_TEST_HOOKS');

/// integration_test 專用的注入：獨立資料目錄、固定時間（testing §8）。
/// 沒有打開 `JLA_TEST_HOOKS` 時整個物件會被忽略，避免誤用在正式流程。
@immutable
final class BootTestOptions {
  const BootTestOptions({
    required this.dataDir,
    this.fixedNowUtc,
    this.utcOffsetMinutes,
  });

  final String dataDir;
  final DateTime? fixedNowUtc;
  final int? utcOffsetMinutes;
}

/// 真實後端的啟動。`RustLib.init` 同一 Isolate 只能一次，重試與重開都不重跑。
final class FrbBootGateway implements BootGateway {
  FrbBootGateway({BootTestOptions? testOptions})
    : _testOptions = _testHooksEnabled ? testOptions : null;

  static bool _rustReady = false;

  final BootTestOptions? _testOptions;
  String? _dbPath;

  Future<String> _databasePath() async {
    final existing = _dbPath;
    if (existing != null) return existing;
    final override =
        _testOptions?.dataDir ??
        (kReleaseMode ? null : Platform.environment['JLA_DATA_DIR']);
    final directory = override ?? (await getApplicationSupportDirectory()).path;
    await Directory(directory).create(recursive: true);
    final path = '$directory/$_databaseFile';
    _dbPath = path;
    LocalLog.ring.attach(File('$directory/$_logFile'));
    return path;
  }

  @override
  Future<BootResult> open() async {
    final dbPath = await _databasePath();
    if (!_rustReady) {
      await guardBackend(
        () => RustLib.init(externalLibrary: _bundledLibrary()),
      );
      _rustReady = true;
    }
    final core = await guardBackend(
      () => rust.AppCore.open(
        config: rust.CoreConfig(
          dbPath: dbPath,
          utcOffsetMinutes:
              _testOptions?.utcOffsetMinutes ??
              DateTime.now().timeZoneOffset.inMinutes,
          fixedNowUtc: _testOptions?.fixedNowUtc,
        ),
      ),
    );
    final repositories = frbRepositories(core);
    final settings = await repositories.settings.load();
    return BootResult(
      repositories: repositories,
      settings: settings,
      onboardingDone: await _hasPlan(repositories),
      ttsEngine: _createEngine(),
      firstRunMarker: FileFirstRunMarker(File(dbPath).parent.path),
    );
  }

  /// Linux 優先用 App 打包的函式庫；null 時交給 FRB 預設流程（native_library.dart）。
  static ExternalLibrary? _bundledLibrary() {
    final path = bundledCoreLibraryPath(
      operatingSystem: Platform.operatingSystem,
      resolvedExecutable: Platform.resolvedExecutable,
      exists: (path) => File(path).existsSync(),
    );
    return path == null ? null : ExternalLibrary.open(path);
  }

  /// `plan_view` 拋 `NoActivePlan` 就是尚未完成引導（§2.2）。
  Future<bool> _hasPlan(BackendRepositories repositories) async {
    try {
      await repositories.plan.view();
      return true;
    } on NoPlanFailure {
      return false;
    }
  }

  TtsEngine _createEngine() {
    const override = String.fromEnvironment('JLA_TTS');
    if (override == 'fake') return FakeTtsEngine();
    if (override == 'unavailable') return FakeTtsEngine(availability: _noVoice);
    if (override == 'spd' || Platform.isLinux) return SpdSayTtsEngine();
    return FlutterTtsEngine(FlutterTts(), isAndroid: Platform.isAndroid);
  }

  @override
  Future<void> resetDatabase() async {
    final path = await _databasePath();
    await guardBackend(() => rust.deleteDatabase(dbPath: path));
  }
}
