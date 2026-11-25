# 課綱與內容設計（curriculum.md）

本文件是內容撰寫代理、內容載入器（`rust/content/`）與內容 lint 的共同規格，也是所有內容欄位的權威定義。對象是繁體中文母語、日語零基礎的成人學習者。

貫穿全文的四條規則：

1. **順序鐵律**：任何句子只能使用「該句所屬課程之前（含當課）已教過」的單字、文法與假名，例外必須逐詞標註（§13，由測試機械檢查）。
2. **單一事實來源**：句子只寫一個 `t` 欄位（§12.2），漢字顯示、分詞假名、羅馬字、振假名全部由程式推導。內容 JSON 不得出現羅馬字欄位。
3. **全部原創**：不收錄任何真實歌詞、日劇台詞、歌名或劇名。
4. **介面語言**：所有中文欄位為繁體中文、台灣用語（lint R15）；中文欄位裡的日文（含純假名）一律用 `{ja:…}` 標記（§12.2、lint R19）。

## 1. 階段地圖與誠實定位

### 1.1 階段總覽

| 階段 | 課程 | 內容 | 累積單字 | 累積文法 | 參考定位 | 完成後能做到 |
|---|---|---|---|---|---|---|
| S0 假名與發音 | K01–K19，KK01–KK08（KK 穿插於 L01–L08 之間） | 平假名、片假名、濁音、拗音、促音、長音、音調入門 | 0（只有拼讀練習字） | 0 | 入門前 | 讀出所有假名；聽辨清濁、長短音、促音 |
| S1 敬體基礎 | L01–L14 | です／ます句、助詞、形容詞、量詞、比較、動詞分類 | 350 | 79 | N5 前半，A1 前段 | 用背好的句型自我介紹、買東西、點餐、問時間 |
| S2 動詞變化與常體 | L15–L30 | て形、ない形、た形、常體、連體修飾、授受 | 800 | 138 | N5 全範圍，A1 | 在預期場景中完成簡單問答；開始讀懂朋友間的常體 |
| S3 N4 口語核心 | L31–L48 | 可能、意向、條件、受身、使役、命令、推測、敬語入門 | 1,400 | 212 | N4 範圍，A2 的接收能力 | 就熟悉話題來回幾句；聽懂放慢或清楚的日常短句 |

原本的「Z 專區」列（日劇聽解、日文歌）與預告語塊、短劇、看劇聽歌任務已移除（RULINGS O13），§4.5、§8、§9 留空號。

### 1.2 參考基準（寫進 App 的「關於程度」頁時須照實引用）

- JLPT 自 2025 年 12 月的測驗起，在合格者的成績單標示 CEFR 參考：N5 總分 80 以上為 A1，N4 總分 90 以上為 A2。
- JLPT 自 2010 年改制後**沒有官方單字與文法清單**，故 `jlpt` 欄位只代表「參考級別」，介面文字須寫「參考 N5」，不得宣稱官方。
- 舊制規格常被引用的數字：4 級（約當 N5）約 800 字、100 漢字、學習約 150 小時；3 級（約當 N4）約 1,500 字、300 漢字、學習約 300 小時。學習時數本身也是估計值。

### 1.3 這個 App 能帶你到哪裡（必須誠實告知使用者）

對外文案只能宣稱該版本實際發布的內容。

| `CONTENT_STAGE`（§14） | 發布範圍 | 可用文案 | 不得宣稱 |
|---|---|---|---|
| `p0a` | S0＋L01–L07 | 「假名與入門七課」 | 不得提及 N4，不得承諾看懂日劇 |
| `p0` | S0＋L01–L30 | 「本版到 L30」，「涵蓋參考 N5 範圍」 | 不得宣稱已含 N4 內容或 L31 以後的內容 |
| `full` | S0＋L01–L48 | 「完整版到 L48」 | 下表「做不到的部分」 |

下表在 `p0` 起才適用，`p0a` 只寫「假名與入門七課」。目前預設建置為 `p0`，筆記入口會露出（§14）。

| 目標 | 本版（`p0`，到 L30）的實際狀態 | 完整版（`full`，到 L48）的實際狀態 | 做不到的部分 |
|---|---|---|---|
| 日常對話 | 自我介紹、點餐、購物、問路、看診等**預期場景**能完成簡單問答；開始讀懂朋友間的常體 | 再加上打電話與基本敬語；熟悉話題能來回幾句 | App 沒有真人對話對象，口說只有跟讀與選擇回應，不評分發音。流暢度必須靠外部練習 |
| JLPT | 涵蓋參考 N5 範圍 | 主線覆蓋 N5 全部與 N4 主要句型 | 完整版主線依方案約 110–165 小時（§11.4），低於 N4 常見的約 300 小時估計。**不保證通過 N4**，閱讀與聽力仍需額外輸入 |

原本的「聽懂日劇」「理解日文歌」兩列已隨專區移除（RULINGS O13）：App 不提供這兩類的專門內容，也不對它們做任何宣稱。

明確不做：漢字手寫課程、自由作文批改、口說評分、N3 以上文法、真實影音素材。

## 2. 中文母語者的優勢與陷阱

| 代碼 | 現象 | 放進內容的方式 |
|---|---|---|
| A1 優勢：漢字辨義 | 看到「電話」「学校」馬上懂 | 單字卡預設顯示漢字加振假名，不做「先假名後漢字」的西方教材路線；不另開漢字課，漢字隨單字學 |
| A2 優勢：音讀對應 | 台語、客語保留入聲與鼻音韻尾：學 hak8→がく（-k 對應く）、國 kok4→こく、三 sam1→さん（-m 對應ん）；-ng 常對應長音（東→とう、生→せい） | `no.rd.*` 共 20 則規律筆記，掛在相關單字；用「記憶鉤」口吻，不當嚴格規則；台語讀音寫台羅數字調（RULINGS O10） |
| A3 優勢：台灣既有日語借詞 | 便當、歐巴桑、歐吉桑、黑輪、甜不辣、榻榻米、卡哇伊、阿莎力、運將 | 單字 `hook_zh` 欄位，提示熟悉的發音；若語意已偏移（阿莎力）須註明 |
| A4 優勢：假名源自漢字 | 安→あ、以→い、加→か、奈→な；片假名取偏旁：伊→イ、多→タ、千→チ、保→ホ | 每個假名有 `origin_kanji`，作為第一層助記 |
| A5 優勢：修飾語在前 | 「我買的書」與「私が買った本」語序同向 | L23 的 `compare_zh` 明確點出，降低連體修飾的心理門檻 |
| T1 陷阱：同形異義 | 手紙＝信、大丈夫＝沒問題 | `no.ff.*` 60 則（清單見下），綁定單字卡顯示紅色警示，並有 `false_friend` 題型；未綁定單字卡者，在 `ja_zh` 以 `{ja:表記|讀音}` 補上讀音 |
| T2 陷阱：字形差異 | 新字體 駅／驛、広／廣、気／氣；細部差異 骨、直、次、海；和製漢字 働、畑、峠、込 | `no.sj.*` 120 則對照表；全部日文強制 `ja` locale 與打包字型（否則漢字會顯示成中文字形）；單字卡標出「和正體不同」。`shape_detail` 只收用打包的 Klee One 與 Noto Sans TC 子集實際渲染後看得出差異的字：角 的差異在日本與中國大陸之間、台灣與日本相同，今、令、言 只在印刷體有差、Klee 的手寫字形看不出來，都不收。`kokuji`（和製漢字）的 `zh_tw` 放意思最接近的中文單字，畫面標「意思近」而不是「對照」。`variant_split` 用於日文依意思分成兩個並存常用字、台灣只用一個字的情形（着／著：着 管「穿、到達」，著作、顯著 仍寫 著），不可歸為新字體 |
| T3 陷阱：音讀訓讀 | 一字多音：生、行、上、下、日、人；日期特殊讀法 | 不教規則清單，單字卡以 `reading_family` 串同字異讀；大原則（單獨和語多訓讀、二字熟語多音讀）放 `no.rd.intro` |
| T4 陷阱：語序 | SOV、否定在句尾；「不吃」→「食べません」 | L05 起排序題比例最高；`compare_zh` 欄位標語序差異 |
| T5 陷阱：助詞 | 中文無對應：は／が、に／で、を的省略 | 填助詞題貫穿全程；L08、L23 有 は／が 專課；`gr.*` 的 `contrast` 欄位列相近助詞 |
| T6 陷阱：「的」轉移 | 誤寫「大きいの車」「買ったの本」 | L09、L23 的選擇題**必須**以此錯誤作干擾項，並寫 `why_zh` |
| T7 陷阱：「是／有／在／了」轉移 | 「行くです」；「有」分 ある／いる／持っている；「在」分 に／で；「了」不等於 た | `no.tr.*` 20 則轉移筆記；形容詞過去「おいしかったです」放 L10 重點防錯（不可說おいしいでした） |
| T8 陷阱：「會／要／想／給／看」多義 | 會＝できる／でしょう／辭書形；給＝あげる／くれる（方向性）；看＝見る／読む／会う | 同屬 `no.tr.*`；授受在 L28、L37 用圖示方向題 |
| T9 陷阱：人稱過度使用 | 句句「私は」「あなたは」；對長輩說あなた很失禮 | 例句在主語明確時省略；`no.tr.anata`；L01 起以「姓氏＋さん」稱呼 |
| T10 陷阱：敬常混亂 | 中文沒有文法化的語體 | 每句有 `style`；L21 專課；`register_convert` 題型；對話提供敬體與常體兩版 |
| T11 陷阱：形容詞有時態、自他動詞成對 | 高かった；開ける／開く | L10、L36 專課 |
| T12 陷阱：發音 | 清濁在華語是送氣對立，不是帶聲對立（か／が、た／だ 易混）；促音、長音的拍感；しゅ／す、ちゅ／つ、じゃ／ざ；語調用四聲去讀 | K11–K19 與 `minimal_pair` 題型。**不用注音符號標音**，ㄅ／ㄆ 的對立會強化清濁誤解 |
| T13 陷阱：量詞音變 | 中文也有量詞（優勢），但 1本 いっぽん、3本 さんぼん 會變音 | L11，答案以表格逐一給出 |

**同形異義清單（`no.ff.*` 至少含以下 54 則，撰寫時補足到 60 則）**：手紙（信）、大丈夫（沒問題）、勉強（念書）、愛人（情婦／情夫）、汽車（火車）、娘（女兒）、丈夫（堅固）、新聞（報紙）、留守（不在家）、床（地板）、走る（跑）、人参（胡蘿蔔）、湯（熱水）、皮肉（諷刺）、迷惑（困擾）、質問（提問）、家内（內人）、我慢（忍耐）、約束（約定）、便宜（方便、權宜）、安い（便宜）、切手（郵票）、上手（擅長）、下手（不擅長）、工夫（巧思）、結束（團結）、放心（失神）、真面目（認真）、一人前（獨當一面）、大家（房東）、面白い（有趣）、怪我（受傷）、必死（拚命）、告訴（提告）、検討（研究考慮）、暗算（心算）、先生（老師）、合同（聯合）、火事（火災）、地味（樸素）、派手（花俏）、案内（導覽）、無理（不可能）、元気（有精神）、気持ち（心情）、番組（節目）、老婆（老太太）、飯店（中式餐館）、自動車（汽車）、自転車（腳踏車）、電車（電車、列車）、時計（鐘錶）、映画（電影）、親切（親切，用法近似，作對照）。未收入單字表的詞（放心、結束等）只出現在「漢字陷阱」總覽（N1 筆記畫面），不進例句。

## 3. 50 音與發音（S0）

### 3.1 教學順序與分組

原則：平假名全部學完才進 L01，片假名穿插在 L01–L08 之間；先學清音，再學變化，最後才是拍感。不按課切天，每日新字數由計畫預設的 `kana_chars_per_day` 決定（10 分＝3、20 分＝5、30 分＝8、45 分＝10，§12.6），各方案的第一批固定 3 字。切片規則：

- 依 `hiragana.json`、`katakana.json` 的陣列順序取字。一天的額度用完為止；當課取完而額度有剩，繼續取下一個有新字的 K／KK 課，遇到無新字的課（K10、K16–K19）或 L 課即停。
- 拗音依規律整批教：同一 `row`（きゃ きゅ きょ）計為 1 字額度，一次教完。
- K10、K16–K19 這類無新字的課，為整課一個切片、算一天。

