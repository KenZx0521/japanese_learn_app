import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/course_groups.dart';
import '../../core/backend/frb/dto.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import 'grammar_list_groups.dart';
import 'grammar_providers.dart';

/// G1 文法列表（§3.5）：依階段分組，頂部搜尋框的內容寫進網址（`?q=`）。
class GrammarListScreen extends ConsumerStatefulWidget {
  const GrammarListScreen({this.query, super.key});

  final String? query;

  @override
  ConsumerState<GrammarListScreen> createState() => _GrammarListScreenState();
}

class _GrammarListScreenState extends ConsumerState<GrammarListScreen> {
  static const _debounce = Duration(milliseconds: 200);

  late final TextEditingController _controller = TextEditingController(
    text: widget.query ?? '',
  );
  late String _sent = _normalized(widget.query);
  Timer? _timer;

  /// 換搜尋字時先留著上一批，查詢期間畫面不閃空白。
  List<StageGroup<GrammarSummaryDto>>? _lastGroups;

  static String _normalized(String? query) => query?.trim() ?? '';

  String? get _activeQuery {
    final query = _normalized(widget.query);
    return query.isEmpty ? null : query;
  }

  @override
  void didUpdateWidget(GrammarListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有外部導覽才覆寫輸入框，否則會打斷輸入中的注音組字
    final incoming = _normalized(widget.query);
    if (incoming != _sent) {
      _sent = incoming;
      _controller.text = incoming;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _timer?.cancel();
    _timer = Timer(_debounce, () => _commit(text));
  }

  void _commit(String text) {
    _timer?.cancel();
    final query = text.trim();
    if (!mounted || query == _sent) return;
    _sent = query;
    context.go(AppRoutes.grammar(query: query.isEmpty ? null : query));
  }

  @override
  Widget build(BuildContext context) {
    final query = _activeQuery;
    final provider = grammarListProvider(query);
    final last = _lastGroups;
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageBackLink(fallback: AppRoutes.learn),
          const AppText('文法', scale: TypeScale.displayM),
          const SizedBox(height: AppSpace.s4),
          _SearchField(
            controller: _controller,
            onChanged: _onChanged,
            onSubmitted: _commit,
          ),
          const SizedBox(height: AppSpace.s6),
          AsyncBody<List<StageGroup<GrammarSummaryDto>>>(
            value: ref.watch(provider),
            onRetry: () => ref.invalidate(provider),
            loading: last == null ? null : GrammarListGroups(groups: last),
            data: (groups) {
              _lastGroups = groups;
              return groups.isEmpty
                  ? _EmptyHint(searching: query != null)
                  : GrammarListGroups(groups: groups);
            },
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    // 比照 V1 的搜尋框：只有底線，不用填色方框
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      cursorColor: t.ai,
      style: TypeScale.body.style(t.ink.primary),
      decoration: InputDecoration(
        isDense: true,
        filled: false,
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.line.strong, width: 1.5),
        ),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(color: t.ai, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.s3),
        hintText: '搜尋：中文或假名',
        hintStyle: TypeScale.body.style(t.ink.tertiary),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: AppText(
      searching ? '找不到，試試中文或假名' : '這一版還沒有文法點',
      color: AppTokens.of(context).ink.secondary,
    ),
  );
}
