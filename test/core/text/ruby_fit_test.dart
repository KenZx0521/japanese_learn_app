// U1：振假名懸掛的純計算（JIS X 4051 ルビの掛け的精神）。
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/text/ruby_fit.dart';

void main() {
  group('RubyFit.compute', () {
    test('ruby 比底字窄：寬度等於底字，ruby 置中，不加字距', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 40,
        baseLength: 2,
        overhang: const RubyOverhang(start: 12, end: 12),
      );

      expect(fit.width, 50);
      expect(fit.baseSpacing, 0);
      expect(fit.rubyLeft, 5);
    });

    test('兩側都可懸掛：寬度等於底字，ruby 置中懸出兩側，不加字距', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 72,
        baseLength: 2,
        overhang: const RubyOverhang(start: 12, end: 12),
      );

      expect(fit.width, 50);
      expect(fit.baseSpacing, 0);
      expect(fit.rubyLeft, -11);
    });

    test('都不能懸掛：寬度等於 ruby，餘量平均成字距（1:2:1）', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 72,
        baseLength: 2,
        overhang: RubyOverhang.none,
      );

      expect(fit.width, 72);
      expect(fit.baseSpacing, 11);
      expect(fit.rubyLeft, 0);
    });

    test('單一底字：字距等於全部餘量（引擎前後各半，等於置中）', () {
      final fit = RubyFit.compute(
        base: 24,
        ruby: 36,
        baseLength: 1,
        overhang: RubyOverhang.none,
      );

      expect(fit.width, 36);
      expect(fit.baseSpacing, 12);
    });

    test('寬度 = max(底字, ruby − 兩側允許懸掛)，餘量才分配', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 72,
        baseLength: 2,
        overhang: const RubyOverhang(start: 4, end: 4),
      );

      expect(fit.width, 64);
      expect(fit.rubyLeft, -4);
      expect(fit.baseSpacing, 7);
    });

    test('兩側允許量不同時，ruby 恰好用滿兩側', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 72,
        baseLength: 5,
        overhang: const RubyOverhang(start: 2, end: 12),
      );

      expect(fit.width, 58);
      expect(fit.rubyLeft, -2);
      expect(fit.rubyLeft + 72, fit.width + 12);
      expect(fit.baseSpacing, closeTo(8 / 5, 1e-9));
    });

    test('一側不能懸掛：ruby 貼齊那一側，只往另一側懸', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 72,
        baseLength: 2,
        overhang: const RubyOverhang(start: 0, end: 12),
      );

      expect(fit.width, 60);
      expect(fit.rubyLeft, 0);
      expect(fit.baseSpacing, 5);
    });

    test('另一側允許量足夠時底字不撐開，ruby 貼齊不能懸的那一側', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 60,
        baseLength: 2,
        overhang: const RubyOverhang(start: 12, end: 0),
      );

      expect(fit.width, 50);
      expect(fit.baseSpacing, 0);
      expect(fit.rubyLeft, -10);
    });

    test('ruby 較窄時，就算不能懸掛也置中於底字', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 40,
        baseLength: 2,
        overhang: RubyOverhang.none,
      );

      expect(fit.baseSpacing, 0);
      expect(fit.rubyLeft, 5);
    });

    test('寬度不超過 maxWidth，字距只分配放得下的部分', () {
      final fit = RubyFit.compute(
        base: 50,
        ruby: 120,
        baseLength: 2,
        overhang: RubyOverhang.none,
        maxWidth: 100,
      );

      expect(fit.width, 100);
      expect(fit.baseSpacing, 25);
      expect(fit.rubyLeft, -10);
    });

    test('底字比 maxWidth 還寬時不加字距', () {
      final fit = RubyFit.compute(
        base: 150,
        ruby: 180,
        baseLength: 5,
        overhang: RubyOverhang.none,
        maxWidth: 100,
      );

      expect(fit.width, 150);
      expect(fit.baseSpacing, 0);
    });

    test('沒有底字時不除以零', () {
      final fit = RubyFit.compute(
        base: 0,
        ruby: 12,
        baseLength: 0,
        overhang: RubyOverhang.none,
      );

      expect(fit.baseSpacing, 0);
    });
  });

  group('RubyOverhang.resolve', () {
    test('每側至多一個 ruby 字寬', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: const RubyRun(width: 40),
        end: const RubyRun(width: 40),
      );

      expect(overhang.start, 12);
      expect(overhang.end, 12);
    });

    test('沒有相鄰文字的一側不懸掛', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: RubyRun.none,
        end: const RubyRun(width: 40),
      );

      expect(overhang.start, 0);
      expect(overhang.end, 12);
    });

    test('不超出相鄰文字本身的寬度', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: const RubyRun(width: 5),
        end: RubyRun.none,
      );

      expect(overhang.start, 5);
    });

    test('相鄰文字另一頭也有 ruby：本段總懸掛量不超過那段文字的一半', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: const RubyRun(width: 40),
        end: const RubyRun(width: 16, shared: true),
      );

      expect(overhang.start + overhang.end, lessThanOrEqualTo(8));
      expect(overhang.end, greaterThan(0));
    });

    test('另一頭的 ruby 本身不比底字寬多少時，可以多用那段文字', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: RubyRun.none,
        end: const RubyRun(width: 24, shared: true, farExcess: 1),
      );

      expect(overhang.end, 12);
    });

    test('另一頭的 ruby 也很寬時，仍只用那段文字的一半', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: RubyRun.none,
        end: const RubyRun(width: 16, shared: true, farExcess: 22),
      );

      expect(overhang.end, 8);
    });

    test('緊鄰另一段 ruby（寬度 0）時完全不懸掛', () {
      final overhang = RubyOverhang.resolve(
        rubyEm: 12,
        start: const RubyRun(width: 40),
        end: const RubyRun(width: 0, shared: true),
      );

      expect(overhang.start, 0);
      expect(overhang.end, 0);
    });
  });
}