| 課 ID | 內容 | 新字數 | 教學重點 |
|---|---|---|---|
| le.k01 | あ行 | 5 | 五母音；う 不圓唇 |
| le.k02 | か行 | 5 | 不送氣傾向 |
| le.k03 | さ行 | 5 | し 的音值 |
| le.k04 | た行 | 5 | ち、つ 的音值 |
| le.k05 | な行 | 5 | |
| le.k06 | は行 | 5 | ふ 的音值 |
| le.k07 | ま行 | 5 | |
| le.k08 | や行＋わ・を・ん | 6 | ん 自成一拍 |
| le.k09 | ら行 | 5 | 不是ㄌ也不是ㄖ |
| le.k10 | 平假名總檢 | 0 | 易混淆字組對決 |
| le.k11 | が行、ざ行 | 10 | 清濁聽辨開始 |
| le.k12 | だ行、ば行 | 10 | ぢ／づ 與 じ／ず 同音 |
| le.k13 | ぱ行 | 5 | ば／ぱ 對比 |
| le.k14 | 拗音（清音 7 行） | 21（額度 7） | きゃ…りょ；不是兩拍 |
| le.k15 | 拗音（濁音、半濁音 4 行） | 12（額度 4） | ぎゃ じゃ びゃ ぴゃ 行 |
| le.k16 | 促音 っ | 規則 | 停一拍；きて／きって |
| le.k17 | 長音 | 規則 | おばさん／おばあさん；え段＋い、お段＋う 的讀法 |
| le.k18 | 助詞 は・へ・を、ん 的音值、母音無聲化 | 規則 | 讀作 wa／e／o；です 的 u |
| le.k19 | 音調入門與平假名畢業考 | 規則 | 日語是高低音，不是四聲；示範 雨／飴 |
| le.kk01 | ア行、カ行（接在 L01 後） | 10 | 由偏旁助記 |
| le.kk02 | サ行、タ行（接在 L02 後） | 10 | シ／ツ 專練 |
| le.kk03 | ナ行、ハ行（接在 L03 後） | 10 | |
| le.kk04 | マ行、ヤ行（接在 L04 後） | 8 | |
| le.kk05 | ラ行、ワ・ヲ・ン（接在 L05 後） | 8 | ソ／ン 專練 |
| le.kk06 | 濁音、半濁音（接在 L06 後） | 25 | 規則與平假名相同 |
| le.kk07 | 拗音、ッ、ー（接在 L07 後） | 33（額度 11） | 長音用「ー」 |
| le.kk08 | 擴充拼法與外來語規則（接在 L08 後） | 21 | ウィ ウェ ウォ シェ ジェ チェ ティ ディ デュ トゥ ドゥ ツァ ファ フィ フェ フォ ヴ ヴァ ヴィ ヴェ ヴォ |

總數：平假名 104（46＋25＋33）、片假名 125（104＋擴充 21）、符號 9（`kind: "mark"`：っ ゃ ゅ ょ、ッ ー ャ ュ ョ，不出題、不建卡、不佔字額度，只供 R06 判定與 `listen_disabled` 回寫）、規則卡 7 張（`ka.rule.sokuon`、`.chouon_hira`、`.chouon_kata`、`.n`、`.devoice`、`.particle_read`、`.accent_intro`）。L01–L08 的句子受假名閘門限制（R06），片假名字在其字母教過前不能出現，所以這幾課只用和語、漢語詞。

### 3.2 易混淆字組（`ka.cf.*`）

| 類型（`kind`） | 字組 |
|---|---|
| 平假名字形（`shape`，15 組） | ぬ／め、る／ろ、わ／れ／ね、は／ほ、さ／ち、き／さ、い／り、あ／お、け／は、こ／に、た／な、ま／よ、う／つ、し／も、ら／ち |
| 片假名字形（`shape`，11 組） | シ／ツ、ソ／ン、ノ／メ、ク／ケ／タ、ウ／ワ／フ、ス／ヌ、コ／ユ／ロ、チ／テ／ナ、ア／マ、ラ／フ、ヲ／ワ |
| 平片假名跨文字（`cross_script`，7 組） | へ／ヘ、り／リ、か／カ、き／キ、せ／セ、も／モ、や／ヤ |
| 片假名與漢字（`kana_kanji`，中文讀者特有，8 組） | カ／力、ニ／二、ハ／八、ミ／三、エ／工、ロ／口、タ／夕、ト／卜 |
| 聽音（`listen`，12 組，含最小對立字） | か／が、た／だ、は／ば／ぱ、し／ち、す／つ、しゅ／す、ちゅ／つ、じゃ／ざ、おばさん／おばあさん、おじさん／おじいさん、きて／きって、ビル／ビール |

`members` 只放 `ka.*` ID；漢字或整個詞放 `literals`（§12.4）。`kana_confuse` 只出 `shape`、`cross_script` 兩類；`kana_kanji`、`listen` 用於說明與 `minimal_pair`。

### 3.3 假名練習題型

| type | 題型 | 說明 |
|---|---|---|
| `kana_read` | 認字 | 顯示字，四選一選讀音（字母選項），答後自動播音 |
| `kana_listen` | 聽音選字 | 只播音，四選一選字，不顯示羅馬字；`listen_disabled: true` 的字不出此題，改出 `kana_read` |
| `kana_match` | 配對 | 假名與讀音連線，一次 5 對，計時 |
| `kana_confuse` | 混淆對決 | 只出同一 `ka.cf.*` 字組的字，連續判斷 |
| `minimal_pair` | 最小對立聽辨 | 播 A 或 B，二選一，用於清濁、長短、促音（代碼 `mpr`） |
| `kana_word` | 拼讀實字 | 只用已學假名組成的真實單字，先讀再聽，有中文意思（代碼 `kwd`，JSON 見 §12.5） |

假名與規則卡以外的題目多由程式依表生成，不需手寫。`minimal_pair` 與 `kana_word` 需手寫（§14）。

**先教後考**：每批新字先逐字呈現（大字、自動播音一次、`origin_kanji`、`hint_zh`、例字），呈現完該字才進測驗。第一批只有 3 字，第一題必定考剛呈現過的字。

**熟練與 FSRS**：只有 `kana_read`、`kana_listen`、`kana_confuse` 的作答計入熟練。同一字連續答對 2 次即「熟練」，建立 `:read` 卡。3 秒時限只決定徽章，答慢不歸零；`kana_listen` 從播放結束起算，設定中可關閉時限。切片的 `complete_task` 只寫 `item_intro`；當日結案時還沒熟練的字由 `complete_task` 補建 state＝0 的 `:read` 卡，`kana_mastery` 只影響徽章與重練，所以未達標的字不會進不了 FSRS。K／KK 課完成＝全部字已 `item_intro` 且該課規則卡讀過。

**畢業考**：K19 與 KK08 只抽假名與規則題，90% 決定蓋章與是否建議複習，未達標不阻擋（§11.1）。手寫描紅與筆順列為暫不實作（§14）。

### 3.4 規則卡與語音示範

規則卡（`ka.rule.*`，JSON 見 §12.4）在 K16–K19（`chouon_kata` 在 KK07）各有獨立畫面：標題、說明、例字；`examples[].beats` 非空時做拍感示範（依拍逐格亮起並等距播放），下方「測試一下」進 `minimal_pair`。

語音示範組（`kana/sound_groups.json`，共 16 組）依 `kind` 分區：

| kind | 組別 |
|---|---|
| `voicing` | `ka.sg.voicing_k`（か／が）、`ka.sg.voicing_s`、`ka.sg.voicing_t`、`ka.sg.voicing_h`（は／ば／ぱ） |
| `length` | `ka.sg.length_vowel`（おばさん／おばあさん）、`ka.sg.length_ei_ou`、`ka.sg.length_kata`（ビル／ビール） |
| `sokuon` | `ka.sg.sokuon_basic`（きて／きって）、`ka.sg.sokuon_kata`（バグ／バッグ） |
| `yoon` | `ka.sg.yoon_shu_su`、`ka.sg.yoon_chu_tsu`、`ka.sg.yoon_ja_za` |
| `accent` | `ka.sg.accent_ame`（雨／飴）、`ka.sg.accent_hashi`（箸／橋／端）、`ka.sg.accent_hana`（花／鼻）、`ka.sg.accent_kami`（神／紙） |

`accent` 組的畫面固定標註「由裝置合成，僅供參考」。實機聽不出差別的配對設 `listen_disabled: true`，該配對不再播放與出題（§10.1）。

## 4. 單字

### 4.1 總量與理由

目標 **1,400 筆**：S1–S2 800、S3 600（原為 1,600，含專區 200；專區移除後改為 1,400，RULINGS O13）。

理由：舊制 4 級、3 級規格約 800 與 1,500 字，是目前最常被引用的基準；1,400 字足以覆蓋本課程主線。選字優先序：口語頻率、場景需要、JLPT 參考級別。JLPT 舊清單裡口語罕用的詞（如万年筆）可替換，但要維持總數。

`jlpt` 欄依基準清單（`reuse-and-verification.md` §3.2）標示，不在清單者標 `beyond`；§4.2 的欄名是課程階段，不是 JLPT 級別，涵蓋率分母維持實測清單的筆數。

### 4.2 主題清單（`topics[0]` 為主要主題，每筆可有多個）

| 主題 slug | 內容 | S1–S2 | S3 | 合計 |
|---|---|---:|---:|---:|
| greet | 問候與固定用語 | 40 | 15 | 55 |
| people | 人稱、家人、人物關係 | 50 | 25 | 75 |
| job | 職業與身分 | 15 | 20 | 35 |
| number | 數字與量詞 | 50 | 15 | 65 |
| time | 時間、日期、星期、頻率 | 55 | 25 | 80 |
| food | 食物、飲料、餐廳 | 50 | 30 | 80 |
| shop | 購物、金錢、衣物 | 30 | 30 | 60 |
| place | 場所與建築 | 40 | 25 | 65 |
| direction | 方位與問路 | 20 | 10 | 30 |
| transport | 交通與車站 | 25 | 25 | 50 |
| home | 住家、家具、日用品 | 40 | 25 | 65 |
| body | 身體、健康、看病 | 20 | 40 | 60 |
| nature | 天氣、季節、自然 | 25 | 25 | 50 |
| animal | 動植物 | 10 | 10 | 20 |
| school | 學校與學習 | 30 | 15 | 45 |
| work | 工作與職場 | 10 | 30 | 40 |
| hobby | 興趣、娛樂、運動 | 20 | 25 | 45 |
| travel | 旅行與住宿 | 5 | 30 | 35 |
| device | 手機、網路、3C | 10 | 15 | 25 |
| emotion | 情感與個性 | 15 | 40 | 55 |
| adj | 基本形容詞 | 60 | 30 | 90 |
| verb | 基本動詞 | 90 | 65 | 155 |
| adverb | 副詞與程度詞 | 30 | 25 | 55 |
| connector | 接續詞與功能詞 | 10 | 5 | 15 |
| question | 疑問詞 | 20 | 0 | 20 |
| demonstrative | {ja:こそあど}與指示 | 30 | 0 | 30 |
| **合計** | | **800** | **600** | **1,400** |

階段分配：S1 350 字（L01–L14，每課約 25）、S2 450 字（L15–L30，每課約 28）、S3 600 字（L31–L48，每課約 33）。

### 4.3 欄位需求

