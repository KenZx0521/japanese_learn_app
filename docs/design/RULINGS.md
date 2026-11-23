# 設計裁決紀錄（RULINGS.md）

本檔是四份設計文件（curriculum.md、rust-core.md、flutter-app.md、reuse-and-verification.md）衝突時的**最高依據**。
第一部分是專案負責人的裁決，優先於第二部分。第二部分是批判審查的原文：其中 `recommended_resolutions` 的每一條，除非被第一部分推翻，都視為已採納。
O13（2026-11-15）移除了日劇與日文歌專區及周邊功能。O13 之前的裁決與第二部分提到專區、短劇、看劇聽歌任務、預告語塊、`contraction_decode`、學習目標的條文保留原文，是當時的紀錄，現況以 O13 為準。

## 第一部分：負責人裁決（優先）

**O1 範圍分階段。** `CONTENT_STAGE` 三值：`p0a`、`p0`、`full`（G12 採納並具體化）。
- `p0a`（垂直切片，第一個必須端到端跑通的版本）：S0 全部假名資料與規則卡（K01–K19、KK01–KK08，含易混字組與假名題）、L01–L07 主線內容（單字、文法、例句、演練、對話）、預告語塊 L03 與 L07 批次、`ms.hira`、`ms.kata`、`ms.survive`、全部計畫預設。
- `p0`：L01–L30、預告語塊 L14 批次、解鎖點不晚於 L30 的日劇與歌曲專區、短劇、看劇／聽歌任務、筆記。
- `full`：L31–L48 與其餘專區。
- 所有 App 功能與題型在 `p0a` 階段就要實作完成；專區畫面在 p0a 階段用測試夾具（fixture）驗證，因為專區在 L21 後才解鎖。
- 附註（2026-11-15，O13）：預告語塊、日劇與歌曲專區、短劇、看劇／聽歌任務已移除，上面三個階段裡的這些項目與「專區畫面用夾具驗證」失效。現行範圍：`p0a` 是 S0 與 L01–L07，`p0` 是 L01–L30 與筆記，`full` 是 L31–L48。

**O2 延後到 P1（推翻批判建議）。** 下列項目不進 P0，文件中列入「暫不實作」：本機每日提醒（G06 前半；「再學一批」仍為 P0）、備份匯出與匯入（G11）、錄音回放（G07 後半、C36）、手寫描紅與筆順、VOICEVOX、術語卡「首次出現時彈窗」（G03 後半；改為把 `no.term.*` 術語筆記放進 N1 筆記清單，從文法頁可點入）。

**O3 實機驗證不是開發前置條件。** 本環境沒有 Android SDK、iOS 工具鏈、音效輸出。C20、G05 中「Android／iOS 全表試聽列為第一個里程碑」「實機驗證排在內容量產之前」改為：內容先用保守預設（下述），並由專案產出 `docs/TTS_DEVICE_CHECKLIST.md` 供專案擁有者實機檢查；檢查結果透過 `tts_text`、`listen_disabled` 欄位回寫，不需改程式。保守預設：`っ`、`ー`、`ゃゅょ` 等無法單獨成音者 `listen_disabled: true`；`ん` 的 `tts_text` 待實機驗證，先以本字送出並列入清單。

**O4 假名節奏。** B04 優先於 C23 的 `kana_days_per_lesson`：不使用「每課天數」，改用計畫預設欄位 `kana_chars_per_day`（10 分＝3、20 分＝5、30 分＝8、45 分＝10）。每個方案的第一批固定 3 字（B01）。拗音依規律整批教，一個拗音行計為 1 字額度。K10、K16–K19 這類無新字的課，為整課一個切片、算一天。

**O5 權威順序。** 內容欄位以 curriculum.md 為準；函式簽章與 DTO 以 rust-core.md §9 為準；UI 流程與 tokens 以 flutter-app.md 為準；驗證工具以 reuse-and-verification.md 為準。任何一方要新增跨文件欄位，名稱以本檔出現者為準。

**O6 不重新討論已實證事項。** spike 已證實的版本與 API 不再更動（Rust 1.99.1、FRB 2.13.0、rusqlite 0.41.1、rs-fsrs 1.2.1、Riverpod 3.5、go_router 18、material_ui）。

**O7 誠實範圍文案。** 首發文案只能宣稱實際發布的內容（C24）：p0a 版本只能說「假名與入門七課」，不得提及 N4、也不得承諾看懂日劇；專區於內容就緒後才露出入口。
- 附註（單字的參考級別）：V3 單字詳情上的 JLPT 參考級別標籤（`參考 N4`、`N4 以外`，`vocab_labels.dart` 的 `jlptLabelOf`，p0 起才顯示）是單字逐字的標示，不是這一版的範圍宣稱，不違反 O7。豁免只限這個標籤本身：同樣的字出現在句子裡（例如「涵蓋參考 N4 範圍」），或出現在 V3 以外的畫面，仍算範圍宣稱。整合測試的文案守門照此實作（`integration_test/support/p0_copy_rules.dart`）。
- 附註（2026-11-15，O13）：專區已移除，「專區於內容就緒後才露出入口」失效；不得提及 N4、不得承諾看懂日劇照舊。

**O8 不引入連網能力。** release 建置不得含 INTERNET 權限；相依樹不得有 HTTP/TLS client。`docs/` 或 CI 要有可執行的檢查方式。

**O9 朱色上限只管強調用途。** flutter-app §4「一個畫面不超過兩處朱色」只規範強調用途（印章、答錯、「再一次」、當前項標記）。K1 的熟練點、P1 的月曆印章這類資料標記不計入，避免兩條規格互相衝突。

**O10 台語讀音用台羅數字調。** `no.rd.*` 的 `examples[].tai` 一律寫教育部台灣閩南語羅馬字拼音（台羅）的數字調，例如 `hak8`、`kok4`、`sam1`、`tong1`，不寫調符。理由：打包的 Noto Sans TC 與 Klee One 原檔都沒有第 8 聲的 U+030D 與 U+0358，寫調符會缺字並違反決策 7（F03）。筆記畫面在台語讀音旁標示「台羅，數字為聲調」。讀音以教育部《臺灣閩南語常用詞辭典》的文讀音為準，不確定的字不收。

**O11 複習積壓與分鐘上限（學習迴路模擬 F1–F3）。** 修改 B10 的「第 3 天起給最小切片」，細節寫在 rust-core §7.2–§7.5 與 curriculum §11.2、§11.3。
- D1 積壓：`ReviewBacklog` 當天暫停專區（`zone_items = 0`，不列 `Zone`；看劇聽歌任務不建卡，照常）。到期數 > `5 × capacity` 時不論第幾天都不給新內容（`BACKLOG_PAUSE_FACTOR = 5`，原為 3，O12 重選）；介於 2 倍與 5 倍之間維持前 2 天 `None`、第 3 天起 `Minimal`。到期數過線的回鍋日同樣暫停（O12），`UnseenNewCards` 不暫停專區。
- D1 補充（實作時依量測加上）：`ReviewBacklog` 且 `new_content = None` 的日子只排複習，new、drill、listen 額度全部併入 review，`review_cap` 依合併後的分鐘重算。理由：只停新內容時，答錯 30% 的學習者每天只用掉約 6–15 分，積壓降不下來；在 S0 50／50、10 分 2／6／1／1 的候選下，L07 之後 1,000 天內沒有再完成任何 L 課，最長 34 個日曆天沒有主線切片，只把 new 額度併入複習時最長 20 天。全部併入後，暫停線 3 倍時最長 13 天（C4 ≤ 14 天），第 1,600 天學完 L30；5 倍的數字見下表。
- D2 分鐘上限：`review_cap` 先從 review 秒數扣掉快照當下的收尾新卡（`new_cards × 8` 秒）。積壓的兩條線改用扣除前的 `capacity`，因為用扣過的 `review_cap` 判定時，10／20／30 分的認真學習者積壓日由 29／3／0 天增為 83／11／1 天。
- D3 10 分方案：S0 配比由 70／30 改為 60／40（KK01–KK08 排在 L07 之後，片假名期間已有 L01–L07 的字卡要複習），10 分方案 S2 的 split 由 2／5／2／1 改為 2／6／1／1。`plan_preview` 的完成日不變（主線 413／251／180／144、專區 799／435／259／191 天），因為切片與專區額度都沒變。
- 量測依據：`rust/tests/p0_learning_loop.rs`（真實 `p0`、2026-03-02 起算，第 1 天＝起算日）。最終參數的實測如下，可用 `cargo test --release --test p0_learning_loop -- --ignored --exact report_every_learner --nocapture` 重現。

| 學習者 | 留到隔天最多 | 受限天數 | 主線完成 | 專區完成 | 預估誤差（主線／專區） | T1 最大 | 最長停滯 |
|---|---:|---:|---:|---:|---:|---:|---:|
| 10 分・每天全對 | 32 | 10 | 423 | 811 | +2.4%／+1.5% | 10 分 | 1 天 |
| 20 分・每天全對 | 58 | 2 | 253 | 437 | +0.8%／+0.5% | 20 分 | 1 天 |
| 30 分・每天全對 | 65 | 0 | 180 | 259 | 0%／0% | 30 分 | 0 天 |
| 45 分・每天全對 | 49 | 0 | 144 | 191 | 0%／0% | 45 分 | 0 天 |
| 20 分・缺六日・答錯 30% | 307 | 795 | 1,152 | 未發完（第 1,212 天 22／292 項） | — | 20 分 | 7 天 |

