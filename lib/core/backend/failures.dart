import 'package:material_ui/material_ui.dart' show immutable;

import 'frb/dto.dart';
import 'local_log.dart';

/// 給使用者看的失敗。`detail` 只進日誌與「複製錯誤資訊」，不顯示（§5.4）。
@immutable
sealed class AppFailure implements Exception {
  const AppFailure({this.detail});

  final String? detail;
  String get userMessage;

  String get diagnostics =>
      detail == null ? '$runtimeType' : '$runtimeType: $detail';
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.detail});
  @override
  String get userMessage => '找不到這項內容，請回上一頁再試一次。';
}

final class InvalidInputFailure extends AppFailure {
  const InvalidInputFailure({super.detail});
  @override
  String get userMessage => '這個操作現在無法完成，請確認內容後再試一次。';
}

final class NoPlanFailure extends AppFailure {
  const NoPlanFailure({super.detail});
  @override
  String get userMessage => '還沒有建立學習計畫，先完成新手引導吧。';
}

final class ContentFailure extends AppFailure {
  const ContentFailure({super.detail});
  @override
  String get userMessage => '學習內容讀取失敗，請重新開啟 App。';
}

final class StorageFailure extends AppFailure {
  const StorageFailure({super.detail});
  @override
  String get userMessage => '資料暫時寫不進去，學過的進度不會遺失，請再試一次。';
}

/// 連點造成，畫面不顯示，直接取下一題（§5.4）。
final class StaleCardFailure extends AppFailure {
  const StaleCardFailure({super.detail});
  @override
  String get userMessage => '這一題已經答過了。';
}

final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure({super.detail});
  @override
  String get userMessage => '出了一點問題，請再試一次。';
}

AppFailure mapCoreError(CoreError error) => switch (error) {
  CoreError_NotFound(:final entity, :final id) => NotFoundFailure(
    detail: '$entity $id',
  ),
  CoreError_InvalidInput(:final field, :final reason) => InvalidInputFailure(
    detail: '$field: $reason',
  ),
  CoreError_StaleCard(:final cardId) => StaleCardFailure(detail: cardId),
  CoreError_NoActivePlan() => const NoPlanFailure(),
  CoreError_ContentCorrupt(:final file, :final detail) => ContentFailure(
    detail: '$file: $detail',
  ),
  CoreError_MigrationFailed(:final fromVersion, :final message) =>
    ContentFailure(detail: 'migration from $fromVersion: $message'),
  CoreError_Storage(:final message) => StorageFailure(detail: message),
  CoreError_Internal(:final message) => UnexpectedFailure(detail: message),
};

/// 所有 FRB 呼叫都經過這裡，例外在邊界轉成 [AppFailure]。
/// `PanicException` 的訊息含 backtrace，只寫日誌，不帶進 failure。
Future<T> guardBackend<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on CoreError catch (error, stack) {
    // NoActivePlan 與 StaleCard 是正常流程，不是錯誤
    final expected =
        error is CoreError_NoActivePlan || error is CoreError_StaleCard;
    if (!expected) logLocal(error, stack);
    throw mapCoreError(error);
  } on AppFailure {
    rethrow;
  } on Exception catch (error, stack) {
    logLocal(error, stack);
    throw const UnexpectedFailure();
  }
}