| 欄位 | 必填 | 說明 |
|---|---|---|
| id | 是 | §12.1 |
| lesson | 是 | 首次教學的課，全域順序依據 |
| lesson_order | 是 | 正整數，同一 `lesson` 內由 1 起連號，切片依此排序（R20）。鍵名不得用 `seq` |
| surface | 是 | 常用表記（漢字＋假名）；只寫假名的詞就寫假名。`vs` 動詞只寫語幹（勉強），活用由獨立的 `vo.suru` 承擔（§12.2） |
| kana | 是 | 讀音，含空白時羅馬字走句子模式（`こんにち は`→konnichi wa）；無空白走單詞模式（`は`→ha） |
| zh | 是 | 繁中釋義陣列，最常用的放第一個 |
| pos | 是 | `n pron num counter v5 v1 v1_s vs vk adj_i adj_na adv conj interj phrase`。可接 する 的名詞、以動詞用法為主者標 `vs`；`v1_s` 是特殊一段（JMdict `v1-s`，只有 くれる），見 §12.4 |
| trans | 動詞必填 | `tr`、`in`、`both`；自他成對的用 `pair` 欄位指向對方 |
| accent | 否 | 音調核位置，見 §4.4 |
| jlpt | 是 | `n5`、`n4`、`beyond`，代表「參考」級別，依基準清單標示（§4.1） |
| topics | 是 | 主題 slug 陣列（§4.2） |
| examples | 是 | 至少 2 個 `se.*`，`examples[0]` 必須與該字同課 |
| tts | 否 | `kana`（預設）或 `auto`。單獨發音的誤讀風險最高，所以預設送假名；只有音調最小對立約 40 筆標 `auto` |
| same_form_zh | 否 | 布林，預設 `false`。與中文同形的詞（電話、学校、勉強）標 `true`：`recog` 只顯示假名或先播音再選意思，`listen` 提升為 priority 0 |
| hook_zh、trap_zh | 否 | 記憶鉤、誤用提醒 |
| notes | 否 | 指向 `no.*`（同形異義、字形差異） |
| reading_family | 否 | 同字異讀的單字 ID |
| use_level | 否 | `safe`（預設）、`friends_only`、`recognize_only`（只求聽懂，粗話必用） |
| conj_omit | 否 | 活用形名稱陣列，預設空。引擎算得出、但這個詞實際不用的形，單字詳情的活用表不顯示，見 §12.4 |

**首次學字**（新內容學習頁）：依 `lesson_order` 逐筆呈現 `surface`、`kana`（振假名）、`zh`、`hook_zh`、`trap_zh`、`notes` 與例句，自動播音後立即一題 `recog`（`same_form_zh` 的字用假名或先播音版）。**搜尋**比對 `surface`、`kana`、由 `kana` 推導的羅馬字（使用者打羅馬字時轉假名比對）與 `zh`。已會、收藏是使用者狀態，不是內容欄位。

### 4.4 音調重音（accent）的決定

**納入為可空欄位，只在有可靠來源時才填，不由撰寫代理憑記憶填寫。**

- 值為下降核位置：0 平板、1 頭高、n 第 n 拍後下降。`null` 時 App 不顯示音調線。
- 理由一：中文母語者容易把語調讀成四聲，音調入門有價值；少數最小對立確實影響理解。
- 理由二：初學者的注意力有限，且 TTS 本身的音調不保證正確，所以不對全部單字施加音調練習，也不考音調。
- 音調最小對立只填約 40 筆，例如 雨 1／飴 0、箸 1／橋 2／端 0、柿 0／牡蠣 1、花 2／鼻 0、神 1／紙 2、酒 0／鮭 1。這些值已與 Kanjium 的音調資料核對。這 40 筆 `tts` 標 `auto`，讓引擎依漢字發音。
- 全面匯入 Kanjium 資料涉及 CC BY-SA 4.0 的署名與相同方式分享義務，由專案擁有者日後決定，不預設匯入。

### 4.5 預告語塊（已移除）

已移除（見 RULINGS O13）。節號保留，不重新編號。

## 5. 文法（有序清單）

每列的文法點依序教學，每課 3–6 點。`di.*` 為該課主對話。S1、S2 涵蓋 N5 全範圍（少數 N4 級但口語必要者提前），S3 為 N4 口語重點。

### 5.1 S1 敬體基礎

| 課 | 主題 | 主對話 | 文法點 |
|---|---|---|---|
| L01 | 初次見面 | di.self_intro | gr.wa_topic は（主題）；gr.desu N です；gr.ja_arimasen じゃありません／ではありません；gr.ka_q 〜か（疑問）；gr.no_poss N の N（所屬）；gr.san_title 〜さん（不可用於自己） |
| L02 | 這是什麼 | di.whats_this | gr.kore_sore これ・それ・あれ・どれ；gr.kono_sono この・その・あの・どの；gr.mo_also も；gr.nan_nani 何（なん／なに）；gr.sou_desu そうです／そうじゃありません；gr.ka_choice 〜ですか、〜ですか（選擇問） |
| L03 | 多少錢 | di.konbini | gr.numbers 數字與〜円；gr.ikura いくら；gr.koko_soko ここ・そこ・あそこ・どこ；gr.n_kudasai N をください（語塊）；gr.onegai N をお願いします（語塊）；gr.no_pron_own の（我的：私のです） |
| L04 | 幾點 | di.opening_hours | gr.jikan 〜時〜分・〜曜日・〜月〜日；gr.kara_made から／まで；gr.desu_past でした／じゃありませんでした；gr.to_and N と N；gr.goro ごろ |
| L05 | 每天做的事 | di.daily_routine | gr.masu ます／ません；gr.wo_obj を；gr.de_place で（動作場所）；gr.ni_time に（時間點）；gr.freq_adv 毎日・よく・時々・あまり〜ない・全然〜ない |
| L06 | 去哪裡 | di.weekend | gr.ni_e_dir に／へ（方向）；gr.de_means で（手段）；gr.to_with と（一起）；gr.masu_past ました／ませんでした；gr.q_ka_mo 疑問詞＋か／も（何か、誰も） |
| L07 | 一起去吧 | di.invite_movie | gr.masen_ka 〜ませんか；gr.mashou 〜ましょう；gr.mashou_ka 〜ましょうか；gr.sfp_ne ね；gr.sfp_yo よ；gr.ni_purpose 動詞ます幹＋に行く |
| L08 | 有沒有、在哪裡 | di.where_is | gr.aru_iru ある／いる；gr.ni_exist に（存在場所）；gr.ga_subject が（新資訊主語）；gr.position 上・下・中・前・後ろ・隣・間；gr.ya_nado や〜など |
| L09 | 形容事物 | di.my_town | gr.i_adj い形容詞現在肯否；gr.na_adj な形容詞現在肯否；gr.adj_mod 形容詞＋N（禁「大きいの車」）；gr.totemo とても・ちょっと・あまり；gr.dou_donna どう／どんな |
| L10 | 喜歡與擅長 | di.hobbies | gr.adj_past 形容詞過去；gr.suki が好き／嫌い；gr.jouzu が上手／下手；gr.wakaru が分かる；gr.ga_but 〜が（但是）；gr.wa_ga N は N が（大主語） |
| L11 | 數量與點餐 | di.restaurant | gr.counters 〜つ・人・枚・本・匹・冊・台・個・杯；gr.counter_pos 量詞位置；gr.dake だけ；gr.shika しか〜ない；gr.gurai くらい；gr.kai_freq 〜に〜回 |
| L12 | 想要、想做 | di.travel_wish | gr.hoshii が欲しい；gr.tai 〜たい；gr.kara_because 〜から（理由）；gr.doushite どうして／なぜ；gr.connectors そして・それから・でも・じゃあ；gr.ka_or N か N（或） |
| L13 | 比較與選擇 | di.choose_gift | gr.yori より；gr.hou_ga 〜のほうが；gr.ichiban 〜の中で一番；gr.dochira どちら；gr.onaji と同じ；gr.wa_contrast は（對比） |
| L14 | 動詞三類 | di.meet_friend | gr.verb_groups 動詞三類；gr.dict_form 辭書形；gr.ni_target に（對象：会う）；gr.ni_arrive に（到達、搭乘）；gr.wo_leave を（離開、經過）；gr.zutsu ずつ |

### 5.2 S2 動詞變化與常體

| 課 | 主題 | 主對話 | 文法點 |
|---|---|---|---|
| L15 | 請做 | di.ask_way | gr.te_form て形；gr.te_kudasai 〜てください；gr.te_kudasai_masen 〜てくださいませんか |
| L16 | 正在做、狀態 | di.phone_where | gr.te_iru_prog 〜ています（進行）；gr.te_iru_state 〜ています（狀態、住む、結婚）；gr.shitte_iru 知っています／知りません |
| L17 | 接著做 | di.station_ticket | gr.te_seq 〜て（順序）；gr.te_kara 〜てから；gr.adj_te くて／で（連接）；gr.adv_form 〜く／〜に（副詞化） |
| L18 | 否定形 | di.library_rules | gr.nai_form ない形；gr.naide_kudasai 〜ないでください；gr.nai_de 〜ないで（沒做而…） |
| L19 | 可以、不行 | di.museum_rules | gr.te_mo_ii 〜てもいいです；gr.te_wa_ikenai 〜てはいけません；gr.demo_example 〜でも（舉例） |
| L20 | 經驗與列舉 | di.travel_story | gr.ta_form た形；gr.ta_koto 〜たことがあります；gr.tari 〜たり〜たりする |
| L21 | 常體 | di.friends_casual | gr.plain_style 常體系統；gr.da_copula だ；gr.casual_q 常體問句（升調、〜の）；gr.particle_drop 口語省略助詞；gr.un_uun うん／ううん |
| L22 | 我覺得、他說 | di.opinion_movie | gr.to_omou 〜と思います；gr.to_iu 〜と言います；gr.deshou でしょう；gr.sfp_kana かな |
| L23 | 名詞修飾 | di.lost_item | gr.rel_clause 連體修飾（禁「買ったの本」）；gr.ga_in_rel 子句內的 が；gr.no_one の（〜的那個）；gr.to_iu_n という N；gr.wa_vs_ga は／が 總整理 |
| L24 | 會做 | di.part_time | gr.koto_nominal こと；gr.no_nominal の（名詞化）；gr.koto_ga_dekiru 〜ことができる；gr.dekiru_n N ができる；gr.kata 〜方 |
| L25 | 必須、建議 | di.clinic | gr.nakereba 〜なければなりません；gr.nakute_mo_ii 〜なくてもいいです；gr.hou_ga_ii 〜ほうがいい／ないほうがいい |
| L26 | 時間子句 | di.trip_plan | gr.toki 〜とき；gr.mae_ni 〜前に；gr.ato_de 〜あとで；gr.nagara 〜ながら；gr.chu_juu 〜中（ちゅう／じゅう） |
| L27 | 變化 | di.getting_better | gr.naru 〜くなる／になる；gr.suru_change 〜くする／にする；gr.mou_mada もう／まだ；gr.mada_te_inai まだ〜ていません；gr.ni_suru 〜にします（決定） |
| L28 | 給與收 | di.birthday | gr.ageru あげる；gr.kureru くれる；gr.morau もらう；gr.ni_kara_source に／から（來源） |
| L29 | 說明語氣 | di.excuse_late | gr.n_desu 〜んです；gr.ndesu_ga 〜んですが（鋪陳）；gr.node ので；gr.kedo_soft 〜けど（句尾緩和） |
| L30 | N5 總複習 | di.n5_day | 無新文法，綜合演練與里程碑測驗 |

### 5.3 S3 N4 口語核心