- 答錯 30% 的學習者每天留到隔天的到期卡都 ≤ `3 × review_cap ＋ 兩次收尾之間新增的到期量`（C1），但 866 個學習日中 795 天受限，專區幾乎沒有發放。這是「積壓有界」與「進度」的取捨，暫停線各倍數的比較見 O12。專區幾乎不發已裁決接受（O12）。
- 附註（2026-11-10，第二輪修正）：D2 的收尾預留加上限：一天至多預留 review 秒數的一半（`tail_card_limit`），佇列第 3、4 步也以同一個數為當日上限，超過的收尾新卡留到之後幾天。原因是長期無聲後打開聲音，收尾新卡一次 297 張，`review_cap` 被扣到 1、T1 顯示 47 分（20 分方案，review_rust R2-H1）。上表的認真學習者與答錯 30% 的學習者收尾最多約 20 張，從未碰到上限，重跑後數字逐項相同。模擬另加三條不變量：到期數 > 暫停線（現為 `5 × capacity`）的積壓日不給主線切片、積壓第 3 天起未過線給最小切片（兩邊一起釘住 `BACKLOG_PAUSE_FACTOR`）；只排複習的日子 `review_cap` > `capacity`；`capacity ≥ 8` 時 `review_cap ≥ 2`。上表的 C1 上界以當天 `review_cap` 計，只排複習的日子是合併後的上限，鬆，不能用來比較暫停線的倍數（review_rust R2-M2）；暫停線的倍數已在 O12 重選。
- 附註（2026-11-15，O13）：專區已移除。D1 的「暫停專區」與看劇聽歌任務、D3 的專區完成日、上表的「專區完成」欄與專區預估誤差不再適用。上表是含專區時量的，保留作為當時的依據；移除後重量的數字在 O13，重現指令相同，輸出以 O13 的表為準。積壓的兩條線、只排複習、D2、S0 60／40、10 分 2／6／1／1 都沒有改。

**O12 第三輪裁決（O11 的後續）。** 2026-11-10 裁決，2026-11-11 實作、審查與修正完成。共 31 項：學習計畫 P1–P13、內容 C1–C3、介面 U1–U15，每一項都可推翻，下面逐條寫結果、理由與怎麼改回。「做」表示本輪實作，「接受」表示維持現狀，「延後」列入 P1。實作與審查時裁決沒寫到、多做的判斷放在最後一段，其中標「負責人請確認」的同時列在 `docs/TASKS.md`「待負責人裁決」。每一項的測試出處見 `docs/TASKS.md`「第三輪修正」。規格細節在 rust-core §7.2、§7.6，curriculum §11.3、§13，flutter-app §3.1、§3.2、§3.7、§4.4、§4.5、§7.3。

附註（2026-11-15，O13）：專區已移除，下面各項提到專區、短劇、看劇聽歌任務、S5、S6 的部分是當時的紀錄。P1 的「暫停專區」（只排複習照舊）、P5、C3、U4 與最後一段的「S6 完整形與口語形相同時」失效；P7、U1、U8 提到的任務、S5、`ZoneRunner`、任務卡已不存在。P3 的量測表是含專區時量的，是當時選 5 倍的依據，倍數不重選；移除後 5 倍的量測在 O13。

學習計畫：

- **P1（做）回鍋日的積壓。** 暫停專區與只排複習看到期數（`due > 2 × capacity`，`Recovery.backlog`），不看原因標籤。`ReturnAfterBreak` 的 `review_cap` 減半照舊，併入後再減半（20 分方案、到期 300 張：150 的一半 75）。理由：回鍋日的積壓往往最大，原本卻照發專區、演練、聽力，複習上限又減半（同一例原本 cap 33）。改回：`budget.rs` 的 `Recovery::pauses_zone`、`reviews_only` 改判 `reason == ReviewBacklog`。
- **P2（做）休息日。** 不遞增 `recovery_days`（維持前一筆快照的值；回鍋落在休息日是唯一例外，見最後一段），複習上限用階段配比，不併入方案分鐘。理由：否則週末打開 App 會把「第 3 天起給最小切片」提早，休息日也會排滿整個方案長度的複習。改回：刪掉 `budget.rs` 的 `recovery_days` 前兩個分支與 `Recovery::reviews_only` 的 `is_study_day` 條件。
- **P3（做）暫停線倍數：`BACKLOG_PAUSE_FACTOR = 5`（原為 3）。** 選擇規則：C1–C4 都成立、四種方案的認真學習者量測（預估誤差 ≤ 5%、留到隔天 ≤ 2 × cap、T1 不超過方案分鐘）不變差的前提下，取答錯 30% 學習者 L30 完成最早的倍數，平手取較小者。改回：改 `budget.rs` 的常數，並同步模擬的 `PAUSE_LINE_FACTOR`（`rust/tests/common/loop_invariants/budget.rs`）與 `jp_plan/tests/budget.rs` 的邊界值。量測（最終設計，release，真實 `p0`）：

| 倍數 | 認真學習者 10／20／30／45 分（主線完成、留到隔天最多、積壓天數） | 答錯 30%：L30 完成 | 學習日／積壓天數／只排複習 | 留到隔天最多（÷cap） | 超出 C1 | 最長停滯（日曆／學習日） | 專區項目 |
|---:|---|---:|---|---|---:|---|---|
| 3 | 423／253／180／144；32／58／65／49；10／2／0／0 | 1,600 | 1,186／1,089／762 | 228（2.40×） | 0 | 13／9 | 34／292 |
| 4 | 同上 | 1,370 | 1,022／951／549 | 282（3.21×） | 0 | 12／8 | 22／292 |
| 5 | 同上 | 1,152 | 866／795／389 | 307（4.27×） | 0 | 7／5 | 22／292 |

  三個倍數的認真學習者逐項相同（預估誤差最大 +2.4%，T1 最大等於方案分鐘），所以 L30 最早的 5 倍入選。審查另量 6 倍：`review_backlog_stays_bounded_for_a_struggling_learner` 失敗，超出 C1 116 天（L30 第 990 天），所以 5 倍也是最終設計下滿足 C1 的最大整數。代價是答錯 30% 的學習者留到隔天的張數由 228 增為 307（仍在 C1 上界內）。邊界學習者（`p0_learning_loop_edges.rs`，5 倍）：每 6 週消失 8 天、答錯 20% 的學習者 9 個回鍋日都到期數過線、都只排複習，`review_cap` 60–70（`capacity` 47–65，到期 203–626）；週一到週五加週末打開、答錯 30% 的學習者 300 天中積壓 177 天、只排複習 46 天。第三輪審查後另加週一到週五、每 40 天消失 8 天、答錯 20% 的學習者（回鍋日輪流落在一週的每一天）：7 個回鍋日中 2 個落在休息日，其餘 5 個都只排複習；300 天中積壓 49 天、留到隔天最多 345 張，超出 C1 上界 2 天（C1 不在邊界模擬的判定規則內，只列量測）。加入回鍋判定的修改後，上表與前述學習者的數字逐項不變。

- **P4（接受）積壓日只排複習。** 保留。理由：沒有它會長期停滯（O11 D1 補充：只停新內容時最長 34 個日曆天沒有主線切片）。改回：`Recovery::reviews_only` 回 `false`，並重跑本條的量測。
- **P5（接受）答錯 30% 的學習者專區幾乎不發。** 5 倍下第 1,212 天只發 22／292 項。這是長期 70% 保留率的壓力測試，不是典型學習者，主線優先是刻意的，不加「不建卡的專區項目」機制。改回：要發就得新增不建卡的專區發放路徑（rust-core §7.3），並重跑量測。
- **P6（接受）收尾上限。** 維持 review 秒數的一半（`TAIL_SHARE_DIVISOR = 2`，O11 附註）。改回：改 `budget.rs` 的常數。
- **P7（接受）積壓日文案。** `flutter-app.md` §3.2 目前的表，因為積壓日照常列出檢定與任務，不說「只複習」。改回：改 `today_copy.dart` 的 `recoveryMessage`。
- **P8（接受）T1 預估不含答錯卡的當日重新學習步驟。** T1 是計畫量，不是實際花費。改回：把重新學習的時間加進 `budget.rs` 的 `estimate_review_minutes`，C3「T1 不超過方案分鐘」要重量。
- **P9（做）lint R10 的「3 課內」只算主線 L 課。** 假名課不介紹單字，不佔時間窗，假名課裡的出現也不算重現，教在最後一個主線課的字不報。實作放在 `jp_content/src/lint/spaced.rs`（裁決寫 `order.rs`，抽成獨立模組，職責較單純）。結果：`vo.miru` 不再警告，`p0a` 教在 L07 的 18 個警告消失。改回：`spaced.rs` 的 `MainLine` 改以 `course.order` 全部計數。
- **P10（做）活躍日（rust.F4）。** K1 自由練習的作答、只考檢定的日子都算活躍（各累加 `drills_done`），只用在連續天數與統計（裁決寫的是「連續天數用」；回鍋判定另看 `plan_active_dates`，見最後一段）。K1 仍不推進計畫（C06）。改回：`session.rs` 的 `kana_submit` 只在切片內累加，`plan_progress.rs` 的 `insert_milestone_result` 不寫 `daily_activity`。
- **P11（接受）對話跟讀三級自評（SPEC-04）。** 不持久化，當下回饋用，不影響排程，只累計 `daily_activity` 的練習統計。改回：要持久化得加資料表與 DTO。
- **P12（接受）FSRS 第一次複習落在第 6 天（J3）。** 沿用 rs-fsrs 預設參數，不調。上線後用 `review_log` 校正。改回：改 `jp_srs` 的參數。
- **P13（接受）K18、K19 沒有 K2 題目。** 由規則卡進入即可。改回：加內容，L1 的練習按鈕會跟著出現。

內容：

- **C1（做）10 個整句 `{ja:S|K}` 多解標記拆成逐詞。** `di.lost_item.casual`、`gr.ga_in_rel`、`gr.kai_freq`、`gr.suki`（`explain_zh` 2 處、`trap_zh` 1 處）、`no.tr.adj_past` ×2、`vo.norikaeru`、`vo.suki`，語意與讀音不變，振假名只標在漢字上。多解檢查加進 lint R19（警告級），`p0`、`p0a` 都是 0 筆。審查另把 `gr.kai_freq` 的 `{ja:1週間に3回泳ぎます|…}` 拆開，它對齊唯一、R19 不報，但 `3回泳` 的振假名蓋在一起。理由：多解時執行期退回整段 ruby，假名也被讀音蓋住。改回：不檢查多解就刪 `jp_content/src/lint/text.rs` 的 `check_ja_span` 裡多解的分支，並放寬 `real_content_has_no_r10_or_r19_findings`。
- **C2（做）R10 剩下的警告。** P9 之後 `p0` 剩 14 個。`vo.otearai`：`dr.l06.sub.001` 第一列由 `学校`／「我去學校。」改為 `お手洗い`／「我去洗手間。」。一〜万 13 張數字字卡是刻意設計，登錄在 `rust/content/lint/r10_allow.txt`，每行有逐字屬實的理由（8 字寫 L04–L06 實際出現的時刻，5 字寫這三課沒有這個讀音）。現在 R10 0 筆。改回：刪掉該字那一行，R10 會再警告。
- **C3（延後）實機聽專區的 debug 推進入口。** 不做，維持 release 介面最小。`docs/TTS_DEVICE_CHECKLIST.md` 請測試者走真實進度，或把例句貼到系統朗讀試聽。列入 P1。

