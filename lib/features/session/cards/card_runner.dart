import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/backend/frb/dto.dart';
import '../../../core/backend/providers.dart';
import '../../../core/backend/today_view_provider.dart';
import '../../../core/tts/audio_available.dart';
import '../../../design/tokens.dart';
import '../../../design/widgets/app_text.dart';
import '../../../design/widgets/async_body.dart';
import '../../quiz/quiz.dart';

/// 一輪字卡跑完的結果。
@immutable
final class CardRunSummary {
  const CardRunSummary({required this.answered, this.nextDueAt});

  /// 這一輪實際答過的張數；0 表示一開始就沒有到期卡片。
  final int answered;
  final DateTime? nextDueAt;
}

/// [run] 每個 [CardRunner] 一個，T2 的複習結案後馬上進收尾時，
/// 新一輪才不會接到還沒釋放的上一輪 `Done`。
typedef CardRunArgs = ({int? seed, Object run});

final cardNextProvider = AsyncNotifierProvider.autoDispose
    .family<CardNextController, SessionNextDto, CardRunArgs>(
      CardNextController.new,
    );

/// 下一張由 Rust 決定，Dart 不維護佇列（§3.4）。語音探測完成前停在載入，
/// 語音可用性改變時以同 seed 重取（§6.6）。
class CardNextController extends AsyncNotifier<SessionNextDto> {
  CardNextController(this.args);

  final CardRunArgs args;

  @override
  Future<SessionNextDto> build() async {
    if (!ref.watch(audioResolvedProvider)) {
      return Completer<SessionNextDto>().future;
    }
    final audio = ref.watch(audioAvailableProvider);
    final review = ref.watch(reviewRepositoryProvider);
    final seed = args.seed ?? sessionSeed(await _logicalDate());
    return review.next(seed, audio);
  }

  Future<String> _logicalDate() =>
      ref.watch(todayViewProvider.selectAsync((today) => today.logicalDate));

  void advance() => ref.invalidateSelf();
}

/// V4 的字卡回合（§3.4），T2 的複習與收尾共用。
/// 放在高度有限的版面；跑到 `Done` 時呼叫 [onDone]，由呼叫端決定下一步。
class CardRunner extends ConsumerStatefulWidget {
  const CardRunner({required this.onDone, this.seed, super.key});

  final ValueChanged<CardRunSummary> onDone;

  /// T2 傳當日 `session_seed`；null 時由 `today_view` 的 logical date 算。
  final int? seed;

  @override
  ConsumerState<CardRunner> createState() => _CardRunnerState();
}

class _CardRunnerState extends ConsumerState<CardRunner> {
  final Object _run = Object();
  int _answered = 0;
  bool _reported = false;

  CardRunArgs get _args => (seed: widget.seed, run: _run);

  void _onNext(
    AsyncValue<SessionNextDto>? previous,
    AsyncValue<SessionNextDto> next,
  ) {
    if (next.isLoading || _reported) return;
    if (next.value case SessionNextDto_Done(:final nextDueAt)) {
      _reported = true;
      widget.onDone(CardRunSummary(answered: _answered, nextDueAt: nextDueAt));
    }
  }

  void _onFinished(QuizOutcome outcome) {
    // StaleCard 的 outcome 沒有紀錄，不算答過
    _answered += outcome.records.length;
    ref.read(cardNextProvider(_args).notifier).advance();
  }

  @override
  Widget build(BuildContext context) {
    final provider = cardNextProvider(_args);
    ref.listen(provider, _onNext);
    return AsyncBody<SessionNextDto>(
      value: ref.watch(provider),
      onRetry: () => ref.invalidate(provider),
      data: (next) => switch (next) {
        SessionNextDto_Card(:final card) => _CardView(
          card: card,
          onFinished: _onFinished,
        ),
        SessionNextDto_Done() => const SizedBox.shrink(),
      },
    );
  }
}

class _CardView extends StatelessWidget {
  const _CardView({required this.card, required this.onFinished});

  final SessionCardDto card;
  final ValueChanged<QuizOutcome> onFinished;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (card.remainingEstimate > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.s3),
          child: AppText(
            '還有約 ${card.remainingEstimate} 張',
            scale: TypeScale.caption,
            color: AppTokens.of(context).ink.secondary,
          ),
        ),
      Expanded(
        child: QuizSessionView(
          key: ValueKey('${card.cardId}/${card.expectedReps}'),
          questions: [card.question],
          grader: ReviewGrader(expectedReps: card.expectedReps),
          ratingPreviews: card.ratingPreviews,
          expandVocab: true,
          onFinished: onFinished,
        ),
      ),
    ],
  );
}
