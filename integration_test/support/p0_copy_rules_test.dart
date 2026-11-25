// O7 文案守門的單元測試（純文字，不開 App）。執行方式見 integration_test/README.md。
import 'package:flutter_test/flutter_test.dart';

import 'p0_copy_rules.dart';

ShownText _shown(String text, {bool inWordDetail = false}) =>
    (text: text, inWordDetail: inWordDetail);

void main() {
  group('p0CopyViolations：N4 宣稱', _n4Claims);
  group('p0CopyViolations：L31 以後的課', _beyondLessonClaims);
  group('shownCopyViolations：V3 級別標籤的豁免', _wordLabelExemption);
  group('rawMarkupTexts：原樣露出的 {ja:} 標記', _rawMarkup);
  group('rawLessonIdTexts：露出課的內部 id（U11）', _rawLessonIds);
  group('retiredSkipTexts：舊的略過文案（U8）', _retiredSkip);
  group('zeroReviewTexts：T1「複習 0 張」（U5）', _zeroReview);
  group('fractionalStudyTimeTexts：T3 的小數分鐘（U6）', _fractionalStudyTime);
}

void _n4Claims() {
  for (final text in [
    '本版到 L30，涵蓋參考 N4 範圍。',
    '學完可達參考 N4 程度',
    'N4 以外的內容也在本版',
    '主線覆蓋 N5 全部與 N4 主要句型',
    '參考 N4',
    '參考Ｎ４',
  ]) {
    test('抓得到「$text」', () {
      expect(p0CopyViolations([text]), [text]);
    });
  }

  test('p0 的範圍說法與限制說明不算', () {
    expect(
      p0CopyViolations([
        '本版到 L30，涵蓋參考 N5 範圍。',
        '參考 N5',
        '無法做到無字幕追劇。一般估計需要 N2、B2 以上程度。',
        '明確不做：N3 以上文法。',
      ]),
      isEmpty,
    );
  });
}

void _beyondLessonClaims() {
  for (final text in [
    '第 31 課',
    '第31課',
    '第 31～48 課',
    '第31～48課',
    '31～48 課',
    '第 21～31 課',
    '第 21 至第 31 課',
    '第３１課',
    'L31',
    'L31～L48',
    'L21～L48',
    'L21-48',
    '完整版到 L48。',
  ]) {
    test('抓得到「$text」', () {
      expect(p0CopyViolations([text]), [text]);
    });
  }

  test('L30 以內與不是課號的數字不算', () {
    expect(
      p0CopyViolations([
        '本版到 L30，約在 2026/9/1 完成（粗估）',
        '完成第 21 課後開放',
        '你現在在第 22 課。',
        '平假名第 10 課',
        'L01–L30',
        '第 1～30 課',
        '45 分鐘',
        '3/9 開放',
        'HTML35',
      ]),
      isEmpty,
    );
  });
}

void _wordLabelExemption() {
  test('V3 單字詳情上整段就是級別標籤時不算', () {
    expect(
      shownCopyViolations([
        _shown('參考 N4', inWordDetail: true),
        _shown('未列入參考詞表', inWordDetail: true),
        _shown(' 參考 N4 ', inWordDetail: true),
      ]),
      isEmpty,
    );
  });

  test('同樣的標籤出現在其他畫面仍算', () {
    expect(shownCopyViolations([_shown('參考 N4'), _shown('N4 以外')]), [
      '參考 N4',
      'N4 以外',
    ]);
  });

  test('舊的 N4 以外標籤在 V3 也不再豁免', () {
    expect(shownCopyViolations([_shown('N4 以外', inWordDetail: true)]), [
      'N4 以外',
    ]);
  });

  test('V3 上把標籤寫進句子仍算', () {
    const sentence = '本版到 L30，涵蓋參考 N4 範圍。';
    expect(shownCopyViolations([_shown(sentence, inWordDetail: true)]), [
      sentence,
    ]);
  });

  test('豁免只管 N4，V3 上的課號照樣檢查', () {
    expect(shownCopyViolations([_shown('第 31 課', inWordDetail: true)]), [
      '第 31 課',
    ]);
  });

  test('isJlptWordLabel 只認整段標籤', () {
    expect(jlptWordLabels.every(isJlptWordLabel), isTrue);
    expect(isJlptWordLabel('涵蓋參考 N4 範圍'), isFalse);
    expect(isJlptWordLabel('N4 以外的內容'), isFalse);
    expect(isJlptWordLabel('N4 以外'), isFalse);
  });
}

void _rawMarkup() {
  test('畫面文字含 {ja: 就算露出標記', () {
    expect(rawMarkupTexts(['數一數 {ja:〜てる}', '數一數 〜てる', '{ja']), [
      '數一數 {ja:〜てる}',
    ]);
  });
}

void _rawLessonIds() {
  test('課的內部 id 算露出', () {
    expect(rawLessonIdTexts(['還沒學到le.k03', 'le.kk02', 'le.l05 開放']), [
      '還沒學到le.k03',
      'le.kk02',
      'le.l05 開放',
    ]);
  });

  test('可讀的課名與其他 id 不算', () {
    expect(
      rawLessonIdTexts([
        '平假名第 3 課',
        '片假名第 2 課',
        '第 5 課',
        'vo.miru',
        'female.l1',
      ]),
      isEmpty,
    );
  });
}

void _retiredSkip() {
  test('裁決統一前的文案算違反', () {
    expect(retiredSkipTexts(['略過這項', '先略過這項吧']), ['略過這項', '先略過這項吧']);
  });

  test('統一後的文案與檢定的「先略過」不算', () {
    expect(retiredSkipTexts(['略過這一項', '先略過']), isEmpty);
  });
}

void _zeroReview() {
  test('複習列寫 0 張算違反', () {
    expect(zeroReviewTexts(['0 張 · 0.5 分']), ['0 張 · 0.5 分']);
  });

  test('有張數、收尾新卡的寫法不算', () {
    expect(
      zeroReviewTexts([
        '10 張 · 3 分',
        '今天先做 20 張，其餘之後再排 · 8 分',
        '最後再看 3 張新卡 · 0.5 分',
      ]),
      isEmpty,
    );
  });
}

void _fractionalStudyTime() {
  test('T3 帶小數的分鐘算違反', () {
    expect(fractionalStudyTimeTexts(['今天學了 0.2 分鐘，答了 5 題']), [
      '今天學了 0.2 分鐘，答了 5 題',
    ]);
  });

  test('不到 1 分鐘與整數分鐘不算', () {
    expect(
      fractionalStudyTimeTexts([
        '今天學了 不到 1 分鐘，答了 5 題',
        '今天學了 12 分鐘，答了 40 題',
        '約 0.5 分鐘',
      ]),
      isEmpty,
    );
  });
}
