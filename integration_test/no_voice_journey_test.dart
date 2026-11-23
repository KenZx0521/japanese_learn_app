// J7 語音不可用：用 `--dart-define=JLA_TTS=unavailable` 執行（見 integration_test/README.md）。
// 無聲模式要能完成今日任務，不能卡死（設計審查的阻斷級風險）。
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';

import 'support/e2e_harness.dart';
import 'support/journeys.dart';
import 'support/study_bot.dart';

const _ttsMode = String.fromEnvironment('JLA_TTS');
const _days = 3;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('J7 語音不可用：O5 改無聲，今日任務能跑完且不出聽力題', (tester) async {
    final app = E2eApp(tester, dataDir: await E2eApp.newDataDir());
    await app.boot();
    final bot = StudyBot(tester);

    await onboardFromZero(tester, silent: true);
    await runToDone(bot);
    await backToTodayStamped(tester);

    for (var day = 2; day <= _days; day++) {
      await app.restart(advance: const Duration(days: 1));
      final view = await app.read(todayRepositoryProvider).today(false);
      expect(
        view.tasks.whereType<TaskDto_Listen>(),
        isEmpty,
        reason: '第 $day 天',
      );
      await studyToday(tester, bot);
    }

    bot.expectAllCorrect();
    expect(
      bot.answered.where(
        (a) =>
            a.type == QuestionType.kanaListen ||
            a.type == QuestionType.vocabListen ||
            a.type == QuestionType.listenMeaning,
      ),
      isEmpty,
      reason: '無聲模式不出聽力題',
    );
    final settings = await app.read(settingsRepositoryProvider).load();
    expect(settings.silentMode, isTrue);
  }, skip: _ttsMode != 'unavailable');
}
