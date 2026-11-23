import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/backend/frb/dto.dart';
import '../../core/tts/audio_available.dart';
import '../../core/tts/tts_controller.dart';
import '../../core/tts/tts_engine.dart';
import '../../design/tokens.dart';
import '../../design/widgets/paper_scaffold.dart';
import 'chart/kana_chart_body.dart';
import 'chart/kana_chart_providers.dart';
import 'chart/kana_detail_panel.dart';
import 'chart/kana_static_chart.dart';

const _firstLessonOf = {
  KanaScript.hiragana: 'le.k01',
  KanaScript.katakana: 'le.kk01',
};

/// K1 五十音表（§3.3）：查閱、聽音、看進度。所有格都可點，不影響計畫。
class KanaChartScreen extends ConsumerStatefulWidget {
  const KanaChartScreen({super.key});

  @override
  ConsumerState<KanaChartScreen> createState() => _KanaChartScreenState();
}

class _KanaChartScreenState extends ConsumerState<KanaChartScreen> {
  KanaScript _script = KanaScript.hiragana;
  KanaCellDto? _selected;
  bool _hidden = false;

  KanaScript get _otherScript => _script == KanaScript.hiragana
      ? KanaScript.katakana
      : KanaScript.hiragana;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 被 K2 蓋住或切到別的分頁再回來時，進度可能變了
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _hidden) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshProgress();
      });
    }
    _hidden = !visible;
  }

  void _refreshProgress() {
    ref
      ..invalidate(kanaChartProvider(KanaScript.hiragana))
      ..invalidate(kanaChartProvider(KanaScript.katakana));
    if (_selected case final cell?) ref.invalidate(kanaDetailProvider(cell.id));
  }

  void _onCellTap(KanaCellDto cell) {
    setState(() => _selected = cell);
    if (cell.listenDisabled || !ref.read(audioAvailableProvider)) return;
    final tts = ref.read(ttsControllerProvider.notifier);
    unawaited(
      tts.speak(tts.atUserSpeed(SpeechRequest.fromDto(cell.id, cell.speech))),
    );
  }

  void _onScriptChanged(KanaScript script) {
    if (script == _script) return;
    setState(() {
      _script = script;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final chart = ref.watch(kanaChartProvider(_script));
    // 另一張也訂閱，切換時不必等，也不用再畫一次靜態表
    ref.watch(kanaChartProvider(_otherScript));
    final loaded = chart.value ?? const <KanaGroupDto>[];
    final groups = loaded.isNotEmpty ? loaded : staticKanaChart(_script);
    final untouched = loaded.isNotEmpty && isChartUntouched(loaded);
    final startLesson = untouched && !chart.hasError
        ? _firstLessonOf[_script]
        : null;
    final body = KanaChartBody(
      script: _script,
      groups: groups,
      selectedId: _selected?.id,
      progressFailed: chart.hasError,
      onScriptChanged: _onScriptChanged,
      onCellTap: _onCellTap,
      onRetry: () => ref.invalidate(kanaChartProvider(_script)),
    );
    final content = KanaDetailPanel(cell: _selected, onSelectCell: _onCellTap);
    final actions = KanaPanelActions(
      cell: _selected,
      startLessonId: startLesson,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= PaperLayout.wideBreakpoint;
        return PaperScaffold(
          body: body,
          aside: wide ? _asideColumn(content, actions) : null,
          bottom: wide
              ? null
              : KanaBottomStrip(content: content, actions: actions),
        );
      },
    );
  }

  Widget _asideColumn(Widget content, Widget actions) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [content, actions],
  );
}
