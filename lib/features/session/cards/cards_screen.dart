import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/routes.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/back_line.dart';
import '../../../design/widgets/esc_to_leave.dart';
import '../../../design/widgets/paper_scaffold.dart';
import 'card_runner.dart';

/// V4 字卡複習（§3.4）。
class CardsScreen extends StatefulWidget {
  const CardsScreen({super.key});

  @override
  State<CardsScreen> createState() => _CardsScreenState();
}

class _CardsScreenState extends State<CardsScreen> {
  CardRunSummary? _empty;

  void _leave() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(AppRoutes.today);
    }
  }

  void _onDone(CardRunSummary summary) {
    if (summary.answered > 0) {
      GoRouter.maybeOf(context)?.go(AppRoutes.sessionDone);
    } else {
      setState(() => _empty = summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = _empty;
    return EscToLeave(
      onEscape: _leave,
      child: PaperScaffold(
        scrollable: false,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(onLeave: _leave),
            const SizedBox(height: AppSpace.s3),
            Expanded(
              child: empty == null
                  ? CardRunner(onDone: _onDone)
                  : _EmptyCards(nextDueAt: empty.nextDueAt),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onLeave});

  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      BackLine(onBack: onLeave, label: '離開'),
      const Spacer(),
      const EyebrowText('字卡複習'),
    ],
  );
}

class _EmptyCards extends StatelessWidget {
  const _EmptyCards({required this.nextDueAt});

  final DateTime? nextDueAt;

  static String _pad(int value) => value.toString().padLeft(2, '0');

  static String _format(DateTime utc) {
    final local = utc.toLocal();
    return '下次到期：${local.month} 月 ${local.day} 日 '
        '${_pad(local.hour)}:${_pad(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final due = nextDueAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText('目前沒有到期卡片', scale: TypeScale.title),
        if (due != null) ...[
          const SizedBox(height: AppSpace.s2),
          AppText(_format(due), color: AppTokens.of(context).ink.secondary),
        ],
      ],
    );
  }
}