| 課 | 主題 | 主對話 | 文法點 |
|---|---|---|---|
| L31 | 能力 | di.can_you_speak | gr.potential 可能形；gr.mieru 見える／聞こえる；gr.ga_potential 可能句的 が；gr.ka_embed 〜か（嵌入問句）；gr.ka_douka 〜かどうか |
| L32 | 打算 | di.new_year_plans | gr.volitional 意向形；gr.you_to_omou 〜ようと思う；gr.tsumori つもり；gr.yotei 予定 |
| L33 | 如果（一） | di.if_rain | gr.tara 〜たら；gr.tara_ii 〜たらいい；gr.tara_dou 〜たらどう |
| L34 | 如果（二） | di.how_to_machine | gr.to_natural と（自然結果）；gr.ba 〜ば；gr.nara なら；gr.ba_ii 〜ばいい |
| L35 | 完成與準備 | di.forgot_wallet | gr.te_shimau 〜てしまう；gr.te_oku 〜ておく；gr.te_miru 〜てみる |
| L36 | 狀態與方向 | di.hotel_room | gr.jita 自他動詞；gr.te_aru 〜てある；gr.te_iku 〜ていく；gr.te_kuru 〜てくる |
| L37 | 幫忙 | di.moving_help | gr.te_ageru 〜てあげる；gr.te_kureru 〜てくれる；gr.te_morau 〜てもらう；gr.te_hoshii 〜てほしい；gr.te_moraemasu 〜てもらえますか |
| L38 | 看起來、聽說 | di.looks_delicious | gr.sou_look 〜そう（樣態）；gr.sou_hear 〜そうだ（傳聞）；gr.kamo かもしれない；gr.hazu はず；gr.ni_yoru によると |
| L39 | 好像 | di.rumor | gr.you_da ようだ；gr.mitai みたい；gr.rashii らしい；gr.garu 〜がる |
| L40 | 雖然、即使 | di.complain_friend | gr.te_mo 〜ても；gr.noni 〜のに；gr.shi 〜し；gr.ba_hodo 〜ば〜ほど |
| L41 | 被 | di.bad_day | gr.passive 受身；gr.passive_trouble 受害受身；gr.passive_social 社會事實受身 |
| L42 | 叫人做 | di.parents_kids | gr.causative 使役；gr.sasete 〜させてください；gr.causative_passive 使役受身 |
| L43 | 命令與禁止 | di.sports_coach | gr.imperative 命令形；gr.prohibit 〜な（禁止）；gr.nasai 〜なさい；gr.te_kure 〜てくれ |
| L44 | 複合動詞 | di.cooking_class | gr.sugiru 〜すぎる；gr.yasui_nikui 〜やすい／〜にくい；gr.hajimeru_owaru 〜始める／〜終わる；gr.tsuzukeru 〜続ける；gr.sa_noun 〜さ（名詞化） |
| L45 | 變化與決定 | di.new_habit | gr.you_ni_naru 〜ようになる；gr.you_ni_suru 〜ようにする；gr.koto_ni_naru 〜ことになる；gr.koto_ni_suru 〜ことにする |
| L46 | 時間的細節 | di.just_arrived | gr.tokoro 〜ところ；gr.ta_bakari 〜たばかり；gr.aida 〜間；gr.uchi_ni 〜うちに；gr.made_ni 〜までに；gr.mama 〜まま |
| L47 | 敬語（一）尊敬 | di.first_visit | gr.keigo_map 敬語三分類；gr.sonkei 尊敬語（いらっしゃる等）；gr.o_ni_naru お〜になる；gr.o_kudasai お〜ください |
| L48 | 敬語（二）謙讓與總複習 | di.business_call | gr.kenjou 謙讓語（参る、申す等）；gr.o_suru お〜する；gr.gozaimasu ございます／でございます；gr.ni_tsuite について |

### 5.4 每個文法點的欄位

`id`、`lesson`、`lesson_order`（同 §4.3）、`jlpt`、`title_zh`、`pattern`（句型公式）、`meaning_zh`、`explain_zh`（150 字內，白話，先講用法再講規則）、`compare_zh`（與中文的對照，必填）、`trap_zh`（常見錯誤）、`formation`（接續變化表）、`register`（`polite`、`plain`、`neutral`）、`requires`（前置文法 ID）、`examples`（至少 6 個 `se.*`）、`contrast`（相近文法 ID）、`terms`（可選，`no.term.*` 的 ID 陣列，文法頁顯示為可點入的術語筆記）。

`pattern`、`formation` 內的日文一律用 `{ja:}` 標記（§12.2）。

## 6. 句型演練

### 6.1 題型總表

JSON 範例見 §12.5。所有題目共同欄位：`id`、`type`、`lesson`、`targets`（練習對象 ID，也是答後「語法重點」的來源）。

| type | 代碼 | 題型 | 額外欄位 | 建議占比 |
|---|---|---|---|---:|
| `substitution` | sub | 替換：顯示中文提示，同 slot 其他列的值作選項；句框逐列列出，不做笛卡兒積，避免出現「喝麵包」。`rows` 至少 3 列，不足就改寫為 `reorder` | `frame`、`rows[]`（各 slot 值、`zh`、`tts?`） | 15% |
| `reorder` | ord | 排序：詞塊由程式依分詞自動切（助詞黏前詞）。`audio_first` 為 true 時即聽寫拼句 | `sentence`、`accept_orders`、`audio_first` | 20% |
| `particle_fill` | par | 填助詞：選項必須都是已教助詞，`blanks` 長度固定為 1（R12） | `sentence`、`blanks[]`（`word_index`、`choices`）、`explain_zh` | 15% |
| `zh_to_ja_choice` | z2j | 中翻日選擇：干擾項為中文母語者典型錯誤 | `prompt_zh`、`answer`、`distractors[]`（`t`、`why_zh`）、`tts?` | 15% |
| `listen_meaning` | lsn（實戰對話的 quiz 用 lsx、常體版用 lsc，避免和主線流水號相撞） | 聽力選意思：文字在作答前隱藏 | `sentence`、`choices_zh`、`answer_index` | 15% |
| `situation_response` | sit | 依情境選回應：同時考內容與語體是否得體 | `situation_zh`、`prompt?`、`answer`、`distractors[]`、`tts?` | 10% |
| `conjugate` | cnj | 變化練習：答案由 Rust 變化引擎生成，不手寫 | `form`（masu、te、ta、nai、potential、volitional、ba、passive、causative、imperative）、`lemmas[]` | 程式生成，不計占比 |
| `register_convert` | reg | 敬體與常體互換，L21 起。一律為 Reorder 題 | `from`、`to`（皆為 `se.*`） | 5% |
| `shadowing` | shd | 跟讀：播放、留空檔、三級自評，不評分，不進 FSRS，只存練習統計 | `sentence` | 5% |
| `false_friend` | ffr | 漢字同形異義判斷 | `note`、`prompt_zh`、`choices_zh`、`answer_index` | 隨單字 |
| `minimal_pair` | mpr | 最小對立聽辨（§3.3） | `a`、`a_zh`、`b`、`b_zh`、`a_kana?`、`b_kana?`、`a_tts_text?`、`b_tts_text?`、`listen_disabled?` | 假名手寫 |
| `kana_word` | kwd | 拼讀實字（§3.3） | `word`、`zh`、`mode`、`choices_zh?`、`answer_index?` | 假名手寫 |

每個文法點至少 4 題且涵蓋 3 種以上題型（R09）。每課手寫約 30 題。`tts?` 為題目層級，套用到該題所有內嵌 `t`（`prompt`、`answer`、`distractors[].t`），省略時為 `auto`。

`question_type` 值域（無欄位 enum，供 UI 窮舉）：`recog`、`vocab_listen`、`produce`、上表全部 type，以及 `kana_read`、`kana_listen`、`kana_match`、`kana_confuse`。

## 7. 情境對話

每課一篇主對話（§5 表內 ID），6–12 句來回，另有 12 篇實戰場景與 16 篇常體版本。

| 要求場景 | 對應 ID |
|---|---|
| 自我介紹 | di.self_intro（L01）、常體版 L21 後 |
| 點餐 | di.restaurant（L11）、di.x_izakaya（L33） |
| 購物 | di.konbini（L03）、di.choose_gift（L13）、di.looks_delicious（L38） |
| 問路 | di.ask_way（L15）、di.x_lost_way（L21） |
| 車站 | di.meet_friend（L14）、di.station_ticket（L17） |
| 看醫生 | di.clinic（L25）、di.x_pharmacy（L29） |
| 打電話 | di.phone_where（L16）、di.business_call（L48） |
| 交朋友 | di.hobbies（L10）、di.friends_casual（L21）、di.opinion_movie（L22） |

**實戰場景（12 篇）**：di.x_onsen（L19 溫泉規矩）、di.x_lost_way（L21 迷路問朋友）、di.x_post_office（L24 郵局）、di.x_emergency（L25 受傷求助）、di.x_taxi（L26 計程車）、di.x_pharmacy（L29 藥局）、di.x_party（L32 約聚會）、di.x_izakaya（L33 居酒屋）、di.x_bank（L34 換匯）、di.x_airport（L36 機場）、di.x_hair_salon（L37 剪髮）、di.x_real_estate（L40 租屋）。

**常體版本（16 篇，`di.<slug>.casual`，`lesson` 不早於 L21）**：self_intro、whats_this、weekend、invite_movie、where_is、hobbies、travel_wish、choose_gift、phone_where、travel_story、lost_item、birthday、if_rain、looks_delicious、rumor、bad_day。

實戰與常體版納入 Integration 輪替：每完成 3 課，下一個整合日改排 1 篇，依 `lesson` 由舊到新。

對話結構：`kind`（`lesson`、`extra`、`casual`）、`scene_zh`（時地人）、`goal_zh`（這段要完成什麼）、`roles`、`style`、`turns[]`（`role`、`t`、`zh`、`note_zh?`、`tts?`）、`focus`（重點 ID）、`quiz`（2–3 個 `listen_meaning` 的 `dr.*` ID 陣列）。流程固定：先只聽一次猜情境，看字逐句學習，跟讀，最後角色扮演（使用者自選角色，對方由 TTS 發聲）。

## 8. 日劇聽解專區（已移除）

已移除（見 RULINGS O13）。章號保留，不重新編號。

## 9. 日文歌專區（已移除）

已移除（見 RULINGS O13）。章號保留，不重新編號。

## 10. 語音示範

### 10.1 哪些內容要能播放

假名、單字、例句、對話逐句、對話全篇連播、演練題（題幹與答後解答）。

| 模式 | 用途 | 規格 |
|---|---|---|
| 正常 | 預設 | 語速 1.0 倍 |
| 慢速 | 初學、聽不清時 | 約 0.7 倍；所有播放鈕旁一鍵切換，記住使用者偏好 |
| 逐詞 | 句子拆解 | 依 `t` 的詞邊界逐詞播放，詞間停頓約 400 毫秒 |
| 跟讀 | shadowing | 播一句、留「句長×1.5」的空檔，三級自評 |

**TTS 輸入**。所有 `t`（句子、對話 `turns`、`substitution` 的 `rows`、題目內嵌 `t`）都依 `tts` 決定：`auto` 送漢字原文（引擎較能判斷音調），`kana` 送分詞假名。必須送假名的情況：義訓、多音字有誤讀風險者（`content/lint/tts_risky.txt` 只收確定會誤讀的詞，命中而未標註則 lint 失敗）、含 `@name` 的句子（一律 `kana`）。送假名時先把獨立成詞的助詞 は／へ 換成 わ／え。單字預設 `kana`（§4.3）。

`tts_risky.txt` 首版收：今日、一日、方、辛い、行った。何、人 太常見，先不收，由實機抽聽後回寫。kana 模式送出前的空白處理以實機試聽定案。

**實機驗證不是開發前置條件**。內容先用保守預設，專案產出 `docs/TTS_DEVICE_CHECKLIST.md` 供專案擁有者在 Android、iOS 實機檢查，結果透過 `tts_text`、`listen_disabled` 欄位回寫，不需改程式。

| 項目 | 保守預設 | 實機結果回寫 |
|---|---|---|
| 一般單假名 | `tts_text` 省略（送 `char`），`listen_disabled: false` | 念成字母名或不穩定：先換 `tts_text`；仍不佳設 `listen_disabled: true`，不出 `kana_listen`，改出 `kana_read` |
| ん | `tts_text: "ん"`（以本字送出），列入清單 | 同上 |
| っ、ー、ゃゅょ（`kind: "mark"`） | `listen_disabled: true` | 維持 |
| `minimal_pair`、語音示範組的配對 | `listen_disabled` 省略（`false`），`accent` 組列入清單 | 無法通過人耳驗收的配對設 `listen_disabled: true` |

語音不可用時，需語音的題目由 `audio_available` 排除，不記對錯、不寫 FSRS。

### 10.2 文字顯示與隱藏

| 內容 | 羅馬字 | 振假名 | 聽力時 |
|---|---|---|---|
| S0 | 顯示 | 不適用 | `kana_listen` 不顯示任何文字 |
| L01–L04 | 預設顯示，可關 | 全顯示 | 作答前隱藏日文與羅馬字，答後顯示 |
| L05–L08 | 預設隱藏，點擊顯示 | 全顯示 | 同上 |
| L09–L30 | 預設關，長按單字才顯示（`ms.kata` 通過或使用者確認後生效；否則維持 L05–L08 的行為） | 預設全顯示 | 同上 |
| L31 起 | 預設關（生效條件同上） | 預設「僅未熟單字」 | 同上；中文翻譯也在答後才出現 |

