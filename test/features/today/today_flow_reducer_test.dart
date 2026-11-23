import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/features/today/flow/today_flow_reducer.dart';

import '../../support/fixtures.dart';
import 'today_tasks.dart';

TodayFlowState _loaded(TodayViewDto view, {String? start}) =>
    reduceTodayFlow(TodayFlowState.initial, FlowViewLoaded(view, start: start));

void main() {
  group('開始', () {
    test('沒有 start 時從第一個未完成的任務開始', () {
      final state = _loaded(
        todayFixture(tasks: [reviewTask(done: true), newContentTask()]),
      );

      expect((state.phase as FlowRunning).task.key, 'new:le.k01:0');
    });

    test('start 指定的任務優先', () {
      final state = _loaded(
        todayFixture(tasks: [reviewTask(), newContentTask()]),
        start: 'new:le.k01:0',
      );

      expect((state.phase as FlowRunning).task.key, 'new:le.k01:0');
    });

    test('start 找不到或已完成時退回第一個未完成', () {
      final view = todayFixture(tasks: [reviewTask(), drillTask(done: true)]);

      expect(
        (_loaded(view, start: 'drill').phase as FlowRunning).task.key,
        'review',
      );
      expect(
        (_loaded(view, start: 'gone').phase as FlowRunning).task.key,
        'review',
      );
    });

    test('沒有未完成任務但 learning_tail > 0 時直接進收尾', () {
      final state = _loaded(
        todayFixture(
          tasks: [reviewTask(due: 0, learning: 0, newCards: 3, done: true)],
          learningTail: 3,
        ),
      );

      expect(state.phase, isA<FlowTail>());
    });

    test('完全沒有事情時回 FlowNothing，不蓋完成章', () {
      final state = _loaded(todayFixture(tasks: [reviewTask(done: true)]));

      expect(state.phase, isA<FlowNothing>());
    });
  });

  group('結案', () {
    test('結案後有下一項時進過場，不自動跳轉', () {
      final running = _loaded(todayFixture(tasks: [reviewTask(), drillTask()]));

      final next = reduceTodayFlow(
        running,
        FlowTaskClosed(
          todayFixture(tasks: [reviewTask(done: true), drillTask()]),
        ),
      );

      expect((next.phase as FlowTransition).next.key, 'drill');
    });

    test('繼續之後跑下一項', () {
      var state = _loaded(todayFixture(tasks: [reviewTask(), drillTask()]));
      state = reduceTodayFlow(
        state,
        FlowTaskClosed(
          todayFixture(tasks: [reviewTask(done: true), drillTask()]),
        ),
      );

      state = reduceTodayFlow(state, const FlowContinued());

      expect((state.phase as FlowRunning).task.key, 'drill');
    });

    test('全部跑完且 learning_tail > 0 時進收尾，再到完成頁', () {
      var state = _loaded(todayFixture(tasks: [newContentTask()]));

      state = reduceTodayFlow(
        state,
        FlowTaskClosed(
          todayFixture(tasks: [newContentTask(done: true)], learningTail: 2),
        ),
      );
      expect(state.phase, isA<FlowTail>());

      state = reduceTodayFlow(state, const FlowTailFinished());
      expect(state.phase, isA<FlowDone>());
    });

    test('Review 空且 new_cards 3、tail 3 時清單跑完仍進收尾', () {
      final state = _loaded(
        todayFixture(
          tasks: [reviewTask(due: 0, learning: 0, newCards: 3, done: true)],
          learningTail: 3,
        ),
      );

      expect(state.phase, isA<FlowTail>());
    });

    test('沒有下一項也沒有 tail 時到完成頁', () {
      final state = reduceTodayFlow(
        _loaded(todayFixture(tasks: [newContentTask()])),
        FlowTaskClosed(todayFixture(tasks: [newContentTask(done: true)])),
      );

      expect(state.phase, isA<FlowDone>());
    });

    test('有 O6 旗標時先進 FlowShowExpectation，看完才接下一項', () {
      var state = _loaded(todayFixture(tasks: [newContentTask(), drillTask()]));

      state = reduceTodayFlow(
        state,
        FlowTaskClosed(
          todayFixture(tasks: [newContentTask(done: true), drillTask()]),
          showExpectation: true,
        ),
      );
      expect(state.phase, isA<FlowShowExpectation>());

      state = reduceTodayFlow(state, const FlowExpectationSeen());
      expect((state.phase as FlowTransition).next.key, 'drill');
    });
  });

  group('略過與失敗', () {
    test('取題為空時略過，不影響後面的任務', () {
      var state = _loaded(todayFixture(tasks: [listenTask(), drillTask()]));

      state = reduceTodayFlow(state, const FlowTaskSkipped('listen'));

      expect((state.phase as FlowTransition).next.key, 'drill');
    });

    test('略過的任務之後不會再被選到', () {
      var state = _loaded(todayFixture(tasks: [listenTask(), drillTask()]));
      state = reduceTodayFlow(state, const FlowTaskSkipped('listen'));
      state = reduceTodayFlow(state, const FlowContinued());

      state = reduceTodayFlow(
        state,
        FlowTaskClosed(
          todayFixture(tasks: [listenTask(), drillTask(done: true)]),
        ),
      );

      expect(state.phase, isA<FlowIncomplete>());
    });

    test('略過後收尾完也不算完成', () {
      var state = _loaded(todayFixture(tasks: [listenTask()], learningTail: 2));
      state = reduceTodayFlow(state, const FlowTaskSkipped('listen'));
      expect(state.phase, isA<FlowTail>());

      state = reduceTodayFlow(state, const FlowTailFinished());

      expect(state.phase, isA<FlowIncomplete>());
    });

    test('略過的過場帶略過標記，完成的沒有', () {
      var state = _loaded(todayFixture(tasks: [listenTask(), drillTask()]));

      state = reduceTodayFlow(state, const FlowTaskSkipped('listen'));

      expect((state.phase as FlowTransition).skipped, isTrue);
    });

    test('換日事件進入提示階段', () {
      final state = reduceTodayFlow(
        _loaded(todayFixture(tasks: [drillTask()])),
        const FlowDayRolled(),
      );

      expect(state.phase, isA<FlowDayChanged>());
    });

    test('看完 O6 時已換日就維持換日提示', () {
      var state = _loaded(todayFixture(tasks: [drillTask()]));
      state = reduceTodayFlow(state, const FlowDayRolled());

      state = reduceTodayFlow(state, const FlowExpectationSeen());

      expect(state.phase, isA<FlowDayChanged>());
    });

    test('結案失敗保留任務與耗時，重試用同一份', () {
      final task = reviewTask();
      final state = reduceTodayFlow(
        _loaded(todayFixture(tasks: [task])),
        FlowCloseFailed(task, const StorageFailure(), 1234),
      );

      final phase = state.phase as FlowClosePending;
      expect(phase.task.key, 'review');
      expect(phase.durationMs, 1234);
      expect(phase.failure, isA<StorageFailure>());
    });

    test('今日資料載入失敗', () {
      final state = reduceTodayFlow(
        TodayFlowState.initial,
        const FlowLoadFailed(StorageFailure()),
      );

      expect((state.phase as FlowLoadError).failure, isA<StorageFailure>());
    });
  });

  group('語音改變', () {
    test('目前的任務還在就繼續，換成新的 DTO', () {
      final state = reduceTodayFlow(
        _loaded(todayFixture(tasks: [reviewTask(due: 4), drillTask()])),
        FlowViewRefreshed(
          todayFixture(tasks: [reviewTask(due: 9), drillTask()]),
        ),
      );

      final task = (state.phase as FlowRunning).task as TaskDto_Review;
      expect(task.due, 9);
    });

    test('目前的任務消失時跳到下一項', () {
      final state = reduceTodayFlow(
        _loaded(todayFixture(tasks: [listenTask(), drillTask()])),
        FlowViewRefreshed(todayFixture(tasks: [drillTask()])),
      );

      expect((state.phase as FlowRunning).task.key, 'drill');
    });

    test('收尾、過場不受影響', () {
      var state = _loaded(todayFixture(tasks: [reviewTask(), drillTask()]));
      state = reduceTodayFlow(
        state,
        FlowTaskClosed(
          todayFixture(tasks: [reviewTask(done: true), drillTask()]),
        ),
      );

      state = reduceTodayFlow(
        state,
        FlowViewRefreshed(
          todayFixture(tasks: [reviewTask(done: true), drillTask()]),
        ),
      );

      expect(state.phase, isA<FlowTransition>());
    });
  });

  group('再學一批', () {
    test('learn_more 回傳的新任務會被 firstRunnableTask 找到', () {
      final view = todayFixture(
        tasks: [
          newContentTask(done: true),
          newContentTask(key: 'new:2'),
        ],
      );

      expect(firstRunnableKey(view), 'new:2');
    });

    test('沒有可跑的任務時回 null', () {
      expect(
        firstRunnableKey(todayFixture(tasks: [reviewTask(done: true)])),
        isNull,
      );
    });
  });
}