介面：

- **U1（做）振假名餘量與行首行尾。** ruby 比底字寬、懸掛額度用完後還有剩時，餘量依 JIS X 4051 的 1:2:1 分配（字間一份、兩端各半份，單一底字置中）：`ruby_fit.dart` 算 `baseSpacing`，`RenderRubyBox` 在 layout 時當底字的 `letterSpacing`。行首行尾由 `RubyOverhangBoundary` 兩階段排版，ruby 不懸出容器，貼齊容器的 ruby 只往內側懸，至多一個 ruby 字寬；ruby 本身比一行還寬時沒有地方加寬，守不住這個上限（真實內容 3,830 字串 × 15 種寬度字級，只有 `{ja:4月1日月曜日|しがつついたちげつようび}` 在 288×2 倍內文、288×2 倍圖說、150×1 倍內文各 1 筆，288 是 320 手機扣邊距的寬度）。`MixedText`、`RubyLine` 一致。S5 列首「大丈夫？」「私：」不再有連續空白（截圖確認）。改回：`baseSpacing` 回 0；不判定行首行尾就拿掉 `RubyOverhangBoundary`。
- **U2（做）行首行尾禁則。** 字元表在 `ruby_kinsoku.dart`：開括號不落行尾、併進下一個盒子；小書き假名、`ー`、`々ゝゞヽヾ` 不落行首、併進前一個盒子（與收尾標點同一機制）。`RubyLine` 開頭是這種字的詞（`って`）和前一個詞組成一組，開頭的字併進前一詞最後一段的盒子，點擊仍查原本的詞。`MixedText` 純文字段另插 U+2060。真實內容掃描 `RubyLine` 2,626 句、`MixedText` 3,830 字串，各 15 種寬度字級，禁則違規 0。改回：改字元表，移除某類字即可。
- **U3（接受）點到懸出部分的讀音由隔壁字接住。** 點底字正確即可。改回：改 `RubyBox` 的點擊範圍。
- **U4（做）S6 說明句。** 已開放、因為引用的詞還沒介紹而沒有「試試看」的項目（非 `no_tts_quiz`），在題目的位置顯示「排進今日任務學過之後，這裡就會出現練習題。」，判斷依據是 `summary.introduced`，`no_tts_quiz` 維持指向任務。實作時多加兩個條件：沒有語音時不顯示（193 個可出題項目有 169 個只有要語音的題，學過也取不到題）；T2 的專區任務不顯示（結案後才寫 `item_intro`）。`dz.yappa`、`dz.mon_noun` 兩項短期不成立，見 `docs/TASKS.md`。改回：`zone_item_view.dart` 的 `explainWhenEmpty` 傳 `false`。
- **U5（做）T1 沒有事可做時不列複習。** `visibleTasks` 只在 `due + learning + new_cards > 0` 時列 `Review`，第一天全 0 時不列。只剩收尾新卡時裁決要繼續列，呈現見最後一段。改回：`today_copy.dart` 的 `visibleTasks`。
- **U6（做）T3「不到 1 分鐘」。** 不到 1 分鐘不顯示小數。改回：`today_copy.dart` 的 `studyTimeLabel`。
- **U7（做）L1 進度條略過的格子。** 稿紙條與課程列方格都是 `line.grid` 填色加一條 `ink.secondary` 斜線，未開始是空格，兩種主題都有 widget 測試與截圖。斜線對填色的對比：淺色 3.28、深色 4.93，高對比 3.54／3.47。改回：拿掉 `drawSkipSlash` 的呼叫。
- **U8（做）文案統一為「略過這一項」。** `SkipItemButton` 用在 T2、L3、`ZoneRunner`、聽力、任務卡。檢定的「先略過」是規格裡的另一個動作，不改。改回：改 `ink_buttons.dart` 的文案。
- **U9（做）返回元件統一為「箭頭＋返回」。** 視覺元件只剩 `BackLine`（`PageBackLink`、`PopBackLine` 是同檔案內只處理導覽的薄包裝），`KanaBackLink`、onboarding 的 `_BackLink`、`page_back_link.dart` 已移除。引導流程的文字用「上一步」、進行中的練習用「離開」，語意不是回上一層，只換文字不換元件。改回：個別畫面傳不同的 `label`。
- **U10（做）O6「知道了，繼續」防連點。** `expectation_view.dart` 的 `_dismissing`，處理中忽略再次點擊，審查後「關於程度」處理中也不能按。改回：拿掉 `_dismissing` 的判斷。
- **U11（做）`lessonNumberLabel` 回傳可讀的課名。** `le.lNN`「第 N 課」、`le.kNN`「平假名第 N 課」、`le.kkNN`「片假名第 N 課」，無法辨識的 id 才退回原始 id。改回：改 `course_groups.dart` 的 `_lessonNamePatterns`。
- **U12（做）S3 與 L2 一致。** 兩邊共用 `DialogueSummaryTile`，未到的對話可點，S4 標「還沒學到第 N 課，可以先聽聽看。」，報讀也念「還沒學到第 N 課」。改回：改 `dialogue_summary_tile.dart` 與 `dialogue_screen.dart` 的 `_AheadNote`。
- **U13（延後）寬螢幕（768／1024）版面。** 手機優先，列入 P1。
- **U14（只驗證）K3 在 320 寬「。」落到行首。** 確認已解決，沒有改程式：7 張規則卡在 320 寬、1／1.5／2 倍字級每一行都守禁則，音調入門卡寬 300–375 逐 px 的「。」都和「飴」同一行，golden `k3_rule_card_320.png`。
- **U15（接受）`ん` 的 `tts_text`、音調入門規則卡的例字。** 等實機 TTS 檢查結果再決定，列在 `docs/TASKS.md` 的實機驗證項目。

實作與審查時多做的判斷（裁決沒寫到）：

- **回鍋判定的最後活躍日（審查 RC1、RC3）。** `ReturnAfterBreak` 改看 `plan_active_dates`（複習、新卡、完成課、跟讀，或當天有任務結案），不含只有 `drills_done` 的日子。理由：定級檢定算活躍後，新使用者考完隔 4 天以上才開始，會永遠停在「歡迎回來」拿不到新內容；缺席中答一題 K1 也會取消隔天的回鍋保護。代價：計畫內的演練只答幾題、沒有結案的日子不算回到計畫。改回：`today.rs` 的 `build_snapshot` 改用 `active_dates`。
- **回鍋要有卡可碰（審查 RC1，負責人請確認）。** 到期卡與收尾新卡都是 0 時不判回鍋。理由：這天做不了事、不會變成活躍日，判回鍋的話天天都是回鍋，沒有出口。改回：`budget.rs` 的 `is_return_after_break` 拿掉第二個條件（並處理沒有出口的情況）。
- **回鍋落在休息日（審查 RC4、RC6，負責人請確認，和 P2 字面「維持前一筆」有出入）。** `recovery_days` 歸 0，下個學習日從 1 起算；`review_cap` 照樣減半，只是不併入方案分鐘。理由：維持舊值時，缺席前累積的天數帶過整段缺席，同一個人週六回來比週一回來提早拿到新內容（週六回來下週一 `Minimal`、上限 60；週一回來兩天只排複習、上限 75／150）。P2 擋的是「週末打開 App 提早」，這條路徑正好提早了。改回：刪掉 `budget.rs` 的 `recovery_days` 第一個分支。
- **T1 只剩收尾新卡的列（U5 的呈現，審查 F2、整合測試 F-A，負責人請確認）。** S0 第 2 天起這一列都在。保留，副標改「最後再看 N 張新卡」，不寫「0 張」、不用「收尾」這個詞，淡色但不蓋完成章。改回：`today_task_list.dart` 的 `_trailing` 拿掉 `isTailOnlyReview` 判斷；也可以整列不列，只留清單下方的「收尾」列（`today_copy.dart` 的 `visibleTasks`）。
- **`MixedText` 段首與空白（U2 的範圍，審查 F3，負責人請確認）。** 日文段前面緊接文字時段首也插 U+2060，空白後面接不能在行首的字時換成 U+00A0，只有段落第一個字例外。代價：單獨舉例的假名會和前一個字一起換行。改回：`mixed_text.dart` 的 `_textSpan` 拿掉 `afterText` 與 `withNoBreakSpaces`。
- **S6 完整形與口語形相同時（整合測試 F-B）。** 只顯示一個、不畫箭頭，因為箭頭暗示有縮約變化。改回：`zone_item_view.dart` 的 `_ContractionLine`。

**O13 移除日劇與日文歌專區（2026-11-15 裁決）。** 負責人決定把日劇與歌曲的部分完整移除，程式、內容、文件都不留用不到的東西。下面依序寫移除範圍、保留範圍、實作時已定案的決定、失效的既有裁決、後果與移除後重量的數字。O1、O7、O11、O12 與第二部分的原文不改，只加附註指到這裡。驗證結果見 `docs/TASKS.md`「第四輪：移除專區」。

移除範圍：

