import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../core/text/ja_text.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/genko_grid.dart';
import '../../../design/widgets/ink_buttons.dart';
import '../onboarding_frame.dart';

/// O1 歡迎：一個按鈕，第一屏就是稿紙與假名。
class WelcomeStep extends StatelessWidget {
  const WelcomeStep({super.key});

  static const _firstRow = ['あ', 'い', 'う', 'え', 'お'];

  /// 寬螢幕維持小方格，不撐成空盪的大格子。
  static const _maxCell = 88.0;

  @override
  Widget build(BuildContext context) => OnboardingFrame(
    step: 1,
    title: '從五十音開始。',
    titleScale: TypeScale.displayL,
    bottom: InkButton(
      label: '開始',
      expanded: true,
      autofocus: true,
      onPressed: () => unawaited(context.push(AppRoutes.welcomeStep('o3'))),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('全程離線，資料只存在這台裝置。', color: AppTokens.of(context).ink.secondary),
        const SizedBox(height: AppSpace.s6),
        ExcludeSemantics(
          child: GenkoGrid(
            maxCell: _maxCell,
            children: [for (final kana in _firstRow) _KanaInCell(kana)],
          ),
        ),
      ],
    ),
  );
}

/// §4.2：假名格內字級＝格寬×0.5，不隨字級縮放。
class _KanaInCell extends StatelessWidget {
  const _KanaInCell(this.kana);

  final String kana;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => Center(
      child: JaText(
        kana,
        fontSize: box.maxWidth / 2,
        height: 1,
        textScaler: TextScaler.noScaling,
      ),
    ),
  );
}
