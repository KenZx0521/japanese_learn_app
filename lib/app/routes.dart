/// 路由路徑（§2.2）。畫面之間的跳轉只經過這裡，features 不互相 import。
abstract final class AppRoutes {
  static const welcome = '/welcome';
  static const placement = '/welcome/placement';
  static String welcomeStep(String step) => '/welcome/$step';

  static const today = '/today';
  static const learn = '/learn';
  static const listen = '/listen';
  static const plan = '/plan';
  static const settings = '/settings';

  static String sessionToday({String? start}) =>
      _withQuery('/session/today', {'start': start});
  static const sessionDone = '/session/done';
  static const sessionExpectation = '/session/expectation';
  static const sessionCards = '/session/cards';

  static String sessionDrill({
    String? lesson,
    String? target,
    List<String>? drills,
  }) => _withQuery('/session/drill', {
    'lesson': lesson,
    'target': target,
    'drills': drills?.join(','),
  });

  static String sessionCheckpoint(String milestoneId) =>
      '/session/checkpoint/${Uri.encodeComponent(milestoneId)}';
  static String sessionDialogue(String dialogueId) =>
      '/session/dialogue/${Uri.encodeComponent(dialogueId)}';

  static String lesson(String id) => '/learn/lesson/${Uri.encodeComponent(id)}';
  static const kana = '/learn/kana';
  static String kanaSession(String lessonId) =>
      '/learn/kana/session/${Uri.encodeComponent(lessonId)}';
  static String kanaRule(String ruleId) =>
      '/learn/kana/rule/${Uri.encodeComponent(ruleId)}';

  static const vocab = '/learn/vocab';
  static String vocabList({
    String? topic,
    bool? onlyIntroduced,
    bool? onlyStarred,
    String? srs,
  }) => _withQuery('/learn/vocab/list', {
    'topic': topic,
    'only_introduced': onlyIntroduced?.toString(),
    'only_starred': onlyStarred?.toString(),
    'srs': srs,
  });
  static String vocabWord(String id) =>
      '/learn/vocab/word/${Uri.encodeComponent(id)}';

  static String grammar({String? query}) =>
      _withQuery('/learn/grammar', {'q': query});
  static String grammarPoint(String id) =>
      '/learn/grammar/${Uri.encodeComponent(id)}';
  static String notes({String? kind}) =>
      _withQuery('/learn/notes', {'kind': kind});
  static const drills = '/learn/drills';

  static const sounds = '/listen/sounds';
  static const dialogues = '/listen/dialogues';

  static const planAbout = '/plan/about-level';
  static const settingsVoice = '/settings/voice';
  static const settingsLicenses = '/settings/licenses';

  /// §2.2：`start` 含 `:`，一律編碼。空值的參數不輸出。
  static String _withQuery(String path, Map<String, String?> params) {
    final entries = [
      for (final MapEntry(:key, :value) in params.entries)
        if (value != null) '$key=${Uri.encodeQueryComponent(value)}',
    ];
    return entries.isEmpty ? path : '$path?${entries.join('&')}';
  }
}
