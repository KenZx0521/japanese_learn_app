import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';
import 'vocab_providers.dart';
import 'widgets/async_sliver.dart';
import 'widgets/vocab_row.dart';
import 'widgets/vocab_search_field.dart';

/// V1 主題與搜尋（§3.4）。
class VocabTopicsScreen extends ConsumerStatefulWidget {
  const VocabTopicsScreen({super.key});

  @override
  ConsumerState<VocabTopicsScreen> createState() => _VocabTopicsScreenState();
}

class _VocabTopicsScreenState extends ConsumerState<VocabTopicsScreen> {
  static const _debounce = Duration(milliseconds: 200);

  final _controller = TextEditingController();
  Timer? _timer;
  String _latestInput = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onInput);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// 注音、日文輸入法選字中不查詢，避免拿半成品字根查出「找不到」。
  void _onInput() {
    final value = _controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      _timer?.cancel();
      return;
    }
    final input = value.text.trim();
    if (input == _latestInput) return;
    _latestInput = input;
    _timer?.cancel();
    if (input.isEmpty) {
      setState(() => _query = '');
      return;
    }
    _timer = Timer(_debounce, () => setState(() => _query = input));
  }

  @override
  Widget build(BuildContext context) => PaperScaffold(
    scrollable: false,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: PageBackLink(fallback: AppRoutes.learn),
        ),
        const AppText('單字', scale: TypeScale.displayM),
        const SizedBox(height: AppSpace.s4),
        VocabSearchField(controller: _controller),
        const SizedBox(height: AppSpace.s5),
        Expanded(
          child: CustomScrollView(
            slivers: _query.isEmpty
                ? const [_TopicEntries(), _TopicList()]
                : [_SearchResults(query: _query)],
          ),
        ),
      ],
    ),
  );
}

class _TopicEntries extends StatelessWidget {
  const _TopicEntries();

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: RuledList(
      children: [
        RuledTile.text(
          '全部單字',
          subtitle: '依課排列',
          onTap: () => context.push(AppRoutes.vocabList()),
        ),
        RuledTile.text(
          '收藏的單字',
          onTap: () => context.push(AppRoutes.vocabList(onlyStarred: true)),
        ),
      ],
    ),
  );
}

class _TopicList extends ConsumerWidget {
  const _TopicList();

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncSliver(
    ref.watch(vocabTopicsProvider),
    onRetry: () => ref.invalidate(vocabTopicsProvider),
    data: (topics) => SliverList.builder(
      itemCount: topics.length,
      itemBuilder: (context, index) => _TopicTile(topic: topics[index]),
    ),
  );
}

class _TopicTile extends StatelessWidget {
  const _TopicTile({required this.topic});

  final TopicDto topic;

  @override
  Widget build(BuildContext context) => RuledTile(
    title: MixedText(topic.titleZh),
    trailing: AppText(
      '${topic.count}',
      scale: TypeScale.caption,
      color: AppTokens.of(context).ink.secondary,
      semanticsLabel: '${topic.count} 個單字',
    ),
    onTap: () => context.push(AppRoutes.vocabList(topic: topic.id)),
  );
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) => asyncSliver(
    ref.watch(vocabSearchProvider(query)),
    onRetry: () => ref.invalidate(vocabSearchProvider(query)),
    data: (results) => results.isEmpty
        ? SliverToBoxAdapter(
            child: Semantics(
              liveRegion: true,
              child: const AppText('找不到，試試中文、假名或羅馬字'),
            ),
          )
        : SliverList.builder(
            itemCount: results.length,
            itemBuilder: (context, index) => VocabRow(
              key: ValueKey(results[index].id),
              word: results[index],
            ),
          ),
  );
}