顯示規則以該內容所屬的課計算，回看舊課時不受目前進度影響。K1 五十音表永遠顯示羅馬字。

`listen_meaning` 在作答前畫面上不得出現題目的日文、假名或羅馬字。`audio_first` 的排序題先播放（不顯示文字），播完才顯示打散的詞塊，完整句子到答題後才出現。答題後必須一次展開全文、假名、中文、語法重點（來自 `targets`）。L01–L06 另提供分詞空格顯示，幫助斷句。

### 10.3 誠實限制（介面需說明）

語音由裝置合成，音調可能不完全正確，也沒有真人的情緒與語速。

## 11. 學習計畫

### 11.1 里程碑

檢定是該課完成後的附加任務，不是課型，不阻擋游標，可「先略過」（`checkpoint_dismiss`）。`milestone.lesson` 是檢定所在課的唯一來源。

| ID | 達成點 | 建議門檻 | 通過時 |
|---|---|---|---|
| ms.hira | K19 | 平假名畢業考 90% | 蓋章 |
| ms.kata | KK08 | 片假名畢業考 90% | 蓋章；L09 起羅馬字預設關閉（§10.2） |
| ms.survive | L07 | 檢定 80% | 「我能自我介紹與約人」成就 |
| ms.a1_half | L14 | 檢定 80% | 蓋章 |
| ms.casual | L21 | 檢定 80% | 蓋章 |
| ms.n5 | L30 | 檢定 80% | 蓋章 |
| ms.n4_mid | L40 | 檢定 80% | 蓋章 |
| ms.n4 | L48 | 檢定 80% | 蓋章 |

檢定 20 題，從累積內容抽題，K19、KK08 只抽假名與規則題。建議門檻一律軟性：只決定蓋章與是否建議複習，未通過不鎖任何內容。UI 的里程碑線依已發布的 `milestones` 動態繪製。

### 11.2 每日任務配比（以 S2 為基準的分鐘數）

每日任務順序：到期複習、新內容、演練、聽力，學習中的卡片與前幾天建立、尚未接觸的卡片於尾端收尾。

| 每日 | 新內容 | FSRS 複習 | 句型演練 | 聽力與跟讀 | 每日新字上限（`new_words_per_day`） | 假名額度（`kana_chars_per_day`） |
|---:|---:|---:|---:|---:|---:|---:|
| 10 分 | 2 | 6 | 1 | 1 | 3 | 3 |
| 20 分（預設） | 4 | 9 | 4 | 3 | 5 | 5 |
| 30 分 | 6 | 14 | 6 | 4 | 8 | 8 |
| 45 分 | 9 | 20 | 9 | 7 | 12 | 10 |

各階段的比例（分鐘數按比例換算，四捨五入到 0.5 分，餘數歸複習）：

| 階段 | 新內容 | 複習 | 演練 | 聽力 |
|---|---:|---:|---:|---:|
| S0 | 60% | 40% | 0% | 0% |
| S1 | 25% | 40% | 25% | 10% |
| S2 | 20% | 45% | 20% | 15% |
| S3 | 20% | 45% | 15% | 20% |

S0 沒有句子，也沒有獨立的演練任務，所以不給演練與聽力額度，併入新內容的假名練習。S0 的複習給 40%，因為 KK01–KK08 排在 L07 之後，片假名期間已有 L01–L07 的字卡要複習；10 分方案的 S2 把演練 1 分移給複習（原為 2／5／2／1）。兩項都是用學習迴路模擬定的（RULINGS O11）：只用 30% 時，10 分與 20 分的認真學習者在片假名期間反覆觸發 `ReviewBacklog`。K11–K15 的手寫題 `minimal_pair`、`kana_word` 放在新內容切片的假名題之後（`rust-core.md` §9.4），不佔演練額度。複習分鐘換算張數時依題型加權：自動判定卡每張 8 秒，`use` 卡每張 25 秒。

### 11.3 調整規則

1. **複習優先**：到期量超過當日複習容量 2 倍時，當天新內容為 0，但最多連續 2 天；第 3 天起給最小新內容切片（假名或單字 3 筆，拗音 1 行）。超過 5 倍時不論第幾天都不給新內容。積壓只看到期量，回鍋日也一樣（檢定照常）。不給新內容的積壓學習日，當天分鐘全部給複習，回鍋日的複習上限再減半（`rust-core.md` §7.2，RULINGS O11、O12）。回鍋要有卡可碰，什麼卡都沒有時不算回鍋；回鍋落在休息日時，下個學習日從第 1 天起算。休息日不算「連續第幾天」，複習上限維持階段配比，不併入整個方案分鐘。
2. **不累積債務**：沒用的日子不補做，任務量以當日分鐘數為上限。T1 的預估含收尾新卡：複習張數先扣掉收尾新卡的時間（每張 8 秒），所以預估不超過方案分鐘。收尾新卡一天至多用掉複習分鐘的一半，超過的留到之後幾天（例如長期無聲後打開聲音，累積的聽力卡），複習張數因此不會被擠到 1 張（`rust-core.md` §6.4、§7.2）。連續 3 個學習日以上未使用，回來第一天新內容為 0，當天 `review_cap` 減半，避免一次面對全部積壓。
3. **同課切分**：一課的新字依 `new_words_per_day` 與 `lesson_order` 切成多天，文法點均分到這些天（先多後少）。最後加 1 天整合（10 分方案 2 天：第 1 天盲聽與逐句，第 2 天跟讀與角色扮演），完成主對話與演練；整合日用新內容＋演練＋聽力的額度。例句與聽力只取所有 `vo.*`、`gr.*` 都已 `item_intro` 的句子（新內容學習頁內也可用當日切片的項目，R18）。實戰與常體版對話依 §7 輪替。
4. **假名階段**：依 `kana_chars_per_day` 切片（§3.1）。
5. **使用者可隨時改時間**，只影響之後的排程，不重置進度。
6. **再學一批**：今日任務完成後可手動多取下一個切片，不改變隔天的快照。
7. （原「專區與主線平行」，已移除，見 RULINGS O13。項號保留。）

### 11.4 預估時程（粗估，上線後以實際資料調整）

估算式：**主線天數＝假名天數＋單字切片天數＋整合天數**。假名依 §3.1 切片（第一批 3 字、拗音行計 1 額度、無新字的課各 1 天）。單字切片為各課 `ceil(字數 ÷ new_words_per_day)` 的總和（S1 每課 25、S2 每課 28、S3 每課 33），整合為 48 課乘以每課整合天數。

| 方案 | 平假名（到 L01 前） | 片假名（KK） | 單字切片 | 整合 | 主線合計（天） | 約略 | 主線總時數 |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 10 分 | 33 | 38 | 484 | 96 | 651 | 22 個月 | 109 小時 |
| 20 分 | 23 | 23 | 292 | 48 | 386 | 13 個月 | 129 小時 |
| 30 分 | 17 | 17 | 210 | 48 | 292 | 10 個月 | 146 小時 |
| 45 分 | 15 | 13 | 144 | 48 | 220 | 7 個月 | 165 小時 |

各時點（第幾天，每天都學）：

| 方案 | 進入 L01 | L07 完成 | L14 完成 | L21 完成 | L30 完成 | L48 完成 |
|---:|---:|---:|---:|---:|---:|---:|
| 10 分 | 34 | 137 | 225 | 309 | 417 | 651 |
| 20 分 | 24 | 80 | 130 | 179 | 242 | 386 |
| 30 分 | 18 | 64 | 104 | 139 | 184 | 292 |
| 45 分 | 16 | 51 | 84 | 112 | 148 | 220 |

`plan_preview` 回傳主線完成日，`forecast` 只算已發布內容。上兩表是估算式的結果；已發布內容的實測如下。

**`plan_preview` 實測（第幾天）**。計算方式：真實內容、`start_level = zero`、`weekdays` 全選（每天都學）、沒有目標日期，從 2026-03-02 起算（`rust/tests/common/mod.rs` 的 `start_time()`），天數＝`main_forecast_end` 減起算日再加 1，即起算日算第 1 天。`p0` 的主線最後一課是 L30，所以「主線完成」就是 L30 完成。

| 方案 | `p0` 主線完成（L30） | `p0a` 主線完成（到 KK08） |
|---:|---:|---:|
| 10 分 | 413 | 145 |
| 20 分 | 251 | 91 |
| 30 分 | 180 | 66 |
| 45 分 | 144 | 53 |

- `p0` 由 `rust/tests/real_content_p0.rs` 的 `plan_preview_forecasts_main_end_for_every_preset` 釘成基準（2026-11-10 實測，2026-11-15 移除專區後數字不變；測試內以 `ContentStage::P0` 載入），`p0a` 由 `rust/tests/curriculum_days_real_content.rs` 釘成基準。內容或排程變動時這兩個測試會失敗，要同時更新本表。
- 與上表估算的差（實測減估算，10／20／30／45 分）：L30 完成 −4／+9／−4／−4 天。
- 學習迴路模擬（`rust/tests/p0_learning_loop.rs`，同樣條件，每天做完全部任務且全部答對）的實際完成日：主線 420／251／180／144（10／20／30／45 分，2026-11-15 移除專區後實測，RULINGS O13）。`forecast` 不模擬受限狀態（`rust-core.md` §7.5），主線晚的天數等於受限天數（7／0／0／0 天）。建立計畫時的預估誤差都 ≤ 1.7%（RULINGS O13）。
- 走 `p0` L01–L30 的切片（`rust/tests/real_content_p0_slices.rs`，同一天反覆完成與「再學一批」）共 342／205／146／116 片，即單字切片 282／175／116／86 加整合日 60／30／30／30。主線實測天數減去這些片數為 71／46／34／28 天，與第一張表平假名、片假名兩欄的合計相同。

分鐘預算依據的假設：新字每筆約 35 秒，自動判定卡每張約 8 秒、`use` 卡每張約 25 秒，穩定期每日複習量約為每日新字的 6–10 倍。

## 12. ID 規則與 JSON 規格

### 12.1 ID 命名

格式：`^[a-z]{2}\.[a-z0-9_]+(\.[a-z0-9_]+)*$`。全部 ASCII 小寫。

| 前綴 | 類別 | 形式 | 範例 |
|---|---|---|---|
| ka | 假名、規則、易混字組、語音示範組 | `ka.hira.<slug>`、`ka.kata.<slug>`、`ka.rule.<slug>`、`ka.cf.<slug>`、`ka.sg.<slug>` | ka.hira.nu |
| vo | 單字 | `vo.<romaji>[_<英文消歧>]` | vo.taberu、vo.hashi_bridge |
| gr | 文法 | `gr.<slug>` | gr.wo_obj |
| se | 句子 | `se.<誕生處>.<流水號>` | se.l05.001、se.x_onsen.01 |
| dr | 演練 | `dr.<課>.<題型代碼>.<流水號>` | dr.l05.par.001 |
| di | 對話 | `di.<slug>`、常體版 `di.<slug>.casual` | di.self_intro、di.self_intro.casual |
| no | 筆記 | `no.ff.*`、`no.sj.*`、`no.rd.*`、`no.tr.*`、`no.term.*` | no.ff.tegami |
| le | 課 | `le.k01`、`le.kk01`、`le.l01` | le.l05 |
| st | 階段 | `st.<slug>` | st.s1 |
| ms | 里程碑 | `ms.<slug>` | ms.n5 |
| pl | 計畫預設 | `pl.min<分鐘>` | pl.min20 |

假名 slug 用羅馬字，但為避免碰撞（R01）：ぢ 用 `di`、づ 用 `du`（ka.hira.di、ka.kata.du），KK08 的擴充拼法加前綴 `x_`（ティ＝ka.kata.x_ti、ディ＝ka.kata.x_di、ウォ＝ka.kata.x_wo）。符號用 `ka.hira.sokuon`、`ka.kata.sokuon`、`ka.kata.chouon`、`ka.{hira,kata}.small_ya`／`small_yu`／`small_yo`。

穩定性規則（進度表以 ID 為鍵，也是日後同步的鍵）：