- **日劇聽解專區。** `dz.*`（`zones/drama_*.json`，178 項）、例句 `se.dz_*`（含完整形 `full_t`）、專區演練 `drills/zone_dz_*.json`、專區單字 `vocab/zone_dz_*.json`（`zone_item`）。
- **日文歌專區。** `so.*`（`zones/songs_*.json`，60 項）、例句 `se.so_*`、`drills/zone_so.json`、`vocab/zone_so.json`。
- **看劇／聽歌任務。** `mi.*`（`zones/missions.json`，24 個）、`TaskDto::Mission`、`mission_log`。
- **短劇。** `di.scene_*`（`dialogues/scenes.json`，8 篇）與 `kind: scene`、`genre`、`release_week`。
- **預告語塊。** `vo.pv_*`（`vocab/preview.json`，46 筆）與 `preview_batch`，全部移除，含 K05、K10 的日常問候。
- **題型 `contraction_decode`。** 題型由 20 種變 19 種，手寫演練的變體剩 12 種。
- **專區排程與進度。** `zone_items_per_day`、`zone_every_days`、分週釋出、今日任務的 `Zone` 與 `Mission`、專區完成日預估（`zone_forecast_end`）、專區項目的進度、介紹與 `use` 卡、`no_tts_quiz`、`DisplayContext.zone`、`srs_card.origin`。
- **學習目標。** 引導流程第 2 步「你對什麼最有興趣？」（flutter-app 的畫面代號 O2，不是本檔的裁決 O2）與 `learning_goals` 設定。
- **Flutter 的專區畫面與入口。** S5、S6、聽說頁的專區區塊、`/listen/zone/...` 路由、1.2 倍語速。

合計刪除 39 個內容檔、1,421 筆（專區項目 238、任務 24、短劇 8、預告語塊 46、專區單字 180、專區例句 694、專區演練 231），另刪 1 題 `false_friend`（見下）。

保留：假名、主線 L01–L30（單字、文法、例句、演練）、筆記、里程碑檢定、學習計畫的主線部分、複習（FSRS）、課文對話（`lesson`）、常體版對話（`casual`）、實戰對話（`extra`）、聽說頁的「語音示範」「對話」「今天的聽力」。文法的 `use` 卡、`item_intro`、`use_level` 是主線共用的，不動。

內容與門檻的決定：

- **單字數門檻。** `p0` 目標由 950 改為 800（移除後實數 812），`full` 目標由 1,600 改為 1,400（S1–S2 800、S3 600）。lint R17、`content_tool` 測試、`real_content_p0.rs` 的 `api_counts`、curriculum §4.1、§4.2、§14 一起改。
- **`vo.pv_yakusoku`。** `no.ff.yakusoku` 原本綁這個預告語塊，改成 `vocab: null`、`lesson: null`（與 `no.ff.jama` 相同做法），只出現在筆記總覽；`dr.l14.ffr.002` 刪除。同形異義筆記維持 60 則，`false_friend` 題由 28 題變 27 題。
- **lint R14 整條移除。** 歌詞拒絕清單、`originality` 與 `lint/lyric_denylist.txt` 一併刪除。verify 的 L01（禁用 `source` 等鍵）不動。原創性沒有機械檢查，靠人工抽查。
- **lint 規則不重新編號。** R13、R14、R21、R22、R23 留空號。
- **`content_tool available` 的 `flags` 欄移除。**
- **verify C04（字幕詞頻報告）保留**，當一般選字參考。
- **`UseLevel::RecognizeOnly`、`Style::Mixed` 保留。** 是通用語意，日後內容可能使用；對應的 DTO 值與 Dart 文案也保留。現在的真實內容沒有項目使用這兩個值。
- **統計類別名稱不改。** 「主線例句」等措辭照舊。
- **ID 直接刪除，不留 `retired: true`。** curriculum §12.1 規定已發布的 ID 永不刪除、以 `retired` 淘汰；這批內容尚未對外發布，所以例外。
- **共用夾具（`jp_content/tests/fixtures/full`）瘦身。** 保留行為若因此失去唯一的測試資料，在主線夾具補最小的資料（實際只補一筆：`se.l21.010` 加句子層級的 `tts: kana`），不為了讓測試通過而刪掉保留行為的測試。

Rust 的決定：

- **資料庫。** App 尚未發布，直接修改 `001_init.sql` 移除 `mission_log` 表與 `srs_card.origin` 欄，不新增遷移，不寫清理既有資料的程式。`CardOrigin` 整個移除。
- **升級當天的舊快照。** 含 `Zone`、`Mission` 任務的快照會解析失敗，接受「重建當日快照」這個一次性行為，不加相容碼。
- **`DisplayContext.zone` 移除**，`DisplayContext` 結構保留，只剩 `lesson_id`。
- **釋出的分鐘。** 專區原本佔用的分鐘回到 `preset.split` 原本的配比，不重新調整配比與常數（`BACKLOG_PAUSE_FACTOR = 5`、S0 60／40、10 分 2／6／1／1 都不變）。
- **學習迴路模擬。** 專區相關的量測與不變量刪除；與專區無關的對帳留成簡化版（`NewContent` 分鐘等於 new 額度、`Listen` 分鐘等於 listen 額度，額度不足 0.5 分不列 `Listen`；長模擬 `new_content_and_listen_minutes_match_the_budget`）。長模擬重跑，不放寬門檻。
- **`jp_lang` 測試與文件範例借用的 `dz.*` 範例 ID** 改成主線 ID（`gr.te_iru_prog`、`gr.n_desu`），行為不動。

Flutter 的決定：

- **1.2 倍語速整條移除。** `TtsSpeed.fast`、`allowFast` 等一併刪除，語速只剩正常與慢速。已存的 `tts_rate = 1.2` 讀到時當成一般速度，不寫遷移。
- **引導流程路徑不重新編號。** 保留 `/welcome/o3`、`o4`、`o5`，歡迎頁直接進 `o3`，進度格改為 4 格。
- **「關於程度」與期望說明。** 刪掉「聽懂日劇」「理解日文歌」兩列目標，以及宣稱聽得出縮約形這類與專區綁定的「做得到」敘述；與專區無關的誠實限制說明保留。
- **複習積壓文案。** 拿掉「專區新項目暫停」，三種情況改成「複習還有一些，今天學一小批新的。」「複習還有一些，今天先複習。」「複習累積了一些，今天的時間先給複習，主線新內容暫停。」。
- **`AnswerCompare` 的 `policy` 參數與 `CompareSide.sentence`** 在 `contraction_decode` 移除後成為死碼，一併移除。
- **`estimateLines()` 維持 `List<String>` 簽章。**
- **`DialogueRunner` 的「沒有測驗題時直接進第二階段」** 保留為防禦性行為（保留的 48 篇對話都有測驗題）。
- **借自專區內容的測試樣本字串** 只改識別字與註解，不改字串本身，避免無謂重產 golden。
- **整合測試 J9（`after_l21_journey_test.dart`）** 裁剪保留，留下常體對話（進 S4 跑完四階段再按「回到列表」；這條 S4 完成路徑原本由短劇步驟帶到，改由常體對話承接）、L22 教學卡等保留內容的覆蓋，檔名不改。`integration_test/support/ruby_layout*.dart` 的呼叫端全在被移除的畫面（S5 清單、S6、任務卡），連同其單元測試一起刪除（三個檔）；真實畫面上的振假名餘量與禁則量測因此不再有，同樣的規則只由 `test/core/text/` 的 widget test 驗。
- **補少量反向回歸測試。** 聽說頁沒有專區區塊（`listen_home_screen_test.dart`）、`/listen/zone/...` 路由不存在（`router_test.dart`，兩條路徑）、引導流程沒有學習目標步驟（`onboarding_flow_test.dart`），共 4 個測試案例。

文件的決定：

- `docs/design/curriculum-zones.md` 刪除。
- 章節、規則與畫面代號不重新編號：curriculum §4.5、§8、§9、§11.3-7、引導步驟 O2、畫面 S5／S6 留空號或標「已移除」。
- `docs/TASKS.md` 的歷史紀錄保留原文，只加註。

失效的既有裁決：

- **O1。** `p0a` 的預告語塊、`p0` 的預告語塊 L14 批次、專區、短劇、看劇／聽歌任務、`full` 的其餘專區，以及「專區畫面用夾具驗證」。
- **O7。** 「專區於內容就緒後才露出入口」。不得提及 N4、不得承諾看懂日劇仍有效。
- **O11。** D1 的「暫停專區」與看劇聽歌任務、D3 的專區完成日、量測表的「專區完成」欄。
- **O12。** P1 的「暫停專區」部分、P5、C3、U4、「S6 完整形與口語形相同時」；P3 表的「專區項目」欄；P7、U1、U8 提到的任務、S5、`ZoneRunner`、任務卡。
- **第二部分的 `recommended_resolutions`。** C11 的專區解鎖、C12、C13、C18 的 `learning_goals`、C21、C22 的短劇、C23 的 `zone_items_per_day` 與 `zone_every_days`、C26、C27 的 `zone` 參數、C29 的「專區時間從 listen 扣」、C30 的「專區」欄與總量 1,600、C33、G08、G09 的 `so.sn_*`（`use` 卡候選少於 3 題時由例句補題照舊）、G10、G12 的預告語塊、B04 的「K05、K10 穿插問候語塊」、B07 的「L21 依類別分週釋出」。

後果：

- 平假名階段（K01–K19，10／20／30／45 分方案約 33／23／17／15 天）不再聽得到句子，因為 B04 用來補這一段的 K05、K10 問候語塊也在移除範圍內。
- App 不再提供日劇與日文歌的專門內容，也不再宣稱在「聽懂日劇」「理解日文歌」上做得到什麼。
- `QuestionType` 少一個值，`shadowing`、`false_friend` 的序號各往前一格；Rust 與 Dart 綁定必須來自同一次產生。
- `001_init.sql` 是直接改的，修改前建立的開發或測試資料庫會留著 `origin` 欄與 `mission_log` 表，程式照常運作，建議清除 App 資料。
- 專案沒有版本控制。移除前的完整備份是專案目錄上一層的 `backup-before-zone-removal-2026-11-15.tar.gz`，要改回只能從它取回。

移除後的量測（`rust/tests/p0_learning_loop.rs`、`p0_learning_loop_edges.rs`，release，真實 `p0`、2026-03-02 起算，第 1 天＝起算日；重現指令同 O11）。常數都沒有重選，主模擬 15 個、邊界模擬 7 個長測試全過，九位學習者的不變量違反數都是 0。`plan_preview` 的主線完成日仍是 413／251／180／144 天。

