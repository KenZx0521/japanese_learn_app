import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:material_ui/material_ui.dart';

import '../core/backend/failures.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/widgets/app_text.dart';
import '../design/widgets/ink_buttons.dart';
import '../design/widgets/paper_scaffold.dart';

const _zhTw = Locale('zh', 'TW');

/// 資料庫打不開時的救援畫面（§5.4）：重試、複製資訊、兩段式確認後重設資料。
class BootErrorApp extends StatelessWidget {
  const BootErrorApp({
    required this.failure,
    required this.onRetry,
    required this.onResetData,
    super.key,
  });

  final AppFailure failure;
  final Future<void> Function() onRetry;
  final Future<void> Function() onResetData;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: _zhTw,
    supportedLocales: const [_zhTw, jaLocale],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: buildTheme(AppTokens.light),
    darkTheme: buildTheme(AppTokens.dark),
    home: _BootErrorScreen(
      failure: failure,
      onRetry: onRetry,
      onResetData: onResetData,
    ),
  );
}

class _BootErrorScreen extends StatefulWidget {
  const _BootErrorScreen({
    required this.failure,
    required this.onRetry,
    required this.onResetData,
  });

  final AppFailure failure;
  final Future<void> Function() onRetry;
  final Future<void> Function() onResetData;

  @override
  State<_BootErrorScreen> createState() => _BootErrorScreenState();
}

class _BootErrorScreenState extends State<_BootErrorScreen> {
  bool _confirmingReset = false;
  bool _busy = false;
  String? _resetError;

  Future<void> _retry() async {
    setState(() => _busy = true);
    await widget.onRetry();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _resetError = null;
    });
    try {
      await widget.onResetData();
    } on AppFailure catch (failure) {
      if (mounted) setState(() => _resetError = failure.userMessage);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('沒辦法開啟學習資料', scale: TypeScale.title),
          const SizedBox(height: AppSpace.s3),
          AppText(widget.failure.userMessage),
          const SizedBox(height: AppSpace.s5),
          Wrap(
            spacing: AppSpace.s2,
            runSpacing: AppSpace.s2,
            children: [
              InkButton(label: '重試', onPressed: _busy ? null : _retry),
              GhostButton(
                label: '複製錯誤資訊',
                onPressed: () => unawaited(
                  Clipboard.setData(
                    ClipboardData(text: widget.failure.diagnostics),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s7),
          if (_resetError != null) ...[
            AppText(_resetError!, color: t.shu),
            const SizedBox(height: AppSpace.s3),
          ],
          if (_confirmingReset)
            _resetConfirmation()
          else
            GhostButton(
              label: '重設資料',
              onPressed: () => setState(() => _confirmingReset = true),
            ),
        ],
      ),
    );
  }

  Widget _resetConfirmation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText('確定要刪除所有學習進度嗎？這個動作無法復原。'),
      const SizedBox(height: AppSpace.s3),
      Wrap(
        spacing: AppSpace.s2,
        runSpacing: AppSpace.s2,
        children: [
          ShuButton(label: '刪除並重新開始', onPressed: _busy ? null : _reset),
          GhostButton(
            label: '先不要',
            onPressed: () => setState(() => _confirmingReset = false),
          ),
        ],
      ),
    ],
  );
}