1. **ID 一經發布永不修改、永不重複使用**。ID 裡的語意片段（如誕生課）只反映建立當時，內容搬到別課也不改 ID。
2. 要淘汰就設 `"retired": true`，需要移轉進度時加 `"replaced_by": "<id>"`。淘汰項目不出現在新學習中，但保留可解析。
3. 順序完全由 `course.json` 的陣列決定，ID 不含順序意義。
4. FSRS 卡片 ID 為 `<content_id>:<facet>`，facet 限 `read`、`listen`（假名）、`recog`、`listen`、`produce`（單字）、`use`（文法）。

例外：2026-11-15 移除的日劇與日文歌專區、短劇、看劇聽歌任務與預告語塊（原 `dz`、`so`、`mi` 前綴，以及 `vo.pv_*`、`di.scene_*`、`se.dz_*`、`se.so_*`）當時尚未對外發布，直接刪除、不留 `retired`（RULINGS O13）。這些前綴與 ID 不再使用。

### 12.2 句子表示法 `t`（全部內容共用）

```text
t      := word (" " word)*
word   := 標點 | morph ("+" morph)*
morph  := surface "|" kana "|" ref   （含漢字或數字時，kana 必填）
        | surface "|" ref            （純假名時，kana 省略）
ref    := vo.* | gr.* | @name | @new:<中文釋義>
```

- 空白分「詞」，`+` 分同一詞內的語素。顯示文字＝所有 surface 串接；分詞假名＝各詞 kana 以空白連接；羅馬字由 Rust 從分詞假名推導。波浪號統一用 U+301C `〜`。
- **語素切法**：動詞語幹與語尾分開。五段 `飲み|のみ|vo.nomu+ます|gr.masu`；一段 `食べ|たべ|vo.taberu+ます|gr.masu`；て形 `飲ん|のん|vo.nomu+で|gr.te_form`；い形容詞 `高|たか|vo.takai+くない|gr.i_adj`。
- **獨立成詞**：助詞、です、ください、いる／ある（〜ている的補助動詞）、する。
- **`vs` 動詞**：單字的 `surface` 為 勉強、`kana` 為 べんきょう，句中寫成 `勉強|べんきょう|vo.benkyou し|vo.suru+ます|gr.masu`，合併 surface 必須等於單字（R07），活用全由獨立的 `vo.suru` 承擔。`conjugate` 題的 `lemmas` 可含 `vs` 動詞，答案為 surface＋する 的活用（勉強して）。
- **助詞必須獨立成詞**，羅馬字才能把 は／へ／を 讀成 wa／e／o。「では」寫成兩個詞 `で|gr.x は|gr.y`。
- **固定語內部的 は**：こんにちは 寫成 `こんにち|vo.konnichiwa は|vo.konnichiwa`，單字的 `kana` 為 `こんにち は`。連續相同 ref 的語素合併後比對單字（R07）。
- **語塊**：尚未教語法但必須先用的短句，登錄成 `pos: phrase` 的單字（`いいですね|vo.ii_desu_ne`）。這是提前使用未教文法的唯一正當方法。
- `@name`：人名地名，每句最多 2 個；含 `@name` 的 `t` 一律 `tts: kana`。`@new:釋義`：標註生字，規則見 R05。
- 數字用阿拉伯數字且必填讀音；數字＋量詞視為一個語素，`3本|さんぼん|gr.counters`。

**`tts` 解析順序**：`t` 自身的 `tts`（`se.*`、`turns[]`、`rows[]`）→所屬題目的 `tts`→`auto`。

**混合文字標記 `{ja:…}`**：所有 `*_zh` 欄位與 `pattern`、`formation[].from`／`to`、`term`、`wrong`、`right`、`no.rd.*` 的 `examples[].ja` 內的日文（含純假名與語尾 〜），一律寫成 `{ja:日文}`；含漢字時可加讀音 `{ja:飯を食べる|めしをたべる}` 供振假名。讀音對齊底字必須恰一解（rust-core §4.6）：整句標記常有多解（`私は音楽が好きです` 的 音楽 可對 おん、好 可對 くがす），執行期退回整段 ruby、假名也被讀音蓋住，所以要拆成相鄰的逐詞標記 `{ja:私は|わたしは}{ja:音楽が|おんがくが}{ja:好きです|すきです}`，振假名只落在漢字上（R19 多解報警告）。標記不巢狀，`日文` 內不得含 `|`、`}`。純日文欄位（`surface`、`kana`、`t`、`word`、`a`、`b` 等）不加標記。`zh`、`example_words[].zh`、`literals[].zh`、`examples[].zh` 不走 MixedText，不得含假名，也不開放標記。

### 12.3 檔案結構

每個檔案為 `{ "schema": 1, "items": [...] }`，單檔不超過 800 行，超過就分檔。

```text
rust/content/
  course.json                 stages、課程順序、課的中繼資料
  kana/{hiragana,katakana,rules,confusables,sound_groups}.json
  vocab/<topic>.json
  grammar/{s1,s2,s3}.json
  sentences/<lesson>.json
  drills/<lesson>.json
  dialogues/{lessons,extras,casual}.json
  notes/{false_friends,shinjitai,readings,transfer,terms}.json
  plan/{presets,milestones}.json
  lint/{tts_risky.txt,zh_tw_denylist.txt,zh_simplified_chars.txt,r10_allow.txt}
```

`CONTENT_STAGE` 由 `course.json` 每課的 `content_stage` 決定範圍：只有 `content_stage` 不高於當前階段的課會進入載入結果，其下項目也一併略過。

### 12.4 課程、假名、單字、文法、句子、筆記

```json
{
  "stages": [{"id": "st.s0", "title_zh": "假名與發音"}, {"id": "st.s1", "title_zh": "敬體基礎"}],
  "order": ["le.k01", "le.k02", "le.k19", "le.l01", "le.kk01", "le.l02", "le.kk02"],
  "lessons": [
    {"id": "le.k01", "stage": "st.s0", "content_stage": "p0a", "title_zh": "{ja:あ}行", "can_do_zh": "能讀出 {ja:あいうえお}", "dialogue": null},
    {"id": "le.l05", "stage": "st.s1", "content_stage": "p0a", "title_zh": "每天做的事", "can_do_zh": "能說出每天的作息", "dialogue": "di.daily_routine"}
  ]
}
```

`content_stage`：`p0a`（K01–K19、KK01–KK08、L01–L07）、`p0`（L08–L30）、`full`（L31–L48）。課的新單字與新文法**不寫在課裡**，由各項目的 `lesson` 反查，避免兩處不同步。檢定位置只由 `milestone.lesson` 決定。

```json
{
  "kana": {"id": "ka.hira.nu", "lesson": "le.k05", "script": "hira", "kind": "basic", "char": "ぬ", "origin_kanji": "奴", "hint_zh": "和「{ja:め}」的差別在尾巴打結", "confusable": ["ka.cf.nu_me"], "example_words": [{"surface": "いぬ", "zh": "狗"}]},
  "kana_n": {"id": "ka.hira.n", "lesson": "le.k08", "script": "hira", "kind": "basic", "char": "ん", "origin_kanji": "无", "hint_zh": "自成一拍", "confusable": [], "example_words": [{"surface": "ほん", "zh": "書"}], "tts_text": "ん"},
  "kana_yoon": {"id": "ka.hira.kya", "lesson": "le.k14", "script": "hira", "kind": "yoon", "row": "kya", "char": "きゃ", "origin_kanji": null, "hint_zh": "念成一拍", "confusable": [], "example_words": [{"surface": "おきゃく", "zh": "客人"}]},
  "kana_mark": {"id": "ka.hira.sokuon", "lesson": "le.k16", "script": "hira", "kind": "mark", "char": "っ", "rule": "ka.rule.sokuon", "origin_kanji": null, "hint_zh": "不發音，停一拍", "confusable": [], "example_words": [{"surface": "きって", "zh": "郵票"}], "listen_disabled": true},
  "confusable_shape": {"id": "ka.cf.nu_me", "lesson": "le.k10", "kind": "shape", "members": ["ka.hira.nu", "ka.hira.me"], "diff_zh": "{ja:ぬ} 收尾有圈，{ja:め} 沒有"},
  "confusable_kanji": {"id": "ka.cf.ka_chikara", "lesson": "le.kk01", "kind": "kana_kanji", "members": ["ka.kata.ka"], "literals": [{"text": "力", "zh": "漢字「力」"}], "diff_zh": "{ja:カ} 是片假名，比漢字「力」小一點、線條更俐落"},
  "confusable_listen": {"id": "ka.cf.obasan_obaasan", "lesson": "le.k17", "kind": "listen", "members": [], "literals": [{"text": "おばさん", "zh": "阿姨"}, {"text": "おばあさん", "zh": "奶奶"}], "diff_zh": "長音多一拍，意思完全不同"},
  "rule_card": {"id": "ka.rule.sokuon", "lesson": "le.k16", "title_zh": "促音 {ja:っ}：停一拍", "body_zh": "{ja:っ} 不發音，佔一拍的時間。", "sound_groups": ["ka.sg.sokuon_basic"], "drills": ["dr.k16.mpr.001"], "examples": [{"text": "きて", "zh": "來（動詞的變化形）", "beats": ["き", "て"]}, {"text": "きって", "zh": "郵票", "beats": ["き", "っ", "て"]}]},
  "sound_group": {"id": "ka.sg.voicing_k", "lesson": "le.k11", "kind": "voicing", "title_zh": "清音與濁音：{ja:か}／{ja:が}", "body_zh": "清濁不是送氣與否。", "test_drills": ["dr.k11.mpr.001"], "pairs": [{"a": "か", "a_zh": "清音", "a_tts_text": "か", "b": "が", "b_zh": "濁音", "b_tts_text": "が"}, {"a": "かき", "a_zh": "柿子", "b": "かぎ", "b_zh": "鑰匙"}]},
  "sound_group_accent": {"id": "ka.sg.accent_ame", "lesson": "le.k19", "kind": "accent", "title_zh": "{ja:雨|あめ}／{ja:飴|あめ}", "body_zh": "日語的音調是高低，不是四聲。", "test_drills": [], "pairs": [{"a": "雨", "a_kana": "あめ", "a_zh": "雨", "b": "飴", "b_kana": "あめ", "b_zh": "糖果"}]},
  "vocab": {"id": "vo.taberu", "lesson": "le.l05", "lesson_order": 3, "surface": "食べる", "kana": "たべる", "zh": ["吃"], "pos": "v1", "trans": "tr", "accent": null, "jlpt": "n5", "topics": ["verb", "food"], "examples": ["se.l05.001", "se.l06.014"], "hook_zh": null, "trap_zh": null, "notes": []},
  "vocab_vs": {"id": "vo.benkyou", "lesson": "le.l05", "lesson_order": 9, "surface": "勉強", "kana": "べんきょう", "zh": ["念書", "學習"], "pos": "vs", "trans": "tr", "accent": null, "jlpt": "n5", "topics": ["school"], "same_form_zh": true, "examples": ["se.l05.017", "se.l05.021"], "notes": ["no.ff.benkyou"]},
  "vocab_accent": {"id": "vo.ame_rain", "lesson": "le.l09", "lesson_order": 12, "surface": "雨", "kana": "あめ", "zh": ["雨"], "pos": "n", "accent": 1, "tts": "auto", "jlpt": "n5", "topics": ["nature"], "same_form_zh": true, "examples": ["se.l09.008", "se.l09.015"]},
  "vocab_phrase": {"id": "vo.konnichiwa", "lesson": "le.l01", "lesson_order": 2, "surface": "こんにちは", "kana": "こんにち は", "zh": ["你好（白天）"], "pos": "phrase", "accent": null, "jlpt": "n5", "topics": ["greet"], "examples": ["se.l01.003", "se.l01.009"]},
  "vocab_v1_s": {"id": "vo.kureru", "lesson": "le.l28", "lesson_order": 2, "surface": "くれる", "kana": "くれる", "zh": ["（別人）給（我）"], "pos": "v1_s", "trans": "tr", "accent": null, "jlpt": "n4", "topics": ["verb"], "examples": ["se.l28.011", "se.l28.012"], "conj_omit": ["potential", "passive", "causative", "volitional"]},
  "grammar": {"id": "gr.wo_obj", "lesson": "le.l05", "lesson_order": 2, "jlpt": "n5", "title_zh": "{ja:を}：動作的對象", "pattern": "N {ja:を} V", "meaning_zh": "標示動作直接作用的對象", "explain_zh": "放在受詞後面，動詞放句尾。", "compare_zh": "中文是「吃飯」，日文語序是「{ja:ご飯を食べる|ごはんをたべる}」。", "trap_zh": "{ja:を} 在這裡讀 o。", "formation": [{"from": "N", "to": "N {ja:を}"}], "register": "neutral", "requires": ["gr.masu"], "examples": ["se.l05.001"], "contrast": ["gr.ga_subject"], "terms": []},
  "sentence": {"id": "se.l05.001", "lesson": "le.l05", "t": "私|わたし|vo.watashi は|gr.wa_topic 毎朝|まいあさ|vo.maiasa ご飯|ごはん|vo.gohan を|gr.wo_obj 食べ|たべ|vo.taberu+ます|gr.masu 。", "zh": "我每天早上吃飯。", "style": "polite", "tts": "auto"},
  "note_false_friend": {"id": "no.ff.tegami", "surface": "手紙", "vocab": "vo.tegami", "ja_zh": "信（書信）", "misread_zh": "看起來像「衛生紙」", "lesson": "le.l12"},
  "note_shinjitai": {"id": "no.sj.eki", "ja": "駅", "zh_tw": "驛", "kind": "simplified_differently", "vocab": ["vo.eki"]},
  "note_reading": {"id": "no.rd.ru_k", "lesson": "le.l08", "title_zh": "入聲 -k 常對應 {ja:く}", "body_zh": "台語尾音 -k 的字，日語音讀常收 {ja:く}。", "examples": [{"hanzi": "學", "tai": "hak8", "ja": "{ja:学|がく}"}, {"hanzi": "國", "tai": "kok4", "ja": "{ja:国|こく}"}], "vocab": ["vo.gakkou"], "caveat_zh": "這是記憶鉤，不是嚴格規則。"},
  "note_transfer": {"id": "no.tr.anata", "lesson": "le.l01", "title_zh": "別對長輩說 {ja:あなた}", "zh_pattern": "你", "wrong": "{ja:あなたは先生ですか|あなたはせんせいですか}", "right": "{ja:田中さんは先生ですか|たなかさんはせんせいですか}", "explain_zh": "知道對方姓氏就用「姓氏＋{ja:さん}」，主語明確時直接省略。", "grammar": ["gr.san_title"], "vocab": []},
  "note_term": {"id": "no.term.masu_stem", "lesson": "le.l07", "term": "{ja:ます}幹", "aka_zh": "連用形", "body_zh": "把 {ja:ます} 形的 {ja:ます} 拿掉剩下的部分：{ja:食べます|たべます}→{ja:食べ|たべ}，{ja:飲みます|のみます}→{ja:飲み|のみ}。", "grammar": ["gr.ni_purpose", "gr.tai"]}
}
```

