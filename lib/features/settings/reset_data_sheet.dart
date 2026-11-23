import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/failures.dart';
import '../../core/backend/local_log.dart';
import '../../core/backend/providers.dart';
import '../../core/settings/settings_controller.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/ink_buttons.dart';

const resetConfirmWord = '清除';

enum _ResetStep { warn, confirm }

/// §3.9：兩段式確認，第二段要輸入「清除」。回傳 true 表示已清除。
class ResetDataSheet extends ConsumerStatefulWidget {
  const ResetDataSheet({super.key});

  @override
  ConsumerState<ResetDataSheet> createState() => _ResetDataSheetState();
}

class _ResetDataSheetState extends ConsumerState<ResetDataSheet> {
  final _controller = TextEditingController();
  _ResetStep _step = _ResetStep.warn;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSubmit => !_busy && _controller.text.trim() == resetConfirmWord;

  /// `Storage` 時連線已換成記憶體庫，要重新啟動才會建新檔（rust-core §5.5）。
  String _messageOf(AppFailure failure) =>
      failure is StorageFailure ? '清除沒有完成，請重新啟動 App。' : '清除沒有完成，資料還在，請再試一次。';

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(settingsRepositoryProvider).resetAll();
    } on AppFailure catch (failure, stack) {
      logLocal(failure, stack);
      if (mounted) {
        setState(() {
          _busy = false;
          _error = _messageOf(failure);
        });
      }
      return;
    }
    if (!mounted) return;
    ref.invalidate(settingsProvider);
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: switch (_step) {
      _ResetStep.warn => _warn(),
      _ResetStep.confirm => _confirm(),
    },
  );

  Widget _warn() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('清除全部進度？', scale: TypeScale.title),
      const SizedBox(height: AppSpace.s3),
      const AppText('學過的假名、單字、文法、複習紀錄與計畫都會刪除，設定也會回到預設，無法復原。'),
      const SizedBox(height: AppSpace.s5),
      GhostButton(
        label: '繼續',
        expanded: true,
        onPressed: () => setState(() => _step = _ResetStep.confirm),
      ),
      const SizedBox(height: AppSpace.s2),
      InkButton(
        label: '先不要',
        expanded: true,
        autofocus: true,
        onPressed: () => Navigator.of(context).pop(false),
      ),
    ],
  );

  Widget _confirm() {
    final error = _error;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('再確認一次', scale: TypeScale.title),
        const SizedBox(height: AppSpace.s3),
        const AppText('請在下面輸入「$resetConfirmWord」兩個字。'),
        const SizedBox(height: AppSpace.s3),
        TextField(
          controller: _controller,
          autocorrect: false,
          enabled: !_busy,
          decoration: const InputDecoration(hintText: resetConfirmWord),
          style: TypeScale.body.style(AppTokens.of(context).ink.primary),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppSpace.s4),
        if (error != null) ...[
          Semantics(
            liveRegion: true,
            child: AppText(error, color: AppTokens.of(context).shu),
          ),
          const SizedBox(height: AppSpace.s3),
        ],
        ShuButton(
          label: '清除全部進度',
          expanded: true,
          onPressed: _canSubmit ? () => unawaited(_submit()) : null,
        ),
      ],
    );
  }
}