| 學習者 | 留到隔天最多 | 受限天數 | 主線完成 | 預估誤差（主線） | T1 最大 | 最長停滯 |
|---|---:|---:|---:|---:|---:|---:|
| 10 分・每天全對 | 28 | 7 | 420 | +1.7% | 10 分 | 1 天 |
| 20 分・每天全對 | 47 | 0 | 251 | 0% | 20 分 | 0 天 |
| 30 分・每天全對 | 37 | 0 | 180 | 0% | 30 分 | 0 天 |
| 45 分・每天全對 | 31 | 0 | 144 | 0% | 45 分 | 0 天 |
| 20 分・缺六日・答錯 30% | 339 | 764 | 1,110 | — | 20 分 | 6 天 |

- 與 O11 的表相比，認真學習者的主線完成日由 423／253／180／144 變為 420／251／180／144，受限天數由 10／2／0／0 變為 7／0／0／0，留到隔天最多由 32／58／65／49 變為 28／47／37／31，預估誤差最大由 +2.4% 變為 +1.7%。移除前後的差別只有專區：專區項目不再排程、不再建卡，專區佔用的聽力分鐘回到 `preset.split` 原本的配比。
- 答錯 30% 的學習者（對應 O12 P3 表的 5 倍列）：第 1,110 天學完 L30（原 1,152），836 個學習日中積壓 764 天、只排複習 362 天，留到隔天最多 339 張（4.17×cap，原 307），超出 C1 上界 0 天，最長停滯 6 個日曆天／4 個學習日。3、4、6 倍沒有重量，O12 P3 的倍數選擇不重做。
- 邊界學習者（5 倍）：前 300 天無聲之後有聲的學習者第 251 天學完 L30，打開聲音後收尾新卡一天最多 4.4 分；每 6 週消失 8 天、答錯 20% 的學習者 9 個回鍋日都到期數過線、都只排複習，`review_cap` 63–69（`capacity` 53–65，到期 214–569）；週一到週五加週末打開、答錯 30% 的學習者 300 天中積壓 189 天、只排複習 34 天；週一到週五、每 40 天消失 8 天、答錯 20% 的學習者 7 個回鍋日中 2 個落在休息日，其餘 5 個都只排複習，留到隔天最多 349 張，超出 C1 上界 2 天（C1 不在邊界模擬的判定規則內，只列量測，移除前是 345 張、2 天）。

實作時多做的判斷（裁決沒寫到，負責人請確認，同時列在 `docs/TASKS.md`「待負責人裁決」）：

- **主線內容裡提到日劇、戲劇或歌詞的語感說明保留。** `gr.te_wa_ikenai`（「日劇裡常聽到口語的 〜ちゃだめ」，只刪掉後半「之後專區會學」）、`gr.plain_style`、`gr.kedo_soft` 提到日劇，`gr.da_copula`、`gr.sfp_kana` 提到戲劇，`vo.boku` 提到歌詞裡的用法。這些是對日語用法的一般描述，不指向被移除的功能。要拿掉就改 `rust/content/grammar/s2.json` 與 `vocab/people.json` 這幾則的文字。
- **完整版的期望說明仍寫「無法做到無字幕追劇」。** `expectation_copy.dart` 的 `ContentStage.full` 只拿掉「聽得出常見語尾與縮約形」，限制說明照「與專區無關的誠實限制說明保留」留下。要拿掉就改同一個檔。
- **「關於程度」不再有日劇與歌曲的限制說明。** `scope_copy.dart` 的兩段限制文字隨「聽懂日劇」「理解日文歌」兩列一起刪除，沒有併進其他列。
- **`/welcome/o2` 顯示歡迎頁。** 引導路徑不重新編號，`o2` 沒有對應步驟，落到預設分支顯示 O1；`/listen/zone/...` 沒有對應路由，走 go_router 的預設錯誤頁。App 沒有外部深連結，使用者走不到這兩條路徑。
- **O11、O12 的量測表保留原文、加附註。** 新數字只寫在本條，沒有回頭改 O11、O12 的表。

## 第二部分：批判審查原文

