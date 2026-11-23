import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show PanicException;
import 'package:flutter_test/flutter_test.dart';
import 'package:japanese_learn_app/core/backend/failures.dart';
import 'package:japanese_learn_app/core/backend/frb/dto.dart';
import 'package:japanese_learn_app/core/backend/providers.dart';

void main() {
  group('guardBackend', () {
    Future<Never> throwing(Object error) => guardBackend<Never>(() async {
      throw error;
    });

    final cases = <(CoreError, Type)>[
      (const CoreError.notFound(entity: 'vocab', id: 'x'), NotFoundFailure),
      (
        const CoreError.invalidInput(field: 'a', reason: 'b'),
        InvalidInputFailure,
      ),
      (const CoreError.staleCard(cardId: 'c'), StaleCardFailure),
      (const CoreError.noActivePlan(), NoPlanFailure),
      (const CoreError.contentCorrupt(file: 'f', detail: 'd'), ContentFailure),
      (
        const CoreError.migrationFailed(fromVersion: 1, message: 'm'),
        ContentFailure,
      ),
      (const CoreError.storage(message: 's'), StorageFailure),
      (const CoreError.internal(message: 'i'), UnexpectedFailure),
    ];

    for (final (error, expected) in cases) {
      test('${error.runtimeType} 對應 $expected', () async {
        await expectLater(
          throwing(error),
          throwsA(
            isA<AppFailure>()
                .having((f) => f.runtimeType, 'type', expected)
                .having((f) => f.userMessage, 'userMessage', isNotEmpty),
          ),
        );
      });
    }

    test('PanicException 轉 UnexpectedFailure，不帶 backtrace', () async {
      await expectLater(
        throwing(PanicException('secret backtrace')),
        throwsA(
          isA<UnexpectedFailure>().having((f) => f.detail, 'detail', isNull),
        ),
      );
    });

    test('一般 Exception 也轉 UnexpectedFailure', () async {
      await expectLater(
        throwing(const FormatException('bad')),
        throwsA(isA<UnexpectedFailure>()),
      );
    });

    test('AppFailure 原樣往外拋', () async {
      await expectLater(
        throwing(const StorageFailure()),
        throwsA(isA<StorageFailure>()),
      );
    });

    test('成功時回傳結果', () async {
      expect(await guardBackend(() async => 7), 7);
    });
  });

  test('userMessage 不含技術字樣', () {
    const failures = <AppFailure>[
      NotFoundFailure(detail: 'SELECT * FROM x'),
      StorageFailure(detail: 'disk I/O error'),
      UnexpectedFailure(detail: 'boom'),
    ];
    for (final failure in failures) {
      expect(failure.userMessage, isNot(contains('SELECT')));
      expect(failure.userMessage, isNot(contains('error')));
    }
  });

  test('sessionSeed 是穩定的 FNV-1a', () {
    expect(sessionSeed(''), 0x811c9dc5);
    expect(sessionSeed('a'), 0xe40c292c);
    expect(sessionSeed('2026-03-02'), sessionSeed('2026-03-02'));
    expect(sessionSeed('2026-03-02'), isNot(sessionSeed('2026-03-03')));
  });
}