`style`：`polite`、`plain`、`mixed`、`neutral`。`tts`：`auto`、`kana`，省略時句子為 `auto`、單字為 `kana`。

單字欄位（其餘見 §4.3）：

- `pos` 為 `v1_s` 的是特殊一段動詞（JMdict `v1-s`，目前只有 くれる）。活用與 `v1` 相同，只有命令形是語幹：くれる→くれ，不是 くれろ。同音的 暮れる 是一般 `v1`，命令形仍是 暮れろ。B 層 J05 把 `v1_s` 對到 JMdict 的 `v1-s`，`v1` 只對到 `v1`。干擾項的「同 `pos`」把 `v1_s` 與 `v1` 視為同一組。
- `conj_omit` 列出引擎算得出、但這個詞實際不用的活用形，值與 `conjugate` 題的 `form` 相同（`masu`、`te`、`ta`、`nai`、`potential`、`volitional`、`ba`、`imperative`、`passive`、`causative`），省略時為空陣列。單字詳情的「活用」表不顯示這些形；`conjugate` 題的 `lemmas` 若在 `conj_omit` 列了該題的 `form`，RC7 報錯。用途有三種：一是本身已有「能」的意思或屬存在動詞，可能形會變成另一個詞，例如 分かる 的 分かれる（分開）、ある 的 あれる（荒れる）、開く(あく) 的 開ける（他動詞 vo.akeru）；二是無意志動詞（降る、咲く、治る 等）不用可能形，其中有他動詞可用的自動詞（閉まる→閉める、始まる→始める、見つかる→見つける、増える→増やす、壊れる→壊す、治る→治す）連使役形也略過，免得學習者拿 閉まらせる 代替他動詞，被動形不自然的也一併略過（治られる 可作尊敬語，保留）；三是 `v1_s` 的 くれる：可能、被動、使役、意向（くれられる、くれさせる、くれよう）在現代標準語不用，全部列入，命令形 くれ 是常用形，不列。無意志動詞的意向形（〜ようとする、〜うが）與祈願用的命令形（雨よ降れ、想いよ届け）是正常用法，不列入。只對確定不用的形標註，拿不準的不標。

假名欄位：`kind` 為 `basic`、`dakuten`、`yoon`、`extended`、`mark`；`row` 只有 `yoon` 必填；`rule` 只有 `mark` 使用，指向相關規則卡；`tts_text` 省略時送 `char`；`listen_disabled` 省略時為 `false`。`ka.cf.*` 的 `kind` 為 `shape`、`cross_script`、`kana_kanji`、`listen`，`literals` 可省略。`ka.sg.*` 的 `pairs[]` 與 `minimal_pair` 同形：`a`、`b`、`a_zh`、`b_zh`，以及可省略的 `a_kana`、`b_kana`（`a`／`b` 含漢字時必填，供振假名）、`a_tts_text`、`b_tts_text`、`listen_disabled`。

`no.term.*` 共 12 則：`masu_stem`、`te_form`、`ta_form`、`nai_form`、`dict_form`、`renyou`、`plain_polite`、`godan`、`ichidan`、`jita`、`na_adj`、`i_adj`，全部列在 N1 筆記清單，從文法頁的 `terms` 點入。

### 12.5 演練題

```json
{
  "items": [
    {"id": "dr.k13.mpr.001", "type": "minimal_pair", "lesson": "le.k13", "targets": ["ka.hira.ki", "ka.hira.gi"], "a": "かき", "a_zh": "柿子", "b": "かぎ", "b_zh": "鑰匙"},
    {"id": "dr.k05.kwd.001", "type": "kana_word", "lesson": "le.k05", "targets": ["ka.hira.i", "ka.hira.nu"], "word": "いぬ", "zh": "狗", "mode": "choice", "choices_zh": ["狗", "貓", "鳥", "魚"], "answer_index": 0},
    {"id": "dr.k11.kwd.002", "type": "kana_word", "lesson": "le.k11", "targets": ["ka.hira.ka", "ka.hira.gi"], "word": "かぎ", "zh": "鑰匙", "mode": "typing"},
    {"id": "dr.l05.sub.001", "type": "substitution", "lesson": "le.l05", "targets": ["gr.wo_obj"], "frame": "私|わたし|vo.watashi は|gr.wa_topic {a} を|gr.wo_obj {b} 。", "rows": [{"a": "ご飯|ごはん|vo.gohan", "b": "食べ|たべ|vo.taberu+ます|gr.masu", "zh": "我吃飯。", "tts": "auto"}, {"a": "お茶|おちゃ|vo.ocha", "b": "飲み|のみ|vo.nomu+ます|gr.masu", "zh": "我喝茶。"}, {"a": "魚|さかな|vo.sakana", "b": "食べ|たべ|vo.taberu+ます|gr.masu", "zh": "我吃魚。"}]},
    {"id": "dr.l05.ord.001", "type": "reorder", "lesson": "le.l05", "targets": ["gr.wo_obj"], "sentence": "se.l05.001", "accept_orders": [[0, 1, 2, 3], [1, 0, 2, 3]], "audio_first": false},
    {"id": "dr.l05.par.001", "type": "particle_fill", "lesson": "le.l05", "targets": ["gr.wo_obj"], "sentence": "se.l05.001", "blanks": [{"word_index": 4, "choices": ["を|gr.wo_obj", "に|gr.ni_time", "で|gr.de_place", "は|gr.wa_topic"]}], "explain_zh": "「吃」的對象用 {ja:を}。"},
    {"id": "dr.l05.z2j.001", "type": "zh_to_ja_choice", "lesson": "le.l05", "targets": ["gr.wo_obj"], "prompt_zh": "我每天早上吃飯。", "answer": "se.l05.001", "distractors": [{"t": "ご飯|ごはん|vo.gohan は|gr.wa_topic 私|わたし|vo.watashi を|gr.wo_obj 食べ|たべ|vo.taberu+ます|gr.masu 。", "why_zh": "主詞和受詞顛倒了。"}]},
    {"id": "dr.l05.lsn.001", "type": "listen_meaning", "lesson": "le.l05", "targets": ["gr.masu"], "sentence": "se.l05.001", "choices_zh": ["我每天早上吃飯。", "我每天晚上吃飯。", "我今天不吃飯。"], "answer_index": 0},
    {"id": "dr.l07.sit.001", "type": "situation_response", "lesson": "le.l07", "targets": ["gr.masen_ka"], "situation_zh": "朋友邀你週六看電影，你想去。", "style": "polite", "prompt": "土曜日|どようび|vo.doyoubi に|gr.ni_time 映画|えいが|vo.eiga を|gr.wo_obj 見|み|vo.miru+ませんか|gr.masen_ka 。", "answer": "いいですね|vo.ii_desu_ne 。", "distractors": [{"t": "はい|vo.hai 、 見|み|vo.miru+ませんでした|gr.masu_past 。", "why_zh": "這是在答過去的事。"}]},
    {"id": "dr.l15.cnj.001", "type": "conjugate", "lesson": "le.l15", "targets": ["gr.te_form"], "form": "te", "lemmas": ["vo.taberu", "vo.nomu"]},
    {"id": "dr.l21.reg.001", "type": "register_convert", "lesson": "le.l21", "targets": ["gr.plain_style"], "from": "se.l05.001", "to": "se.l21.004"},
    {"id": "dr.l05.shd.001", "type": "shadowing", "lesson": "le.l05", "targets": ["gr.masu"], "sentence": "se.l05.001"},
    {"id": "dr.l12.ffr.001", "type": "false_friend", "lesson": "le.l12", "targets": ["vo.tegami"], "note": "no.ff.tegami", "prompt_zh": "「{ja:手紙|てがみ}」是什麼意思？", "choices_zh": ["信", "衛生紙", "手帕"], "answer_index": 0}
  ]
}
```

`kana_word` 的 `mode`：`choice`（`choices_zh` 四選一，`answer_index`）或 `typing`（打字比對 `word` 的讀音，只用於 K10 之後）；`word` 必須全由已教假名組成（R06）。`particle_fill` 的 `word_index` 從 0 起算，標點也算一個詞；`blanks` 長度固定為 1。`accept_orders` 的索引指向自動切出的詞塊（`私は／毎朝／ご飯を／食べます`），標點不算。`substitution` 的 `rows` 至少 3 列。

### 12.6 對話、計畫

```json
{
  "dialogue": {"id": "di.self_intro", "kind": "lesson", "lesson": "le.l01", "style": "polite", "scene_zh": "語言交換活動，第一次見面。", "goal_zh": "說出名字與來自哪裡", "roles": [{"id": "a", "name_zh": "林", "voice": "a"}, {"id": "b", "name_zh": "田中", "voice": "b"}], "turns": [{"role": "a", "t": "はじめまして|vo.hajimemashite 。", "zh": "初次見面。"}, {"role": "a", "t": "林|りん|@name です|gr.desu 。", "zh": "我姓林。", "tts": "kana"}, {"role": "b", "t": "田中|たなか|@name です|gr.desu 。 よろしく|vo.yoroshiku_onegaishimasu お願いします|おねがいします|vo.yoroshiku_onegaishimasu 。", "zh": "我是田中，請多指教。", "tts": "kana"}], "focus": ["gr.desu"], "quiz": ["dr.l01.lsn.012", "dr.l01.lsn.013"]},
  "plan_preset": {"id": "pl.min20", "minutes": 20, "new_words_per_day": 5, "kana_chars_per_day": 5, "split": {"new": 4, "review": 9, "drill": 4, "listen": 3}},
  "milestone": {"id": "ms.casual", "lesson": "le.l21", "title_zh": "聽懂朋友說話的第一步", "pass_ratio": 0.8, "questions": 20}
}
```

