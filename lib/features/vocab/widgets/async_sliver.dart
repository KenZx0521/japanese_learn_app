import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../design/widgets/error_slip.dart';
import '../../../design/widgets/skeleton_lines.dart';

/// `AsyncBody` 的 sliver 版：資料區要在 `CustomScrollView` 內虛擬化時用。
Widget asyncSliver<T>(
  AsyncValue<T> value, {
  required Widget Function(T data) data,
  VoidCallback? onRetry,
}) => value.when(
  data: data,
  loading: () =>
      const SliverToBoxAdapter(child: DelayedReveal(child: SkeletonLines())),
  error: (error, _) =>
      SliverToBoxAdapter(child: ErrorSlip.fromObject(error, onRetry: onRetry)),
);
