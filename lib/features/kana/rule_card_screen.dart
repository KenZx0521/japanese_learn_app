import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/backend/providers.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/rule_card_view.dart';
import '../../design/widgets/back_line.dart';

final ruleCardProvider = FutureProvider.autoDispose.family<RuleCardDto, String>(
  (ref, id) => ref.watch(kanaRepositoryProvider).ruleCard(id),
);

/// K3 規則卡（§3.3）：促音、長音、助詞讀音、音調的說明、拍感示範與語音示範組。
class RuleCardScreen extends ConsumerWidget {
  const RuleCardScreen({required this.ruleId, super.key});

  final String ruleId;

  void _openDrill(BuildContext context, RuleCardDto card) => unawaited(
    context.push<void>(AppRoutes.sessionDrill(drills: card.drillIds)),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ruleCardProvider(ruleId);
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageBackLink(fallback: AppRoutes.kana),
          const SizedBox(height: AppSpace.s3),
          const EyebrowText('規則卡'),
          const SizedBox(height: AppSpace.s2),
          AsyncBody<RuleCardDto>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            data: (card) => RuleCardView(
              card: card,
              onTest: card.drillIds.isEmpty
                  ? null
                  : () => _openDrill(context, card),
            ),
          ),
        ],
      ),
    );
  }
}
