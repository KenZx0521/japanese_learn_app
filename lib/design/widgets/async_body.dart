import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'error_slip.dart';
import 'skeleton_lines.dart';

/// 統一處理 loading／error（architecture §5.4）。重試由呼叫端 `ref.invalidate`。
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    required this.value,
    required this.data,
    this.onRetry,
    this.loading,
    super.key,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  /// 預設為延遲 200ms 的三行骨架。
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    loading: () => loading ?? const DelayedReveal(child: SkeletonLines()),
    error: (error, _) => ErrorSlip.fromObject(error, onRetry: onRetry),
  );
}
