import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../tokens.dart';
import 'app_text.dart';
import 'ink_buttons.dart';

/// 共通錯誤狀態：友善訊息、重試、複製錯誤資訊（§5.4）。
/// `PanicException` 的技術內容已在 `guardBackend` 去除，這裡只會有摘要。
class ErrorSlip extends StatelessWidget {
  const ErrorSlip({required this.failure, this.onRetry, super.key});

  factory ErrorSlip.fromObject(
    Object error, {
    VoidCallback? onRetry,
    Key? key,
  }) => ErrorSlip(
    failure: error is AppFailure ? error : const UnexpectedFailure(),
    onRetry: onRetry,
    key: key,
  );

  final AppFailure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    final retry = onRetry;
    return Container(
      padding: const EdgeInsets.only(left: AppSpace.s4),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: t.shu, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(liveRegion: true, child: AppText(failure.userMessage)),
          const SizedBox(height: AppSpace.s3),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              if (retry != null) GhostButton(label: '重試', onPressed: retry),
              GhostButton(
                label: '複製錯誤資訊',
                onPressed: () => unawaited(
                  Clipboard.setData(ClipboardData(text: failure.diagnostics)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