===== contradictions 37
 * C01〔阻斷〕今日任務拿不到內容：rust-core §7.4 的 DailyTask 帶 ID（words/grammar/kana、sentence_ids），§9.5 的 TaskDto 只回數量（words: u32、sentences: u32）。flutter-app §3.2 要「NewContent→依內容進 K2／單字／文法」「Listen→聽力」，但 §9.4 沒有任何 API 能取今日切片；kana_session 取整課，且不存在 listen session。
 * C02〔阻斷〕字卡互動模型不同：flutter-app §3.4 的 V4 一律翻面＋四鍵自評（submit_answer SelfGrade），rust-core §9.6 也如此對應；rust-core §6.1 卻規定 recog＝日→中四選一、listen＝聽音選中文、read＝kana_read、use＝演練題，§6.2 自動判定。V4 無法處理 Choice／Reorder／Typing。
 * C03〔阻斷〕語音不可用時會卡死：flutter-app §6.4 要求聽力題「略過，不計入對錯或 FSRS」；rust-core §9.5 的 AnswerPayload 沒有 Skip，§6.4 session_next 只回第一張符合的卡。到期的 :listen 卡會無限重現，使用者只能亂答污染 FSRS。
 * C04〔阻斷〕正常學習也會被判落後：rust-core §7.2 條件 3 為未學 priority 0 新卡數 > new_words_limit 時當天禁新內容；§7.3 在 complete_task 才建 state=0 卡；flutter-app §3.2 任務順序是複習在前、新內容在後。20 分方案當天 5 字＋1～2 文法＝6～7 張未學卡，隔天 6～7 > 5，整天禁新內容，還顯示「昨天的新內容還沒看完」，進度約減半。
 * C05〔高〕Review 沒有 key：flutter-app §3.2 所有任務完成時呼叫 complete_task(key, durationMs)；rust-core §7.4 的 DailyTask::Review 與 §9.5 的 TaskDto::Review 都沒有 key，§7.4 又說完成狀態由 daily_task_done 判定。
 * C06〔高〕首次流程繞過任務模型：flutter-app §3.1 O6 在 create_plan 後直接進 le.k01 的 K2「不經過首頁」；rust-core §7.3／§7.4 的新內容必須來自 today_view 快照並以 complete_task 結案，且 20 分方案 K01 當天只取 3 字。直接進 K2 不會結案，回 T1 仍顯示新內容未做，範圍也與切片不符。
 * C07〔阻斷〕假名建卡與課完成條件互斥：rust-core §6.1／§6.5 說熟練後才建 :read 卡；§7.3 說 complete_task 的 introduce_items 同 transaction 建卡。若以熟練為準，未達標的字游標過後永遠進不了 FSRS。§7.3 的完成條件只寫整合日，K／KK 課沒有；K10、K16–K19 字數為 0，max(1, round(0/…)) 無字可取，游標可能卡住。
 * C08〔高〕判定責任不一致：rust-core §8.4 稱「判定以 Rust 為準」，但 kana_drill_submit(is_correct)、Match{all_correct}、checkpoint_finish(correct, total) 都由 Dart 算。flutter-app §3.3 要每題呼叫 kana_drill_submit，rust-core §6.5 只計 kana_read／listen／confuse；kana_match（5 字）、minimal_pair、kana_word 沒有單一 kana_id。flutter-app §3.6 要「結束列弱項」，只回傳總數的 checkpoint_finish 算不出弱項。
 * C09〔高〕含隨機變體的題目無法判定：rust-core §8.4 的 substitution 依種子選 rows、conjugate 依種子選 lemmas；§9.5 的 QuestionRefDto 與 AnswerDto 沒有 seed 或變體索引，§8.4 又稱判定不必重新產生題目。Rust 無從得知答的是哪一列或哪個動詞。
 * C10〔高〕檢定課定義衝突：rust-core §7.3 把「L 課」與「檢定課」列成互斥課型；curriculum §11.1 的 L07、L14、L21、L40、L48 都是有新內容的課。curriculum §12.4 的 lesson.checkpoint 與 §12.6 的 milestone.lesson 是雙重來源。rust-core §8.5 要文法與單字各半，K19／KK08 沒有這些內容，且 curriculum §11.1 並無各半之說。flutter-app §3.6 的「先略過」沒有 API，略過後游標是否前進未定義。
 * C11〔高〕解鎖規則三種說法：curriculum §11.1 表格寫 ms.hira 解鎖 L01、ms.a1_half 解鎖 S2、ms.casual 解鎖專區，§3.3 寫畢業考需 90%，同節末又寫未通過不鎖死；§8 寫「學完該課後開放」；rust-core §7.3 用 pos(item.lesson) ≤ pos(游標)，游標一到 L21 就開放，當時常體尚未學；flutter-app §2.3 寫「L21 前整區鎖定」。
 * C12〔高〕專區時程互相矛盾：curriculum §11.4 以（200 字＋268 項）÷每日新字加進總天數（20 分＝463 天）；§11.2 的節奏是 20 分每 2 天 1 項，268 項需 536 天；rust-core §7.3 專區與主線平行、不阻擋，forecast 只到 L48（約 369 天）。專區實際完成約第 707 天，App 顯示的日期與文件永遠對不上。
 * C13〔高〕專區單字會灌爆課程切片：curriculum §4.3 的 lesson 必填，§4.2 寫專區 200 字隨解鎖批次；rust-core §7.3 由 items_by_lesson 取該課全部單字切片。專區字若標 le.l21，會讓 L21 新內容多出數十到上百字，主線卡數週。§12.6 的專區項目也沒有 vocab 欄位可關聯這些字。
 * C14〔高〕同課順序與順序鐵律失效：curriculum §12.3 單字依 vocab/<topic>.json 存放，§12.4 課內不列單字；rust-core §3.4 課內順序為（檔案路徑、陣列下標），等於依主題檔名字母排序。curriculum R04 只保證課層級，§11.3-3 卻按天切分，第 1 天的例句可含第 5 天才教的字；rust-core §8.3 第 3、4 層干擾項（pos ≤ 游標）也會出現未介紹的字。
 * C15〔高〕單字羅馬字會把歯輸出成 wa：rust-core §4.3 字串模式明定用於 vocab.kana，詞等於 は／へ／を 時輸出 wa／e／o；reuse §7.2 要求 kana 為 は／へ 的 vo.* 單獨顯示時輸出 ha／he，J08 列為錯誤。§4.5 typed_answer_matches 也用句子模式，輸入 ha 答 歯 會判錯。rust-core 只修了 t 模式。
 * C16〔高〕中文欄位內的日文標記三方不一：flutter-app §7.3 用 {{飯を食べる}}，並自動判定純假名；reuse §9.2 Z02 用 {ja:...}，純假名也必須包；curriculum §12.4 範例（compare_zh、hint_zh、trap_zh、title_zh）完全沒有標記。grep 結果：curriculum 內 {{ 與 {ja: 皆為 0 次。不統一就違反決策 7。
 * C17〔中〕字型決策未回寫：reuse §1、§5.4 預設繁中用系統字型，§10 的打包清單只有 Klee；flutter-app §4.3 改打包 Noto Sans TC 與 Noto Serif TC（約 9.7MB），F02、L02 會因此失敗。reuse §5.3 的字元集只有常用漢字（2,573 字），flutter-app §4.3 要聯集內容用字，reuse J02 也實測 嘘、綺、絆、儚 不在常用漢字內，照 reuse 流程 F01 必失敗。
 * C18〔高〕rust-core 未補 flutter-app 要求的欄位：flutter-app §5.3、§9 要 OptionDto.sentence、blank_word_index、SettingsDto.theme_mode 與 autoplay，rust-core §9.5 全部沒有。另 curriculum §12.5 的 particle_fill 是 blanks[] 可多空格，flutter-app 要單一 index，rust-core §8.4 的 Choice 也只有一組選項。O2 目標（flutter-app §3.1）、語音選擇（§3.9）同樣無處儲存。
 * C19〔高〕TTS 欄位覆蓋不足：curriculum §10.1 以 tts 標記防誤讀，§12.4 只有 sentence 有此欄位；§12.6 對話 turns、§12.5 substitution rows、§4.3 單字都沒有，§4.3 單字單獨發音的誤讀風險最高。逐詞播放（curriculum §10.1、flutter-app §3.7）用 WordDto，rust-core §9.5 沒有語音欄位，助詞 は 會念 ha。PromptDto、OptionDto 的 tts_text 是單一字串，flutter-app 實證 #9 要求 Linux 必送假名，含漢字時會念錯。
 * C20〔高〕單假名 TTS 備案沒有資料欄位：curriculum §10.1、flutter-app §3.3 說「由內容決定」改以例字示範；curriculum §12.4 的 kana 只有 example_words，沒有 tts_text，rust-core §3.2 又 deny_unknown_fields。例字備案也不適用 kana_listen 這種只播單音的題型。
 * C21〔高〕日劇對比聽力缺資料：curriculum §8、§10.1 與 flutter-app §3.7 都要例句的完整形與口語形各播一次；§12.6 的 drama_item 只有 full／short 片段，drama_sentence 只有口語句。§12.5 的 contraction_decode.choices 是純字串（何をしているの），不是 t，違反 R02、R12，沒有振假名與讀音，TTS 也會碰到 tts_risky 的 何。
 * C22〔高〕rust-core 宣稱與 curriculum「一一對應」的型別實際沒有規格：kana_word（§6.1、§14 要 20 題）無 JSON；§6.1 代碼表沒有範例用的 mpr；ka.rule.* 無 schema；SoundGroupDto 對不到 §12，ka.cf.* 的 members 也放不下 おばさん／おばあさん 這類詞；dz.scene_* 無 schema；no.rd／no.tr 無範例；dialogue.quiz 是內嵌還是 ID 未定義。
 * C23〔中〕計畫預設欄位未對齊：rust-core §3.2 要 kana_days_per_lesson 與小數 zone_items_every_days，curriculum §12.6 的 plan_preset 沒有 kana_days_per_lesson（grep 0 次），依 deny_unknown_fields 一加上就與規格不符，不加則切分無資料。rust-core §5.3 的 daily_minutes 允許 5–120，§7.1 卻只接受 10／20／30／45。
 * C24〔中〕P0 範圍與 UI、預期不符：flutter-app §3.8 寫里程碑線 8 個點，curriculum §14 的 P0 只有 6 個。curriculum §1.3、§11.4 與 P2 文案都以 L48 為完成點，P0 只到 L30，首發版會宣稱尚未提供的 N4 內容。
 * C25〔中〕UI 狀態沒有後端支撐：flutter-app §2.3「這課的題目都做過了」與「下次從斷點繼續」，rust-core §7.4 不存題目歷史，§6.1 明言不需歷史；G2「文法點狀態變為讀過」沒有 API；V2「未解鎖主題」與 §12.1 主題跨課矛盾，TopicDto 也無解鎖課；/session/cards?source= 對不到 session_next。
 * C26〔中〕看劇任務沒有資料也沒有變體：curriculum §10.3、flutter-app §3.2 都要每週一次「看劇任務」；flutter-app 同節卻說 TaskDto 七種變體，rust-core §9.5 無對應（grep 0 次），curriculum §14 也沒有這類內容。
 * C27〔中〕顯示規則無法表達專區：curriculum §10.2 專區振假名預設全顯示，與 L31 起的主線不同；rust-core §9.4 的 display_policy(&self) 無參數，§9.5 只依目前課別。word_spacing 依課別也會影響回看舊課。flutter-app §3.3 的 K1 romaji「依顯示規則」，L09 後參考表會失去羅馬字。
 * C28〔中〕選項語言窮舉不成立：flutter-app §7.2 說 switch 窮舉會編譯失敗，rust-core §9.5 的 question_type 卻是 String；清單也漏了 substitution、register_convert、kana_word、minimal_pair、kana_confuse，rust-core 單字題的 question_type 名稱全未定義。
 * C29〔中〕時間預算互相打架：rust-core §7.2 以每張 8 秒算 review_cap（9 分＝67 張），§7.4 演練卻以 30 秒一題，§6.1 的 use 卡正是演練題。Integration 只分到新內容額度（20 分方案 4 分鐘），flutter-app §3.7 的 S4 四階段放不進去。TaskDto::Zone 沒有 minutes、budget 也沒有專區，違反 curriculum §11.3-2 以當日分鐘數為上限。
 * C30〔中〕N5／N4 數量與基準不符：curriculum §4.2 為 N5 800、N4 600，§14 的 P0 寫「N5 800」；reuse §3.2 實測基準為 N5 684 列、N4 640 列。至少 116 字標 n5 卻不在基準內，且 App 要標「參考 N5」並依 reuse §3.3-5 標示 Waller 來源，標示會失實。
 * C31〔中〕ID 規則碰撞：curriculum §12.1 的 ka.hira.<romaji> 配合 rust-core §4.2（ぢ→ji、づ→zu）會讓 じ／ぢ、ず／づ 同 ID，違反 R01，片假名亦同。§12.4 的 st.* 不在 §12.1 前綴表。
 * C32〔中〕する動詞格式衝突：curriculum §12.2 寫 勉強|べんきょう|vo.benkyou し|vo.suru+ます，R07 要求合併 surface 等於單字，所以單字是 勉強；rust-core §4.7 的 vs 規則與 spike 以 勉強する 為單字（前綴保留）。兩者無法同時通過，§4.3 的 pos 也可能是 vs 或 n。
 * C33〔中〕專區解鎖違反自家順序：dz.se_kana 在 L21，對應 gr.sfp_kana 在 L22；dz.ck_doushiyou（どうしよう）在 L21，意向形在 L32，同類的 dz.ck_ikou 卻放 L32；so.cl_n（〜ん＝〜う）在 L30，意向形也在 L32。R04、R13 會失敗。
 * C34〔中〕筆記無處顯示：curriculum §2 明定未收入單字表的詞只出現在「漢字陷阱」總覽，P0 要寫 220 則筆記；flutter-app §2.2 路由沒有此畫面，rust-core §9.4 也無清單 API。
 * C35〔中〕教學必要欄位被 DTO 漏掉：curriculum §4.3、§8.8 要求 use_level（粗話提示）、§1.2 要標參考級別、T3 用 reading_family、T11 用 pair；rust-core §9.5 的 VocabDetailDto 全無。flutter-app §3.4 的 V4 背面也不顯示 notes，違反 curriculum §2 T1、T2「綁定單字卡」。WordDto.ref_id 跳過 @ 開頭的 ref，@new 的中文釋義點字查不到。A4 的 origin_kanji 在 flutter-app 出現 0 次。
 * C36〔中〕錄音回放未回寫：curriculum §6.1、§10.1 仍寫可錄音回放，flutter-app §3.7、§9 列為 P1。flutter-app 的 audio_first 詞塊可見也與 curriculum §10.2 字面不符，只寫「請確認」。shadowing 的三級自評對不到 rust-core 的四級 Rating。
 * C37〔低〕其他對齊項：rust-core §9.6 仍是 flutter-app 舊版介面（startTask、dueCards、rate、placementResult）；rust-core C1–C9 與 reuse C01–C06 命名空間相撞；reuse J04 允許 ゝゞヽヾ、ヷ，rust-core §4.2 回 InvalidChar；rust-core 只列 U+FF5E，curriculum 通篇用 U+301C（189 次）；reuse 用 -p content_tool，rust-core §1.2 沒有 workspace；R15 需 OpenCC，rust-core 無此相依且 reuse §9.1 稱 A 層不需外部資料；VocabDef 的 Vec、bool 未標 default，curriculum 範例省略時解析失敗；reset_all 會撞上 append-only 觸發器；rust-core §3.4 估 P0 4,500／完整 6,500 筆，依 §14 加總為 4,816／6,932；V4 鍵名「輕鬆」對 rust-core「簡單」。
===== gaps 12
 * G01 五十音：沒有「先教後考」。flutter-app §3.3 的 K2 只有測驗型，curriculum §3.3 也沒有呈現步驟，hint_zh、例字只在 K1 詳情條，origin_kanji 完全沒有 UI。促音、長音、助詞讀音、音調（K16–K19、ka.rule.* 7 張）沒有任何畫面。
 * G02 單字表：沒有首次學字流程，只有 V4 複習。搜尋語意未定（初學者打不出假名，需支援羅馬字與中文）。沒有收藏、標記已會、依熟練度篩選，suspended 欄位已預留卻未暴露。
 * G03 文法：grammar_list 無搜尋，沒有索引可查「這個 て 是什麼」；pattern、formation、full／short 這些含日文的欄位沒有振假名；ます幹、連用形等術語沒有術語卡或首次提示。
 * G04 句型演練：substitution 的 Choice 選項來源未定義，register_convert 沒有干擾項，reorder 的 distractors 在 Rust 未處理。演練幾乎全是辨識題，輸出只有 conjugate 打字，對「能對話」不足。answer 後要顯示的「語法重點」（curriculum §10.2）QuestionDto 沒有對應欄位。
 * G05 語音示範：S2 內容沒有 schema；音調示範建立在 curriculum §4.4 自認不保證正確的 TTS 上；Android／iOS 上單假名、多音字、音調都未驗證，卻是 S0 的基礎。
 * G06 安排計畫：沒有學習提醒（flutter-app §9 不做，本機通知不違反離線）；沒有「今天想多學」的入口（快照凍結整天，complete_task 不產生下一切片）；plan_preview 不分主線與專區完成日。
 * G07 日常對話：只有跟讀與選擇回應，MVP 又沒有錄音回放，學習者無法聽到自己的聲音。12 篇實戰與 16 篇常體版不進任何每日任務，只能自行從 S3 找，而這正是對話目標最有價值的內容。
 * G08 聽懂日劇：最重要的 12 篇 dz.scene_* 沒有 schema、畫面、排程。播放只有 1.0 與 0.7 倍，沒有快於正常的過渡。dz.se_yo（升降調）、dz.se_no_q／dz.se_no_ex、31 個感嘆詞、語體切換的區別在韻律，TTS 無法呈現，卻被 curriculum §8 強制要配 listen_meaning 或 contraction_decode。
 * G09 聽懂日文歌：so.sn_nasal_ga、so.sn_roll_r、so.sn_stretch、so.sn_wo_sung 都是聲音現象，TTS 示範不了；§10.3 只有看劇任務，沒有聽歌任務；每項僅 1 題，use 卡會永遠重複同一題；文語殘留排在 L30，20 分方案約第 8 個月。
 * G10 目標回饋太晚：專區在 20 分方案要到第 171 天（5.7 個月）、10 分方案第 278 天（9.3 個月）才開放，而 curriculum §1.1 自稱不讓學習者等到第十個月。O2 選的目標只改文案，選「日文歌」的人體驗毫無差別。
 * G11 僅本機資料卻沒有備份：rust-core §12.2、flutter-app §3.9 都把匯出列 P1，但 15 個月的進度在換機或解除安裝時會全部消失，也沒有伺服器可救。
 * G12 交付範圍：P0 仍有約 4,816 筆內容，1,618 句要逐語素標 ref，且 reuse §9.10 要求母語者審閱 S1 與專區。文件沒有可先端到端驗證的垂直切片，R17 的 CONTENT_STAGE 也只有 p0 與 full。
===== beginner_risks 12
 * B01 第一次打開就卡住：O6 直接進 K2，第一題就是沒看過的 あ 配 4 個羅馬字按鈕，只能亂猜。答錯或超過 3 秒又重置，第一分鐘就是挫折。
 * B02 沒有日語語音：台灣 Android 常需另行下載語音資料，廠牌路徑各異，O5 卻可略過。略過後 S0 完全無聲，學的是沒有聲音的假名，kana_listen 也卡死（C03）。Android／iOS 的探測都還沒有實機驗證。
 * B03 3 秒熟練門檻過嚴：連續 3 次且每次 3 秒內，答慢即歸零，未定義 kana_listen 的計時起點（TTS 啟動與播放都佔時間），也沒有放寬機制。年長者、肢體障礙或螢幕報讀使用者幾乎過不了。
 * B04 開頭一個月沒有句子：20 分方案 K01–K19 要 28.5 天，10 分方案 38 天，直接違反 curriculum §3.1「避免連續一個月只學字母」。批次也不均：宣稱每批 5–6 字，K14 有 21 字，KK06、KK07 有 25、33 字，依公式 KK07 一天要吃 22 字。
 * B05 羅馬字依賴：L01–L08 預設顯示羅馬字，約 2 個月，此時平假名已畢業，眼睛會直接跳到羅馬字。L09 不論片假名考過與否都會關閉（curriculum §10.2 與 ms.kata 不一致）。輸入一律羅馬字，而台灣使用者預設是注音鍵盤，未指定 Latin 鍵盤會打不出字。
 * B06 漢字讓字卡失真：recog 是漢字配中文四選一，電話、学校 不會讀也能答對，FSRS 就記為已掌握；listen 要等 scheduled_days ≥ 4 才解鎖。這與「聽懂」的主目標相反，學到的是看得懂卻聽不出來。
 * B07 資訊過載：L21 一次解鎖 171 個專區項目（本審查逐項統計），17 種以上題型沒有首次使用說明，FSRS 四鍵與間隔對零基礎者是術語。
 * B08 初期任務是空的：S0 預算有演練 4 分、聽力 2 分，但 K01–K09 沒有手寫題，S0 也沒有句子。清單會出現「句型演練」卻沒有題目，flutter-app §3.2 的範例還把 S2 分鐘數用在か行。
 * B09 引導順序：開始前要過 6 個畫面，第 6 個才是「無法無字幕追劇」的誠實預期，放在第一次成功之前會先打擊動機。O3 的「會一點假名」沒有對應 start_level，rust-core 的 Kana、Basic 在 UI 也選不到。
 * B10 回鍋難度：連續 3 個學習日未用就當天 0 新內容，到期超過 2 倍上限也是 0，沒有上限天數。積壓者可能連續多日只有複習，最容易流失的人最沒有新鮮感。
 * B11 時間承諾不實：use 卡一題可能 25–30 秒，卻以 8 秒估算，20 分鐘實際可能拉長到 30 分鐘以上，「約 20 分鐘」失去信任。
 * B12 TTS 教錯而不自知：單字無上下文時 人、方、今日 會誤讀；雨／飴 的音調示範可能本身就錯。零基礎者無從判斷，會直接學進去。tts_risky 若含 何、人，大量句子會落入純假名模式，分詞空白與音調品質也未經實機驗證。
===== recommended_resolutions 61
 * C01 裁決：新增 new_content_session(task_key) 回傳今日 KanaDetail／VocabDetail／GrammarDetail，與 listen_session(task_key)。TaskDto 維持數量，Flutter 新增 L3「新內容學習頁」，流程為呈現、播音、立即一題。
 * C02 裁決：以 rust-core §6.1 為準。V4 改為依 QuestionBodyDto 分派，評分列只在 SelfGrade 顯示。P0 定案 produce＝SelfGrade（中→日回想），Typing 只用於 conjugate 與 kana_word。背面補呼叫 vocab_detail。
 * C03 裁決：session_next、kana_session、drill_session 加參數 audio_available。false 時排除需語音的 facet 與題目，且不計入到期數與積壓判定。不做 Skip，不寫 FSRS。
 * C04 裁決：第一次接觸在 NewContent 內完成，卡片當場離開 state=0。條件 3 只計 created 邏輯日早於今天的 state=0 卡。任務順序為複習到期、新內容、演練、聽力，尾端自動插入 Learning 收尾，不佔 key。
 * C05 裁決：DailyTask::Review 與 TaskDto::Review 都加 key:"review"。done 為 due==0 且 learning==0，或已 complete_task。
 * C06 裁決：O6 改為 create_plan、today_view，進 T2 的第一個 NewContent，仍不經首頁但走任務模型。kana_session(lesson_id) 僅供 K1 自由練習，不影響計畫。
 * C07 裁決：K 切片的 complete_task 只寫 item_intro。熟練時建 :read 卡；當日結案仍未熟練者由 complete_task 補建 state=0 卡，kana_mastery 只影響徽章與重練。K 課完成＝全部字已 item_intro 且規則卡讀過。K10、K16–K19 為整課一個 KanaRule 切片，算一天。
 * C08 裁決：kana_drill_submit 改為 kana_submit(reference, payload, duration_ms)，由 Rust 判定，僅 kana_read／listen／confuse 計入熟練。checkpoint_finish 改收 Vec<AnswerDto> 並回傳弱項 ID。Match 是唯一允許 Dart 判定的例外，須在文件註明。
 * C09 裁決：QuestionRefDto 增加 variant: Option<u32>（rows 或 lemmas 索引），submit_answer 與 grade_drill 以此判定。
 * C10 裁決：milestone.lesson 為唯一來源，刪除 lesson.checkpoint。檢定是該課完成後的附加任務，不是課型，不阻擋游標。新增 checkpoint_dismiss(milestone_id) 供「先略過」。K19、KK08 只抽假名與規則題；rust-core §8.5 的各半僅用於 L 課，並刪除對 curriculum 的錯誤引用。
 * C11 裁決：一律軟性。curriculum §11.1 表頭改為「建議門檻」，90% 只決定蓋章與是否建議複習。專區解鎖定案為 pos(item.lesson) < pos(游標)，即該課完成才開放。
 * C12 裁決：專區與主線平行（rust-core 為準）。節奏改為 10 分每 2 天 1 項、20 分每天 1 項、30 分每天 2 項、45 分每天 3 項，時間從當日 listen 額度扣。plan_preview 分別回傳主線與專區完成日，curriculum §11.4 依此重算。
 * C13 裁決：專區字加 zone_item 欄位指向 dz.* 或 so.*，專區項目加 vocab[]。rust-core 的 items_by_lesson.words 排除這些字，由專區任務介紹。topics[0] 為 drama、song 時 zone_item 必填。
 * C14 裁決：單字、文法加 lesson_order 整數（不可叫 seq，L01 禁用），切片依此排序。例句與聽力只取所有 vo.*、gr.* 都已 item_intro 者。干擾項刪除第 3、4 層，只用已 item_intro 的項目，不足時退回 SelfGrade。新增 lint：每個切片日至少一句可用例句。
 * C15 裁決：單字羅馬字規則為 vocab.kana 含空白走句子模式（こんにち は→wa），否則走單詞模式（は→ha）。typed_answer_matches 與 romanize_reading 同規則並加 mode 參數，保留 reuse J08。
 * C16 裁決：統一用 {ja:飯を食べる}，可加讀音 {ja:飯を食べる|めしをたべる} 供振假名。純假名也要包（Z02 維持），MixedText 取消自動判定，「漢字緊鄰假名」改為輔助 lint，並重寫 curriculum 所有範例。
 * C17 裁決：保留 flutter-app 的打包方案，Noto Serif TC 改依 lib 實際用字子集以減少體積。reuse §1、§5.4、§10 修訂並補 Noto 授權。Klee 字元集定案為常用漢字聯集內容用字，由 make_charset.py 產生。
 * C18 裁決：rust-core §9.5 全數補上 OptionDto.sentence、blank_word_index、theme_mode、autoplay，另加 voice_id、learning_goals。P0 將 particle_fill 的 blanks 長度限制為 1，由 lint 檢查。
 * C19 裁決：turns 與 substitution rows 增加 tts，R16 擴及所有 t。單字加 tts，預設 kana，音調最小對立約 40 筆為 auto。WordDto 加 speech_kana（は→わ）。PromptDto、OptionDto 的 tts_text 改為 SpeechDto{text, kana}。@name 句一律 kana。
 * C20 裁決：KanaDef 加 tts_text 與 listen_disabled。Android／iOS 全表試聽列為第一個里程碑，不佳的字改用 tts_text；仍不佳者不出 kana_listen，改出 kana_read。VOICEVOX 維持 reuse §8.2 的 P1 評估。
 * C21 裁決：se.dz_* 增加必填 full_t（完整形句，同 t 語法），SentenceDto 帶 full。contraction_decode.choices 改為 t 陣列，納入 R02、R04、R12、R16。
 * C22 裁決：curriculum 補齊 kana_word、ka.rule、kana/sound_groups.json、no.rd、no.tr 的 JSON，代碼表加 mpr、kwd。dialogue.quiz 定為 drill ID 陣列。短劇改為 di.scene_*，沿用 DialogueDef 與 S4，S5 提供入口。rust-core 改列明確對應表，刪除「一一對應」的說法。
 * C23 裁決：curriculum §12.6 加 kana_days_per_lesson，zone_items_every_days 改為整數 zone_items_per_day 配 zone_every_days。rust-core §5.3 的 CHECK 改為 IN (10,20,30,45)。
 * C24 裁決：MilestoneRail 依 PlanViewDto.milestones 動態繪製。curriculum §1.3、P2 分列「本版到 L30」與「完整版到 L48」，forecast 只算已發布內容。
 * C25 裁決：D2 空狀態改為「這課目前沒有題目」。斷點續做僅保證 FSRS 與假名熟練；D2、K2、S4 離開後以同 seed 重做。「讀過」改由 item_intro 與 use 卡狀態推導，刪除蓋章狀態。V2 改為 only_introduced 開關加課次標示，刪除 ?source=。
 * C26 裁決：新增 zones/missions.json 與 TaskDto::Mission{key, mission_id, done}，L21 後每 7 天出現一次，內容含看劇與聽歌任務，手動打勾。
 * C27 裁決：display_policy 加參數 DisplayContext{lesson_id, zone: bool}，以該內容所屬課計算。K1 參考表永遠顯示羅馬字。
 * C28 裁決：question_type 改為無欄位 Rust enum，含 recog、vocab_listen、produce 與全部 kana、drill 題型，由 FRB 產生 Dart enum，optionLanguageOf 依此窮舉。
 * C29 裁決：review_cap 依題型加權，自動判定卡 8 秒、use 卡 25 秒。Integration 用 new＋drill＋listen 額度；10 分方案分兩天做一二、三四階段。專區時間從 listen 扣。
 * C30 裁決：jlpt 依基準清單標，不在清單者標 beyond。§4.2 欄名改為「S1–S2」「S3」「專區」，總量 1,600 不變，C01、C02 分母維持實測清單。
 * C31 裁決：ぢ、づ 的 ID slug 用 di、du（ka.hira.di、ka.kata.du），R01 檢查唯一性，st.* 加入前綴表。
 * C32 裁決：採 curriculum。vs 單字的 surface 為 勉強、kana 為 べんきょう，活用由獨立 する 承擔。conjugate 引擎對 vs 以 surface＋する 計算，legal_stems 回傳空，並修改 rust-core §4.7 測試。
 * C33 裁決：dz.se_kana 移至 L22，so.cl_n 移至 L32，dz.ck_doushiyou 登錄為 pos: phrase 語塊維持 L21。
 * C34 裁決：P0 新增 N1「漢字陷阱」畫面（/learn/notes）與 note_list(kind)，從 L1 進入。
 * C35 裁決：VocabDetailDto 補 use_level、jlpt、reading_family、pair、trans。V4 背面顯示同形異義與字形徽章及「聽懂就好」提示。WordDto 加 gloss_zh 支援 @new。K1 詳情條顯示 origin_kanji。
 * C36 裁決：curriculum 改為錄音回放屬 P1。audio_first 定案為先聽後顯示詞塊，修改 §10.2 文字。shadowing 不進 FSRS，三級自評只存練習統計。
 * C37 裁決：刪除 rust-core §9.6；rust-core 規則改名 RC1–RC9；reuse J04 比照 rust-core，禁疊字符與 ヷ 系；標點表加 U+301C；rust/Cargo.toml 加 [workspace]，content_tool 放 rust/tools/；R15 改用 content/lint 內的簡體字表，不依賴 OpenCC；Vec、bool 加 #[serde(default)]；reset_all 改為關閉連線、刪檔重建；估算修正為 4,816／6,932；V4 鍵名統一為「簡單」。
 * G01 解法：K2 每字先呈現大字、播音、origin_kanji 與 hint_zh，再進測驗。K16–K19 新增規則卡畫面與拍感示範。
 * G02 解法：search_vocab 支援羅馬字（轉假名）、假名、漢字、中文。P0 加已會／收藏標記，沿用 suspended 並加 starred。
 * G03 解法：grammar_list 加 query。pattern、formation 的日文改用 {ja:} 標記。新增術語卡，首次出現 ます幹、て形時彈一次。
 * G04 解法：substitution 定案為中文提示加同 slot 其他列作選項，列數至少 3，否則用 Reorder。register_convert 定案為 Reorder。QuestionDto 加 focus_ids，答後顯示文法重點。
 * G05 解法：Android／iOS 實機驗證排在內容量產之前。音調示範標註「由裝置合成，僅供參考」，無法通過人耳驗收的對立組不收入。
 * G06 解法：P0 加本機每日提醒，不需網路。新增「再學一批」動作，於今日任務完成後產生下一切片。
 * G07 解法：實戰與常體版對話納入 Integration 輪替，每完成 3 課排 1 篇。錄音回放提前到 P0 後第一個版本，先解決 Linux 相依。
 * G08 解法：短劇納入 Zone 排程。專區加 1.2 倍速。韻律型項目允許只有說明加外部任務，R09 增加 no_tts_quiz 例外。
 * G09 解法：so.sn_* 改為說明加聽歌任務，不強制 TTS 題目。use 卡候選少於 3 題時，由例句自動補 listen_meaning。
 * G10 解法：新增「預告語塊」，L03、L07、L14 各開放 10–15 個 recognize_only 的 pos: phrase，含 大丈夫、ちょっと待って 與歌詞意象詞，只需聽懂。O2 目標決定優先出現的專區類別，主線順序不變。
 * G11 解法：匯出備份提前到 P0，使用 rust-core 已實測的 VACUUM INTO，透過系統分享匯出。
 * G12 解法：增加 CONTENT_STAGE=p0a，範圍為 S0、L01–L07、ms.hira 與 ms.survive、預告語塊，先端到端打通全部題型與語音，再量產。
 * B01 解法：同 G01，且第一批只教 3 字，第一題保證可答。
 * B02 解法：O5 失敗時停在引導，明確選「現在設定」或「先用無聲模式」。無聲模式顯示常駐說明並停用聽力題，文案依實機路徑寫。
 * B03 解法：連續 2 次答對即熟練，時限僅供徽章參考不歸零。kana_listen 從播放結束起算，並提供無障礙設定關閉時限。
 * B04 解法：平假名清音 46 字壓到 20 分方案約 10 天，改用每日固定字數上限取代每課天數，並在 K05、K10 穿插音訊為主的問候語塊。拗音按規律批次教，不按字數計天。
 * B05 解法：L01–L04 預設顯示，L05–L08 預設隱藏且可點顯示。L09 起的關閉綁定 ms.kata 通過或使用者確認。TextField 指定 Latin 鍵盤類型並關閉自動校正。
 * B06 解法：與中文同形的單字，recog 改為只顯示假名或先播音再選意思，listen 提升為 priority 0。
 * B07 解法：L21 依類別分週釋出，先開縮約形與高頻語塊。每種題型第一次出現顯示一次操作提示。FSRS 按鈕隱藏間隔數字，提供設定開啟。
 * B08 解法：S0 的 budget 只給新內容與複習，演練、聽力額度併入假名練習，rust-core §7.2 比例表改寫。
 * B09 解法：O6 的誠實預期移到第一次學習完成後顯示。O3「會一點假名」對應 Zero，但可略過已會的行。
 * B10 解法：複習優先最多連續 2 天，第 3 天起給最小新內容切片。回鍋首日額外限制 review_cap，避免一次面對全部積壓。
 * B11 解法：同 C29，並在 T1 顯示依題型估算的實際分鐘數。
 * B12 解法：tts_risky 只收確定會誤讀者，並列入實機抽聽清單。kana 模式送出前的空白處理以實機試聽定案。