四個計畫預設：`pl.min10`（3、3；split 2／6／1／1）、`pl.min20`（5、5；4／9／4／3）、`pl.min30`（8、8；6／14／6／4）、`pl.min45`（12、10；9／20／9／7），依序為 `new_words_per_day`、`kana_chars_per_day`；split 為 new／review／drill／listen。

### 12.7 羅馬字的邊界案例（給 Rust 推導模組的測試資料）

`こんにち は`→konnichi wa；`で は`→de wa；`まっちゃ`→matcha；`コーヒー`→koohii；`とうきょう`→toukyou；`せんせい`→sensei；`ほんい`→hon'i；`ほんや`→hon'ya；`ティ`→ti；`ファ`→fa；尾端促音省略（`あっ`→a，`えっ`→e）。單字 `kana` 無空白時走單詞模式（`は`→ha、`へ`→he），含空白時走句子模式。

## 13. 順序一致性的機械檢查

實作為 `cargo test` 的整合測試（`rust/crates/jp_content/tests/content_lint.rs`，單獨執行要 `cargo test -p jp_content --test content_lint`），任一規則失敗即測試失敗。錯誤訊息需列出項目 ID、違規 token、該 token 首次教學的課，讓撰寫者能直接修正。檢查範圍與門檻依環境變數 `CONTENT_STAGE`（`p0a`、`p0`、`full`，預設 `p0`）決定，只檢查 `content_stage` 不高於當前階段的內容（§12.3）。

**核心做法**：`course.json` 定出每課的位置 `pos(lesson)`；每個可教項目（`vo.*`、`gr.*`、`ka.*`）有唯一的 `lesson`；所有句子都用 `t` 寫，因此句子的每個語素都帶著 ref。檢查就是比較 `pos(ref 所屬課) ≤ pos(句子所屬課)`。

| 規則 | 檢查內容 |
|---|---|
| R01 | ID 符合正規式、全域唯一（含 `ka.*` 的 `di`、`du`、`x_` slug）；`vo.*` 的 slug 應以 `kana` 推導的羅馬字開頭（警告級） |
| R02 | 所有 `t`（句子、對話、`rows`、題目、干擾項、`choices`、句框展開後）都可解析；每個語素都有 ref |
| R03 | ref、`examples`、`requires`、`contrast`、`targets`、`quiz`、`terms`、`sound_groups`、`drills`、`test_drills` 等 ID 都存在且未淘汰 |
| R04 | **順序**：`pos(ref) ≤ pos(所屬課)`；`requires` 必須早於或同課，同課時 `lesson_order` 較小，且無循環 |
| R05 | `@new` 每句最多 1 個、每課不超過句數 10%；S0 與所有演練題禁用 |
| R06 | **假名閘門**：句中每個假名字元都已在該位置前教過（含 KK 課穿插，拗音與擴充拼法以最長比對算一個單位，`kind: mark` 的符號也要先教過）。`kana_word.word`、`minimal_pair` 的 `a`／`b`、`ka.sg.*` 的配對同樣檢查 |
| R07 | **語素一致**：non-inflecting（含 `vs`）的合併 surface 與 kana 等於單字；inflecting 的語幹必須是引擎生成的合法變化語幹（`知ら` 屬於 `知る`） |
| R08 | 純假名語素不得填 kana；含漢字或數字者必填；振假名對齊必須唯一 |
| R09 | **覆蓋**：每個單字至少出現在 2 句、`examples[0]` 同課；每個文法至少 6 句、4 題、3 種題型 |
| R10 | **間隔重現**：新單字在教學後 3 個主線課內至少再出現一次（警告級）。時間窗只算主線課（非 S0 的 L 課）：KK 課穿插在 L01–L08 之間，但假名課不介紹單字，不佔「3 課內」，在假名課的出現也不算重現；教在最後一個主線課（例如 `p0a` 的 L07）的字沒有時間窗，不報。刻意設計的例外登錄在 `lint/r10_allow.txt`（每行「`vo.*` ID 理由」，理由必填，缺理由為錯誤；已重現仍登錄者報警告，提醒移除）。現行登錄：L03 的一〜万 13 張數字字卡（L04 起時刻、價格寫阿拉伯數字，整塊屬 `gr.jikan`／`gr.numbers`，R07 不允許標成 `vo.*`）。取消某字的例外：刪掉 `r10_allow.txt` 該行。改回「依 `course.order` 計」：`jp_content/src/lint/spaced.rs` 的 `MainLine` 改用 `ctx.pos`。`p0`、`p0a` 的 R10 與 R19 由 `content_lint.rs` 的 `real_content_has_no_r10_or_r19_findings` 釘在 0 筆，要放寬時一併調整這個測試 |
| R11 | **負擔**：例句的當課新項目不超過 3 個（L01–L03 放寬為 5 個），對話逐句不超過 5 個 |
| R12 | 題目的選項與干擾項也適用 R04；`particle_fill` 的每個選項都要帶 ref，`blanks` 長度必為 1；句框的每一列都展開後檢查，`rows` 至少 3 列 |
| R13 | 已移除（RULINGS O13），編號保留 |
| R14 | 已移除（RULINGS O13），編號保留 |
| R15 | 中文欄位不得含簡體字（比對 `content/lint/zh_simplified_chars.txt`，不依賴 OpenCC）或 `zh_tw_denylist.txt` 內的中國用語（視頻、軟件、信息等） |
| R16 | 所有 `t` 依 §12.2 的 `tts` 解析順序取得有效值：`auto` 者不得命中 `tts_risky.txt`；含 `@name` 者必為 `kana` |
| R17 | 各類別筆數與 §14 表中當前 `CONTENT_STAGE` 欄比對，低於目標失敗 |
| R18 | 依 §11.3 切分模擬，每個 L 課的非整合切片日至少有一句可用例句（句中 `vo.*`、`gr.*` 都已在當日或更早切片介紹） |
| R19 | `{ja:…}` 語法正確；§12.2 列舉的中文與混合欄位內，假名必須包在標記內；`zh`、`example_words[].zh`、`literals[].zh`、`examples[].zh` 不走 MixedText，不得含假名，也不開放標記；未加讀音但含漢字者為警告；有讀音但與底字 0 解（例如讀音漏了 `？`，rust-core §4.6）為錯誤，多解（例如整句 `{ja:私は音楽が好きです|…}`，音楽 可對 おん）為警告，要拆成逐詞標記（§12.2；改回不檢查多解：刪掉 `jp_content/src/lint/text.rs` 的 `check_ja_span` 裡多解的分支）；「漢字緊鄰假名」且不在標記內為警告（輔助 lint） |
| R20 | `lesson_order` 在同一 `lesson` 內由 1 起連號（單字與文法分開計）；任何內容不得有 `seq` 鍵 |
| R21 | 已移除（RULINGS O13），編號保留 |
| R22 | 已移除（RULINGS O13），編號保留 |
| R23 | 已移除（RULINGS O13），編號保留 |
| R24 | 假名課完整性：`le.k10`、`le.k16`–`le.k19` 沒有非 `mark` 的新字；`yoon` 必有 `row`；`mark` 必為 `listen_disabled: true`（警告級：實機未驗證前的預設） |
| R25 | 全為漢字、且與 `zh` 任一項相同的單字未標 `same_form_zh` 為警告 |

**撰寫流程工具**：提供 `content_tool available <lesson>`，輸出到該課為止所有可用 ID 及其 surface。撰寫代理寫某課前先取得此清單，只從清單內選字，寫完跑 lint。

**撰寫順序的前提**：先定 `course.json` 與全部文法的 `lesson`，再把單字分配到各課，然後才寫句子。不要邊寫句子邊新增單字；句子真的需要新字時，必須把單字登錄到某一課再引用，或標 `@new`。

## 14. 內容量總表與分工

內容分三階段（`CONTENT_STAGE`）：

- `p0a`（垂直切片，第一個必須端到端跑通的版本）：S0 全部假名資料與規則卡（K01–K19、KK01–KK08，含易混字組與假名題）、L01–L07 主線內容、`ms.hira`、`ms.kata`、`ms.survive`、全部計畫預設。所有 App 功能與題型在此階段就要實作完成；筆記畫面用測試夾具（`rust/crates/jp_content/tests/fixtures/full/`）驗證。L01–L07 的 `notes` 在 `p0a` 為空陣列，`false_friend` 由夾具驗證。
- `p0`：L01–L30、筆記。
- `full`：L31–L48。

| 類別 | 路徑 | `p0a` | `p0` | `full` | 單筆要求 |
|---|---|---:|---:|---:|---|
| 假名字元 | kana/ | 229 | 229 | 229 | §3 |
| 假名符號 | kana/ | 9 | 9 | 9 | `kind: mark`，§3.1 |
| 假名規則卡 | kana/rules | 7 | 7 | 7 | §3.1 |
| 易混字組 | kana/confusables | 53 | 53 | 53 | §3.2 |
| 語音示範組 | kana/sound_groups | 16 | 16 | 16 | §3.4 |
| 課程 | course.json | 34 | 57 | 75 | 含 K 19、KK 8、L 7／30／48 |
| 單字 | vocab/ | 175 | 800 | 1,400 | §4.3；`p0a` 為 S1 前 7 課，`p0` 為 S1–S2 800，`full` 另加 S3 600 |
| 文法點 | grammar/ | 39 | 138 | 212 | §5.4 |
| 主線例句 | sentences/ | 266 | 1,140 | 1,824 | 每課約 38 句 |
| 手寫演練（課程） | drills/ | 210 | 900 | 1,440 | 每課 30 題 |
| 手寫演練（假名） | drills/ | 100 | 100 | 100 | `minimal_pair` 80、`kana_word` 20 |
| 主對話 | dialogues/lessons | 7 | 30 | 48 | 6–12 句 |
| 實戰對話 | dialogues/extras | 0 | 6 | 12 | 6–12 句 |
| 常體版對話 | dialogues/casual | 0 | 12 | 16 | 原對話不晚於 L30 者屬 `p0` |
| 同形異義筆記 | notes/false_friends | 0 | 60 | 60 | §2 |
| 字形對照 | notes/shinjitai | 0 | 120 | 120 | §2 |
| 讀音規律筆記 | notes/readings | 0 | 20 | 20 | §2 |
| 語言轉移筆記 | notes/transfer | 0 | 20 | 20 | §2 |
| 術語筆記 | notes/terms | 0 | 12 | 12 | §12.4 |
| 里程碑 | plan/milestones | 3 | 6 | 8 | §11.1 |
| 計畫預設 | plan/presets | 4 | 4 | 4 | §11.2 |

預設 `p0` 的實際筆數（2026-11-16，`content_tool --stage p0 stats`）全部達到 `p0` 欄。高於目標的有單字 812、主線例句 1,932、課程演練 1,082，其餘類別與目標相同。

**暫不實作（P1）**：本機每日提醒、備份匯出與匯入、錄音回放、手寫描紅與筆順、VOICEVOX、術語卡的首次彈窗。

**分工與相依順序**（`p0a` 範圍優先，端到端跑通後再量產）：

| 批次 | 工作 | 前置 |
|---|---|---|
| 1 | `course.json`、全部文法（S1、S2、S3 三份檔案） | 無 |
| 2 | 假名資料、規則卡、易混字組、語音示範組、假名手寫題 | 無（可與 1 平行） |
| 3 | 單字分配到課：S1、S2 一組，S3 一組 | 1 |
| 4 | 主線例句與演練，每 10 課一組（L01–10、11–20、21–30、31–40、41–48） | 1、3 |
| 5 | 主對話、實戰、常體版 | 4 |
| 6 | 已移除（RULINGS O13），編號保留 | |
| 7 | 已移除（RULINGS O13），編號保留 | |
| 8 | 筆記類（同形異義、字形、讀音、轉移、術語） | 3 |
| 9 | 全量 lint、人工抽查原創性與自然度 | 全部 |

每批交付都必須通過當下可適用的 lint 規則。
