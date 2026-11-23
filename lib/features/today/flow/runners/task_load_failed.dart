import 'package:material_ui/material_ui.dart';

import '../../../../design/tokens.dart';
import '../../../../design/widgets/error_slip.dart';
import '../../../../design/widgets/ink_buttons.dart';

/// 單項載入失敗：可重試，也可略過，其餘任務繼續（§2.3 T2）。
class TaskLoadFailed extends StatelessWidget {
  const TaskLoadFailed({
    required this.error,
    required this.onRetry,
    required this.onSkip,
    super.key,
  });

  final Object error;
  final VoidCallback onRetry, onSkip;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ErrorSlip.fromObject(error, onRetry: onRetry),
      const SizedBox(height: AppSpace.s3),
      SkipItemButton(onPressed: onSkip),
    ],
  );
}
