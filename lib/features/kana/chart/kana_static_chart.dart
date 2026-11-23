import '../../../core/backend/frb/dto.dart';

// K1 的靜態底圖（§2.3）：載入中先畫，`kana_chart` 失敗時仍有表可看。
// 欄位與內容 JSON 的比對在 test/features/kana/kana_static_chart_test.dart。

typedef _Row = (String kana, String idTails);

const _gapMark = '_';

const _head = <_Row>[
  ('あ い う え お', 'a i u e o'),
  ('か き く け こ', 'ka ki ku ke ko'),
  ('さ し す せ そ', 'sa shi su se so'),
  ('た ち つ て と', 'ta chi tsu te to'),
  ('な に ぬ ね の', 'na ni nu ne no'),
  ('は ひ ふ へ ほ', 'ha hi fu he ho'),
  ('ま み む め も', 'ma mi mu me mo'),
  ('や _ ゆ _ よ', 'ya _ yu _ yo'),
];
const _ra = ('ら り る れ ろ', 'ra ri ru re ro');
const _wa = ('わ _ _ _ を', 'wa _ _ _ wo');
const _n = ('ん _ _ _ _', 'n _ _ _ _');

const _dakuten = <_Row>[
  ('が ぎ ぐ げ ご', 'ga gi gu ge go'),
  ('ざ じ ず ぜ ぞ', 'za ji zu ze zo'),
  ('だ ぢ づ で ど', 'da di du de do'),
  ('ば び ぶ べ ぼ', 'ba bi bu be bo'),
  ('ぱ ぴ ぷ ぺ ぽ', 'pa pi pu pe po'),
];

const _yoon = <_Row>[
  ('きゃ きゅ きょ', 'kya kyu kyo'),
  ('しゃ しゅ しょ', 'sha shu sho'),
  ('ちゃ ちゅ ちょ', 'cha chu cho'),
  ('にゃ にゅ にょ', 'nya nyu nyo'),
  ('ひゃ ひゅ ひょ', 'hya hyu hyo'),
  ('みゃ みゅ みょ', 'mya myu myo'),
  ('りゃ りゅ りょ', 'rya ryu ryo'),
  ('ぎゃ ぎゅ ぎょ', 'gya gyu gyo'),
  ('じゃ じゅ じょ', 'ja ju jo'),
  ('びゃ びゅ びょ', 'bya byu byo'),
  ('ぴゃ ぴゅ ぴょ', 'pya pyu pyo'),
];

/// 內容 ID 尾碼與實際讀音不同的字。
const _romajiOverride = {'di': 'ji', 'du': 'zu'};

/// 兩種假名都是標準五十音順，對齊 `kana_chart` 的列序。
const _basicRows = <_Row>[..._head, _ra, _wa, _n];

String _toKatakana(String hiragana) =>
    String.fromCharCodes(hiragana.runes.map((code) => code + 0x60));

KanaCellDto _cell(
  KanaScript script,
  String kana,
  String idTail,
  KanaKindDto kind,
) {
  final isHiragana = script == KanaScript.hiragana;
  final ch = isHiragana ? kana : _toKatakana(kana);
  return KanaCellDto(
    id: 'ka.${isHiragana ? 'hira' : 'kata'}.$idTail',
    ch: ch,
    romaji: _romajiOverride[idTail] ?? idTail,
    kind: kind,
    status: KanaStatus.notStarted,
    fastBadge: false,
    speech: SpeechDto(text: ch, kana: ch),
    listenDisabled: false,
  );
}

KanaRowDto _row(KanaScript script, _Row row, KanaKindDto kind) {
  final kanas = row.$1.split(' ');
  final ids = row.$2.split(' ');
  return KanaRowDto(
    cells: [
      for (var i = 0; i < kanas.length; i++)
        kanas[i] == _gapMark ? null : _cell(script, kanas[i], ids[i], kind),
    ],
  );
}

KanaGroupDto _group(
  KanaScript script,
  String title,
  int columns,
  List<_Row> rows,
  KanaKindDto kind,
) => KanaGroupDto(
  titleZh: title,
  columns: columns,
  rows: [for (final row in rows) _row(script, row, kind)],
);

/// 全部為「尚未開始」的表；外來音與符號只在真實資料出現。
List<KanaGroupDto> staticKanaChart(KanaScript script) => [
  _group(script, '清音', 5, _basicRows, KanaKindDto.basic),
  _group(script, '濁音與半濁音', 5, _dakuten, KanaKindDto.dakuten),
  _group(script, '拗音', 3, _yoon, KanaKindDto.yoon),
];
