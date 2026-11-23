import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/backend/frb/dto.dart';
import '../../core/text/mixed_text.dart';
import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/error_slip.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/skeleton_lines.dart';
import 'vocab_labels.dart';
import 'vocab_paged_controller.dart';
import 'vocab_providers.dart';
import 'widgets/async_sliver.dart';
import 'widgets/toggle_tag.dart';
import 'widgets/vocab_row.dart';

/// V2 單字列表（§3.4）：依課分段，往下捲分頁，篩選寫進網址。
class VocabListScreen extends ConsumerStatefulWidget {
  const VocabListScreen({
    this.topic,
    required this.onlyIntroduced,
    required this.onlyStarred,
    this.srs,
    super.key,
  });

  final String? topic;
  final bool onlyIntroduced;
  final bool onlyStarred;
  final String? srs;

  VocabFilterDto get filter => VocabFilterDto(
    topic: topic,
    onlyIntroduced: onlyIntroduced,
    onlyStarred: onlyStarred,
    srsState: srsFromQuery(srs),
  );

  @override
  ConsumerState<VocabListScreen> createState() => _VocabListScreenState();
}

class _VocabListScreenState extends ConsumerState<VocabListScreen> {
  /// 距離底部還有這麼多像素就先取下一頁，捲動時看不到等待。
  static const _loadAheadPx = 800.0;

  late VocabFilterDto _filter = widget.filter;

  @override
  void didUpdateWidget(VocabListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.filter;
    if (incoming != oldWidget.filter) _filter = incoming;
  }

  /// `replace` 保留 page key：不重建畫面、不跑轉場，捲動位置也還在。
  void _apply(VocabFilterDto next) {
    setState(() => _filter = next);
    GoRouter.maybeOf(context)?.replace(
      AppRoutes.vocabList(
        topic: next.topic,
        onlyIntroduced: next.onlyIntroduced ? true : null,
        onlyStarred: next.onlyStarred ? true : null,
        srs: next.srsState?.name,
      ),
    );
  }

  VocabFilterDto _with({
    bool? onlyIntroduced,
    bool? onlyStarred,
    required SrsStateLabel? srs,
  }) => VocabFilterDto(
    topic: _filter.topic,
    onlyIntroduced: onlyIntroduced ?? _filter.onlyIntroduced,
    onlyStarred: onlyStarred ?? _filter.onlyStarred,
    srsState: srs,
  );

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.extentAfter < _loadAheadPx) {
      unawaited(ref.read(vocabPagedProvider(_filter).notifier).loadMore());
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final provider = vocabPagedProvider(_filter);
    final paged = ref.watch(provider);
    return PaperScaffold(
      scrollable: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                filter: _filter,
                total: paged.value?.total,
                onChanged: _apply,
                buildFilter: _with,
              ),
            ),
            asyncSliver<VocabPagedData>(
              paged,
              onRetry: () => ref.invalidate(provider),
              data: (data) => _PagedList(
                data: data,
                onRetryMore: () =>
                    unawaited(ref.read(provider.notifier).retryMore()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

typedef _FilterBuilder = VocabFilterDto Function({
  bool? onlyIntroduced,
  bool? onlyStarred,
  required SrsStateLabel? srs,
});

class _Header extends ConsumerWidget {
  const _Header({
    required this.filter,
    required this.total,
    required this.onChanged,
    required this.buildFilter,
  });

  final VocabFilterDto filter;
  final int? total;
  final ValueChanged<VocabFilterDto> onChanged;
  final _FilterBuilder buildFilter;

  static const _states = [
    SrsStateLabel.notStarted,
    SrsStateLabel.learning,
    SrsStateLabel.review,
    SrsStateLabel.mastered,
  ];

  String? _topicTitle(WidgetRef ref) {
    final topic = filter.topic;
    if (topic == null) return null;
    final topics = ref.watch(vocabTopicsProvider).value ?? const [];
    final title = topics.where((t) => t.id == topic).firstOrNull?.titleZh;
    return title ?? '單字';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    final topic = _topicTitle(ref);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageBackLink(fallback: AppRoutes.vocab),
        if (topic != null)
          // 主題名稱來自內容，不能用 displayM（§4.2）
          MixedText(topic, scale: TypeScale.title)
        else
          const AppText('全部單字', scale: TypeScale.displayM),
        if (total != null)
          AppText(
            '共 $total 個',
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
        const SizedBox(height: AppSpace.s4),
        _flagFilters(),
        const SizedBox(height: AppSpace.s2),
        _stateFilters(),
        const SizedBox(height: AppSpace.s5),
      ],
    );
  }

  Widget _flagFilters() => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s2,
    children: [
      ToggleTag(
        label: '只看學過的',
        value: filter.onlyIntroduced,
        onChanged: (value) =>
            onChanged(buildFilter(onlyIntroduced: value, srs: filter.srsState)),
      ),
      ToggleTag(
        label: '收藏',
        value: filter.onlyStarred,
        onChanged: (value) =>
            onChanged(buildFilter(onlyStarred: value, srs: filter.srsState)),
      ),
    ],
  );

  Widget _stateFilters() => Wrap(
    spacing: AppSpace.s2,
    runSpacing: AppSpace.s2,
    children: [
      for (final state in _states)
        ToggleTag(
          label: srsLabelOf(state),
          value: filter.srsState == state,
          onChanged: (selected) =>
              onChanged(buildFilter(srs: selected ? state : null)),
        ),
    ],
  );
}

class _PagedList extends StatelessWidget {
  const _PagedList({required this.data, required this.onRetryMore});

  final VocabPagedData data;
  final VoidCallback onRetryMore;

  bool get _showsFooter => data.loadingMore || data.moreFailure != null;

  @override
  Widget build(BuildContext context) {
    final items = data.items;
    if (items.isEmpty) {
      return const SliverToBoxAdapter(child: AppText('沒有符合的單字'));
    }
    return SliverList.builder(
      itemCount: items.length + (_showsFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == items.length) return _footer();
        final word = items[index];
        final startsLesson =
            index == 0 || items[index - 1].lessonId != word.lessonId;
        return _LessonRow(
          key: ValueKey(word.id),
          word: word,
          showHeading: startsLesson,
        );
      },
    );
  }

  Widget _footer() {
    final failure = data.moreFailure;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s4),
      child: failure == null
          ? const DelayedReveal(child: SkeletonLines(lines: 1))
          : ErrorSlip(failure: failure, onRetry: onRetryMore),
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.word, required this.showHeading, super.key});

  final VocabSummaryDto word;
  final bool showHeading;

  @override
  Widget build(BuildContext context) {
    final heading = lessonLabelOf(word.lessonId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeading && heading.isNotEmpty) _LessonHeading(heading),
        VocabRow(word: word),
      ],
    );
  }
}

class _LessonHeading extends StatelessWidget {
  const _LessonHeading(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return Semantics(
      header: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(top: AppSpace.s5, bottom: AppSpace.s2),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.line.strong)),
        ),
        child: EyebrowText(title),
      ),
    );
  }
}
