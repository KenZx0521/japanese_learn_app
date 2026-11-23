import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/features/dialogue/model/dialogue_run.dart';

void main() {
  group('visibleDialoguePhases', () {
    test('語音可用時保留要求的階段', () {
      expect(visibleDialoguePhases(const [1, 2, 3, 4], audio: true), [
        1,
        2,
        3,
        4,
      ]);
    });

    test('無聲模式略過第一、三階段', () {
      expect(visibleDialoguePhases(const [1, 2, 3, 4], audio: false), [2, 4]);
      expect(visibleDialoguePhases(const [3, 4], audio: false), [4]);
    });
  });

  group('reduceDialogueRun', () {
    test('階段完成後前進，最後一段完成後為 null', () {
      var run = initialDialogueRun(const [1, 2], audio: true);
      expect(run.phase, 1);
      run = reduceDialogueRun(run, const PhaseCompleted());
      expect(run.phase, 2);
      run = reduceDialogueRun(run, const PhaseCompleted());
      expect(run.phase, isNull);
      expect(run.isDone, isTrue);
    });

    test('無聲時從可見的第一段開始', () {
      final run = initialDialogueRun(const [1, 3, 4], audio: false);
      expect(run.phase, 4);
    });

    test('全部階段都被略過時直接完成', () {
      final run = initialDialogueRun(const [1, 3], audio: false);
      expect(run.isDone, isTrue);
    });

    test('語音消失時跳過當前不可見的階段，保留已到的進度', () {
      var run = initialDialogueRun(const [1, 2, 3, 4], audio: true);
      run = reduceDialogueRun(run, const AudioChanged(false));
      expect(run.phase, 2);
      expect(run.audio, isFalse);
    });

    test('語音消失時目前階段仍可見則不動', () {
      var run = initialDialogueRun(const [1, 2, 3, 4], audio: true);
      run = reduceDialogueRun(run, const PhaseCompleted());
      run = reduceDialogueRun(run, const AudioChanged(false));
      expect(run.phase, 2);
    });

    test('語音消失時目前是最後的不可見階段則結束', () {
      var run = initialDialogueRun(const [3], audio: true);
      run = reduceDialogueRun(run, const AudioChanged(false));
      expect(run.isDone, isTrue);
    });

    test('語音恢復時不會把使用者送回前面的階段', () {
      var run = initialDialogueRun(const [1, 2, 3, 4], audio: false);
      expect(run.phase, 2);
      run = reduceDialogueRun(run, const AudioChanged(true));
      expect(run.phase, 2);
    });
  });
}
