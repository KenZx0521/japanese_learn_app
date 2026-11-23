import 'package:material_ui/material_ui.dart';

import 'steps/level_step.dart';
import 'steps/time_step.dart';
import 'steps/voice_step.dart';
import 'steps/welcome_step.dart';

/// O1、O3–O5（§3.1）。步驟名就是路徑：`/welcome`、`/welcome/o3` … `/welcome/o5`。
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({this.step, super.key});

  final String? step;

  @override
  Widget build(BuildContext context) => switch (step) {
    'o3' => const LevelStep(),
    'o4' => const TimeStep(),
    'o5' => const VoiceStep(),
    _ => const WelcomeStep(),
  };
}
