import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/design/widgets/error_slip.dart';
import 'package:japanese_learn_app/design/widgets/skeleton_lines.dart';
import 'package:japanese_learn_app/design/widgets/stamp_overlay.dart';
import 'package:japanese_learn_app/features/checkpoint/checkpoint_flow.dart';
import 'package:material_ui/material_ui.dart';

import '../../support/fake_backend.dart';
import '../../support/pump_app.dart';
import '../quiz/quiz_fixtures.dart';

CheckpointResultDto _result({
  bool passed = true,
  List<String> weak = const [],
}) => CheckpointResultDto(
  milestoneId: 'ms.hira',
  correct: passed ? 18 : 10,
  total: 20,
  scorePercent: passed ? 90 : 50,
  passed: passed,
  weakIds: weak,
);

Future<void> _settleStamp(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 2));
  await tester.pumpAndSettle();
}

void main() {
  late FakeBackend backend;

  setUp(() {
    backend = FakeBackend();
    backend.drills.checkpointStartStub.returns([choiceQuestion()]);
  });

  Future<void> pumpFlow(
    WidgetTester tester, {
    ValueChanged<CheckpointResultDto>? onFinished,
    VoidCallback? onEmpty,
    Future<void> Function()? onDismiss,
    bool settle = true,
  }) async {
    await pumpApp(
      tester,
      backend: backend,
      settle: settle,
      child: CheckpointFlow(
        milestoneId: 'ms.hira',
        title: '平假名',
        seed: 3,
        audio: true,
        onFinished: onFinished ?? (_) {},
        onEmpty: onEmpty,
        onDismiss: onDismiss,
      ),
    );
  }

  group('開始頁', () {
    testWidgets('顯示名稱、題數、中途不顯示對錯', (tester) async {
      await pumpFlow(tester);

      expect(find.text('平假名'), findsOneWidget);
      expect(find.text('1 題'), findsOneWidget);
      expect(find.text('中途不顯示對錯'), findsOneWidget);
      expect(backend.drills.checkpointStartStub.calls.single, [
        'ms.hira',
        3,
        true,
      ]);
    });

    testWidgets('載入超過 200ms 顯示骨架', (tester) async {
      final gate = Completer<void>();
      backend.drills.checkpointStartStub.gate = gate.future;

      await pumpFlow(tester, settle: false);
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SkeletonLines), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('載入失敗可重試', (tester) async {
      backend.drills.checkpointStartStub.throws(const StorageFailure());

      await pumpFlow(tester);
      expect(find.byType(ErrorSlip), findsOneWidget);

      backend.drills.checkpointStartStub.returns([choiceQuestion()]);
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();

      expect(find.text('開始'), findsOneWidget);
    });

    testWidgets('沒有題目且 T2 傳 onEmpty 時略過', (tester) async {
      backend.drills.checkpointStartStub.returns(const []);
      var empties = 0;

      await pumpFlow(tester, onEmpty: () => empties++);

      expect(empties, 1);
    });

    testWidgets('沒有題目的空狀態', (tester) async {
      backend.drills.checkpointStartStub.returns(const []);

      await pumpFlow(tester);

      expect(find.text('這課目前沒有題目'), findsOneWidget);
    });

    testWidgets('先略過失敗時留在本頁並提示', (tester) async {
      await pumpFlow(
        tester,
        onDismiss: () async => throw const StorageFailure(),
      );

      await tester.tap(find.text('先略過'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorSlip), findsOneWidget);
      expect(find.text('開始'), findsOneWidget);
    });
  });

  Future<void> answerAll(WidgetTester tester) async {
    await tester.tap(find.text('開始'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('貓'));
    await tester.pumpAndSettle();
  }

  group('作答與結果', () {
    testWidgets('作答中不顯示對錯，結束時整批送 checkpoint_finish', (tester) async {
      backend.drills.checkpointFinishStub.returns(_result());
      CheckpointResultDto? finished;

      await pumpFlow(tester, onFinished: (r) => finished = r);
      await answerAll(tester);

      expect(find.textContaining('答對'), findsOneWidget);
      final call = backend.drills.checkpointFinishStub.calls.single;
      expect(call.first, 'ms.hira');
      expect(call.last, hasLength(1));

      await _settleStamp(tester);
      await tester.tap(find.text('繼續'));
      expect(finished?.passed, isTrue);
    });

    testWidgets('通過時蓋章', (tester) async {
      backend.drills.checkpointFinishStub.returns(_result());

      await pumpFlow(tester);
      await answerAll(tester);

      expect(
        tester.widget<StampOverlay>(find.byType(StampOverlay)).play,
        isTrue,
      );
      await _settleStamp(tester);
    });

    testWidgets('未通過只建議，不蓋章也不鎖內容', (tester) async {
      backend.drills.checkpointFinishStub.returns(_result(passed: false));

      await pumpFlow(tester);
      await answerAll(tester);

      expect(find.text('可以先往下學，有空再回來'), findsOneWidget);
      expect(
        tester.widget<StampOverlay>(find.byType(StampOverlay)).play,
        isFalse,
      );
    });

    testWidgets('送出失敗顯示重試，用同一批作答', (tester) async {
      backend.drills.checkpointFinishStub.throws(const StorageFailure());

      await pumpFlow(tester);
      await answerAll(tester);

      expect(find.byType(ErrorSlip), findsOneWidget);
      backend.drills.checkpointFinishStub.returns(_result());
      await tester.tap(find.text('重試'));
      await tester.pumpAndSettle();
      await _settleStamp(tester);

      final calls = backend.drills.checkpointFinishStub.calls;
      expect(calls, hasLength(2));
      expect(calls.first.last, calls.last.last);
    });

    testWidgets('弱項逐一 peek，gr.* 有練這題', (tester) async {
      backend.drills.checkpointFinishStub.returns(
        _result(passed: false, weak: const ['gr.wa']),
      );
      backend.peek.peekStub.returns(peekGrammar);

      await pumpFlow(tester);
      await answerAll(tester);

      expect(find.text('練這題'), findsOneWidget);
      expect(
        backend.peek.peekStub.calls.map((c) => c.single),
        contains('gr.wa'),
      );
    });
  });
}
