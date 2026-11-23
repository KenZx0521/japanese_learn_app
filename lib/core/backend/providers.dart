import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:material_ui/material_ui.dart' show ValueNotifier;

import 'first_run_marker.dart';
import 'repositories.dart';

// 介面的 provider 預設 throw，bootstrap 與測試用 `overrideWithValue`（architecture §5.2）。
Never _notInjected(String name) =>
    throw UnimplementedError('$name 尚未注入：bootstrap 或 pumpApp 要 override');

final todayRepositoryProvider = Provider<TodayRepository>(
  (ref) => _notInjected('TodayRepository'),
);
final courseRepositoryProvider = Provider<CourseRepository>(
  (ref) => _notInjected('CourseRepository'),
);
final kanaRepositoryProvider = Provider<KanaRepository>(
  (ref) => _notInjected('KanaRepository'),
);
final vocabRepositoryProvider = Provider<VocabRepository>(
  (ref) => _notInjected('VocabRepository'),
);
final reviewRepositoryProvider = Provider<ReviewRepository>(
  (ref) => _notInjected('ReviewRepository'),
);
final grammarRepositoryProvider = Provider<GrammarRepository>(
  (ref) => _notInjected('GrammarRepository'),
);
final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => _notInjected('NoteRepository'),
);
final drillRepositoryProvider = Provider<DrillRepository>(
  (ref) => _notInjected('DrillRepository'),
);
final listeningRepositoryProvider = Provider<ListeningRepository>(
  (ref) => _notInjected('ListeningRepository'),
);
final planRepositoryProvider = Provider<PlanRepository>(
  (ref) => _notInjected('PlanRepository'),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => _notInjected('SettingsRepository'),
);
final contentPeekRepositoryProvider = Provider<ContentPeekRepository>(
  (ref) => _notInjected('ContentPeekRepository'),
);
final clockRepositoryProvider = Provider<ClockRepository>(
  (ref) => _notInjected('ClockRepository'),
);
final textToolsProvider = Provider<TextTools>(
  (ref) => _notInjected('TextTools'),
);
final firstRunMarkerProvider = Provider<FirstRunMarker>(
  (ref) => _notInjected('FirstRunMarker'),
);

/// 尚未完成引導時路由一律導向 `/welcome`；`create_plan` 成功後設為 true。
final onboardingDoneProvider = Provider<ValueNotifier<bool>>(
  (ref) => _notInjected('onboardingDone'),
);

/// `onResume` 每次重新探測語音完成後加一。取今日資料的 provider 要 watch 它。
final resumeTickProvider = NotifierProvider<ResumeTick, int>(ResumeTick.new);

class ResumeTick extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

/// 把一組 repository 轉成 `ProviderScope.overrides`。
List<Override> repositoryOverrides(BackendRepositories r) => [
  todayRepositoryProvider.overrideWithValue(r.today),
  courseRepositoryProvider.overrideWithValue(r.course),
  kanaRepositoryProvider.overrideWithValue(r.kana),
  vocabRepositoryProvider.overrideWithValue(r.vocab),
  reviewRepositoryProvider.overrideWithValue(r.review),
  grammarRepositoryProvider.overrideWithValue(r.grammar),
  noteRepositoryProvider.overrideWithValue(r.notes),
  drillRepositoryProvider.overrideWithValue(r.drills),
  listeningRepositoryProvider.overrideWithValue(r.listening),
  planRepositoryProvider.overrideWithValue(r.plan),
  settingsRepositoryProvider.overrideWithValue(r.settings),
  contentPeekRepositoryProvider.overrideWithValue(r.peek),
  clockRepositoryProvider.overrideWithValue(r.clock),
  textToolsProvider.overrideWithValue(r.textTools),
];

/// `session_seed`：對 logical_date 算 32 位元 FNV-1a，同一天重開題目相同（§5.2）。
/// 不得用 `String.hashCode`，它不保證跨執行穩定。
int sessionSeed(String logicalDate) {
  const offsetBasis = 0x811c9dc5;
  const prime = 0x01000193;
  var hash = offsetBasis;
  for (final unit in logicalDate.codeUnits) {
    hash ^= unit;
    hash = (hash * prime) & 0xffffffff;
  }
  return hash;
}
