# 工作狀態

最後更新：2026-11-25。範圍定義見 `docs/PRD.md`。預設建置的內容階段是 `p0`。

2026-11-15 依 `docs/design/RULINGS.md` O13 移除了日劇與日文歌專區及周邊功能（見「第四輪：移除專區」）。「第二輪修正」「第三輪修正」「文件同步」「審查修正」四段是當時的紀錄，原文保留，提到專區、短劇、看劇聽歌任務、預告語塊的項目另外標「後於 O13 移除」。

## 已完成

**教材與首次學習畫面優化（2026-11-25）**

- 首次文法學習卡顯示完整接續表，與文法詳情頁共用；窄版上下排列。真實て形教材的回歸涵蓋 320px、1.5 倍字級與下一步／考一題。
- 參考詞表未收錄的單字顯示「未列入參考詞表」，不再暗示高於 N4；非正式用語標籤與 O7 守門同步。
- L10、L21 題幹明確指定過去式、常體，解析不再把其他合理說法當成普遍錯誤。修正たり、形容詞連接、程度副詞與語用說明中的絕對敘述。
- 促音說明區分閉鎖與摩擦音延長，補上いっしょ三拍示例；長音說明補上思う例外。33 則未連結單字卡的同形異義筆記補上振假名。
- 保険証的釋義與例句區分日本保險證件與台灣健保卡，補充現行マイナ保険証／資格確認書。制度依據：[厚生勞動省的資格確認方法](https://www.mhlw.go.jp/stf/newpage_50657.html)（2026-11-25 查核）。
- 驗證：相關 Flutter 功能測試 220 個、O7 純文案守門 36 個通過；`jp_content`、`jp_quiz` 測試通過；`p0`／`p0a` lint 均為 0 錯誤、0 警告；`p0 verify --strict --only J01b,J04,J08,J09,F01,F02,F03,F04,F05,C03,C05,Z01,Z02,L01,L02,L04` 的 16 條不需外部資料規則全過，包含打包字型與標記檢查。其餘需外部辭典資料的規則本次未重跑。
- Android／iOS 的語音實聽仍待實機驗收；新增的促音例字已列入 `TTS_DEVICE_CHECKLIST.md`，未將空白結果當作通過。

**Rust 核心**

- 假名與羅馬字、動詞變化、內容載入與 lint、SQLite、FSRS、學習計畫、測驗與演練，以及 FRB 介面（`rust-core.md` §9）。
- 全部題型的判定都在 Rust（配對題依裁決由 Dart 判定）。
- K11–K15 的切片在假名題後接 `minimal_pair`、`kana_word`，S0 主流程練得到清濁、半濁、拗音（loop.F2，`rust-core.md` §9.4）。
- `use` 卡只剩標題時保留 `{ja:}` 標記，中文夾假名的標題能正確分段。

**預設內容切換為 `p0`**

- `rust/crates/jp_content/build.rs` 與 `rust/crates/jp_content/src/disk.rs` 的 `DEFAULT_STAGE` 都改為 `p0`，`disk.rs` 的單元測試確認兩者一致。未設 `CONTENT_STAGE` 時，App 嵌入、`content_tool` 與 `content_lint` 都走 `p0`。
- `p0a` 仍可用 `CONTENT_STAGE=p0a` 建置。四個 `p0a` 真實內容測試（`curriculum_days_real_content.rs` 等）在測試內固定 `ContentStage::P0a`，不受預設影響。

**`p0` 內容**

- L08–L30 主線（單字、文法、例句、演練、主對話）、里程碑 `ms.a1_half`、`ms.casual`、`ms.n5`。
- 實戰對話 6 篇、常體版對話 12 篇。
- 筆記 232 則：同形異義 60、字形對照 120、讀音規律 20、語言轉移 20、術語 12。讀音規律的台語讀音依 RULINGS O10 寫台羅數字調，內容檔中沒有 U+030D、U+0358。
- 全部類別達到 `curriculum.md` §14 的 `p0` 目標，數量見下方驗證結果的 `stats`。

**`p0a` 內容**

- S0 全部假名與規則卡、L01–L07 主線、三個里程碑、四種計畫。
- 主線例句 431 句，高於規格的 266 句。

**Flutter App**

- 新手引導、今日連續流程、課程、五十音（表、練習、規則卡）、單字（主題、列表、詳情、字卡）、文法、演練與檢定、語音示範、對話四階段、計畫、設定與授權頁。
- 筆記（N1）畫面。預設 `p0` 露出入口並載入真實內容；`p0a` 沒有筆記內容，入口不露出。
- 範圍文案（O7）依 `content_stage` 切換，`p0` 寫「本版到 L30」、「涵蓋參考 N5 範圍」。
- 語音：Android／iOS 走 flutter_tts，Linux 走 spd-say，無語音時的引導與無聲模式。

**驗證與工具**

- 內容 lint、`content_tool verify`、離線保證檢查、Rust 授權清單。
- 字型子集：`assets/fonts/*.subset.ttf` 保留 2026-11-10 的成品。2026-11-25 教材優化後已重產 `tools/fonts/charset_*.txt`；`content_tool --stage p0 charset` 輸出 846 個日文字與 1,627 個中文字。既有子集仍涵蓋本次用字，F01–F05 全過，因此沒有重建二進位字型。
- Rust 的 `p0` 真實內容回歸測試三個檔、21 個測試（`real_content_p0.rs`、`real_content_p0_slices.rs`、`real_content_p0_drills.rs`，見 `rust-core.md` §11.2）。
- 整合測試七個檔、15 個測試：J1／J2／J6（4）、J3（1）、J4（375、320、320＋2 倍字級、1280 共 4，含 N1 筆記五個分頁）、J5（2）、J7（1）、J9（2，L21 之後的常體對話、L22）、boot（1）。每一站檢查 `p0` 文案不宣稱 N4、不出現 L31 以後的課與「完整版」。移除專區後檔數與測試數不變（J4、J9 的專區部分已依 O13 拿掉，J9 留下 L22 教學卡、常體對話、L1 進度條、L22 的單字與文法頁）。
- `docs/TTS_DEVICE_CHECKLIST.md`：A–G 區（假名、配對、L01–L03 例句）與 E 區的 `p0` 音調單字，加上 H 區的 `p0` 代表性項目（L08 以後的例句）。結果欄都是空的，要實機填。
- 學習迴路長模擬：`p0_learning_loop.rs`（主模擬，15 個長測試）與 `p0_learning_loop_edges.rs`（無聲、休息日、回鍋、休息日回鍋，7 個）在 release 都通過，量測見 RULINGS O13。

**第二輪修正（2026-11-10，正式程式碼的修改都先寫會失敗的測試）**

每項後面的「驗證」是固定這個行為的測試；執行結果見下方「目前的驗證狀態」。測試弱點的補強另做過「故意改壞」：在工作區副本改正式程式碼，確認新斷言會失敗、舊斷言不會。

- 計畫引擎（RULINGS O11）：積壓暫停專區、只排複習的日子、`review_cap` 先扣收尾新卡、S0 60／40、10 分方案 2／6／1／1。學習迴路模擬原本的 F1–F3 三個 `finding_` 測試改為一般長模擬並通過。驗證：`jp_plan/tests/budget.rs`、`compose_backlog.rs`、`flow_day.rs`、`flow_recovery.rs`，`rust/tests/p0_learning_loop.rs`（release 長模擬 19 個），`test/features/today/today_copy_test.dart`。（積壓暫停專區後於 O13 移除；長模擬現為 15 個）
- 收尾新卡的當日上限（`rust-core.md` §6.4、§7.2）：收尾一天至多用 review 秒數的一半（`tail_card_limit`），佇列第 3、4 步也以同一個數為上限。修正前長期無聲後打開聲音，收尾 297 張、`review_cap` 被扣到 1、T1 顯示 47 分（20 分方案）。驗證：`jp_store/tests/srs_queue.rs`、`jp_srs/tests/queue.rs`、`jp_plan/tests/budget.rs`、`flow_day.rs`，`p0_learning_loop_edges.rs` 的無聲學習者（拿掉上限時重現 47 分／cap 1）。
- `DayBudget`／`BudgetDto` 加上 `capacity`（積壓判定用的容量），FRB 繫結已重新產生。學習迴路模擬加上暫停線、只排複習日的 `review_cap`、`review_cap` 不塌成 1、休息日只列 `Review` 四條不變量；`p0_learning_loop.rs` 的執行與報表移到 `tests/common/loop_run.rs`。驗證：`compose_backlog.rs` 的 `capacity` 模組、`rust/tests/plan_flow.rs`（`BudgetDto.capacity`）、`test/ffi/core_ffi_test.dart`（新的 `.so`）；暫停線改成 5 倍時 `BacklogPauseLine` 失敗 403 筆。
- 新增 `rust/tests/p0_learning_loop_edges.rs`：前 300 天無聲之後有聲、週一到週五的計畫週末也打開 App、每 6 週消失 8 天三位學習者（release 約一分鐘，5 個測試）。
- 振假名（`rust-core.md` §4.6）：接在 ASCII 英數字後的 `.`、`,` 歸漢字類（3.5、1,000、Mr.）；標點異體（〜～~、？?）互通；lint R19 對讀音與底字 0 解的 `{ja:S|K}` 報錯。驗證：`jp_lang/tests/kana_furigana.rs`、`jp_content/tests/content_lint_rules.rs` 的 `r19_rejects_markup_whose_reading_does_not_align`，真實內容 R19 0 個錯誤。
- Rust 測試補強：`real_content_p0_zones.rs` 的 no_tts 對照組、`real_content_p0_slices.rs` 的 forecast 與輪替序列、`answerable.rs` 的判分 API 比對與空格位置（挖掉的必須是正解那個詞）、`real_content_p0.rs` 的 API 計數。四個檔共 30 個測試。（`real_content_p0_zones.rs` 後於 O13 移除，現為三個檔 21 個測試）
- Flutter：振假名可懸在相鄰的假名、標點上（`RubyBox`）；`unknownOnly` 時不懸到已知詞的漢字上；MixedText 併進盒子的收尾標點會被報讀一次；S5 專區清單已開放的排前；S5 橋樑提示窄寬時「知道了」放到文字下方靠右；Linux 優先載入 bundle 內的函式庫；T1 的任務與檢定副標用 MixedText（不再露出 `{ja:}`）；積壓日文案不說「只複習」；O4 粗估文案改用 `scope_copy`；文字 golden 樣張撐滿寬度，375／768／1024 三張不再相同。驗證：`test/core/text/ruby_fit_test.dart`、`ruby_neighbor_test.dart`、`mixed_text_overhang_test.dart`、`ruby_line_overhang_test.dart`、`text_golden_test.dart`，`test/features/zones/zone_labels_test.dart`、`zone_list_screen_test.dart`，`test/design/question_hint_strip_test.dart`，`test/core/backend/native_library_test.dart`，`test/features/today/today_screen_test.dart`、`today_copy_test.dart`，`test/features/plan/scope_copy_test.dart`、`test/features/onboarding/plan_estimate_copy_test.dart`。（S5 與 `test/features/zones/` 後於 O13 移除）
- 內容：`verify --strict` 的 18 個警告逐一查證後登錄覆寫（`rust/content/lint/verify_allow.toml`），26 句例句改寫補上 3 課內的複習（lint R10 由 44 降為 15）；se.l04.018 的中文改為直譯。驗證：`content_tool --stage p0`、`--stage p0a` 的 `verify --strict` 結束碼 0，`--stage p0 stats` 與改寫前相同（沒有增刪項目）。
- 整合測試：O7 文案守門抽成純文字規則並補單元測試（`integration_test/support/p0_copy_rules*.dart`），旅程每站另斷言畫面沒有原樣的 `{ja:` 標記；J9 補 Mission 卡、S6 作答以 API 取題、專區排序與提示版面；J1／J2／J6 各自建資料、可單獨執行。驗證：`integration_test/run_all.sh` 七個檔 15 個測試全過，`p0_copy_rules_test.dart` 27 個通過。（J9 的 Mission 卡、S6 作答、專區排序與提示版面後於 O13 移除）

**第三輪修正（2026-11-11，依負責人裁決，逐條記在 `RULINGS.md` O12）**

下表的項目都已完成。正式程式碼的修改都先寫會失敗的測試，或以「故意改壞、確認測試失敗、再還原」確認測試抓得到（中斷前已改好的項目用後者）。「接受」與「延後」的項目（P4–P8、P11–P13、C3、U3、U13、U15）沒有改程式，理由見 O12；延後的在下方 P1。執行結果見「目前的驗證狀態」。

| 項目 | 狀態 | 驗證出處 |
|---|---|---|
| P1 回鍋日的積壓依到期數判定 | 完成（暫停專區的部分後於 O13 移除，`zone_pauses_*`、`zone_pause_*` 兩個測試改名為 `backlog_flag_*`） | `jp_plan/tests/budget.rs` 的 `zone_pauses_on_the_due_count_not_the_reason`、`return_after_break_with_backlog_only_reviews_and_keeps_the_half_cap`、`zone_pause_compares_the_due_count_against_the_capacity_not_the_cap`；`compose_backlog.rs` 的 `return_day_with_backlog_only_reviews_with_half_the_merged_cap`；`p0_learning_loop_edges.rs` 的 `return_days_with_backlog_only_review` |
| P2 休息日不遞增、不併入 | 完成 | `jp_plan/tests/budget.rs` 的 `rest_day_keeps_the_previous_recovery_days`、`rest_day_backlog_does_not_merge_into_review`；`compose_backlog.rs` 的 `rest_day_backlog_keeps_the_stage_split_and_cap`；邊界模擬的 `RestDayReviewOnly` |
| P3 `BACKLOG_PAUSE_FACTOR = 5` | 完成（含專區時量的；移除後 5 倍的量測見 O13，長模擬測試改名為 `review_backlog_days_only_review_and_respect_the_pause_line`） | 量測表在 O12，3、4、5 倍都實跑，審查另量 6 倍；`jp_plan/tests/budget.rs` 的 `backlog_lines_compare_against_the_capacity_before_the_tail`、`backlog_up_to_the_pause_line_keeps_minimal_from_day_three`；`p0_learning_loop.rs` 的 `review_backlog_days_pause_the_zone_and_only_review`（常數改 4 或 6 都失敗） |
| P9 R10 只算主線課 | 完成 | `jp_content/tests/content_lint.rs` 的 `r10_window_counts_only_main_line_lessons`、`r10_skips_last_main_line_lesson_even_when_kana_lessons_follow`、`r10_reuse_in_kana_lesson_does_not_count`、`r10_reuse_on_the_third_main_line_lesson_counts`、`r10_ignores_retired_vocab` |
| P10 K1 與檢定算活躍日 | 完成 | `rust/tests/activity_accounting.rs` 的 `free_kana_practice_counts_as_an_active_day_without_advancing_the_plan`、`a_day_with_only_a_checkpoint_counts_as_active`；`jp_store/tests/activity_settings.rs` 的 `a_checkpoint_result_counts_its_answers_for_the_day` |
| C1 整句標記拆成逐詞 | 完成 | `jp_content/tests/content_lint_rules.rs` 的 `r19_warns_markup_whose_reading_has_several_alignments`、`r19_split_markup_has_single_alignment`；`content_lint.rs` 的 `real_content_has_no_r10_or_r19_findings` |
| C2 剩餘 R10 | 完成 | `content_lint.rs` 的 `r10_allow_list_with_reason_suppresses_warning`、`r10_allow_entry_needs_reason`、`r10_allow_entry_without_reason_keeps_warning`、`r10_allow_entry_for_repeated_word_is_stale`、`real_content_has_no_r10_or_r19_findings`；`content_tool --stage p0 lint` 0 警告 |
| U1 振假名餘量 1:2:1、兩階段行首行尾 | 完成（J9 的 `expectRowHeadsWithoutGaps` 與專區畫面的截圖後於 O13 移除） | `test/core/text/ruby_spacing_test.dart`、`ruby_fit_test.dart`、`mixed_text_overhang_test.dart`；J9 的 `expectRowHeadsWithoutGaps`；`zone_drama_list`、`zone_songs_list` 截圖 |
| U2 行首行尾禁則 | 完成（J9 的三個版面檢查在專區畫面上，後於 O13 移除） | `test/core/text/ruby_kinsoku_test.dart`、`ruby_kinsoku_cuts_test.dart`、`ruby_affix_test.dart`；J9 的 `expectKinsokuIn`、`expectJoinedAfter`、`expectOpenBracketJoinsRuby`；真實內容掃描（`RubyLine` 2,626 句、`MixedText` 3,830 字串，各 15 種寬度字級）禁則違規 0 |
| U4 S6 說明句 | 完成（S6 後於 O13 移除） | `test/features/zones/zone_item_view_test.dart`；J9；`zone_drama_pending_note` 截圖 |
| U5 T1 沒有事可做時不列複習 | 完成 | `test/features/today/today_copy_test.dart`、`today_row_stamp_test.dart`；J2、J3 的 `expectReviewRow` |
| U6 T3「不到 1 分鐘」 | 完成 | `today_copy_test.dart`、`today_flow_view_test.dart`；J1 |
| U7 L1 略過的格子 | 完成 | `test/features/learn/learn_home_screen_test.dart`（兩種主題、高對比）；`learn_progress_light`、`learn_progress_dark` 截圖 |
| U8「略過這一項」 | 完成（`ZoneRunner` 與任務卡後於 O13 移除） | `test/design/widgets_test.dart`、`test/features/zones/zone_runner_test.dart`、`test/features/new_content/new_content_view_test.dart`、`test/features/listen/listen_session_view_test.dart`、`test/features/today/today_flow_tasks_test.dart`；旅程每站的 `retiredSkipTexts` |
| U9 返回元件統一 | 完成（`back_navigation_test.dart` 的 S5、S6 兩案與 J9 在 S6 的 `expectBackLine` 後於 O13 移除，整合測試現在只有 J4 呼叫） | `test/design/back_line_test.dart`、`test/app/back_navigation_test.dart`；J4、J9 的 `expectBackLine` |
| U10 O6 防連點 | 完成 | `test/features/session_leave_test.dart` 的「連點「知道了，繼續」只離開一次」「離開途中「關於程度」不能按」 |
| U11 假名課課名 | 完成 | `test/core/backend/course_groups_test.dart`；J1；旅程每站的 `rawLessonIdTexts` |
| U12 S3 未到對話可點 | 完成 | `test/features/dialogue/dialogues_screen_test.dart`、`test/features/learn/lesson_detail_screen_test.dart`；J4 |
| U14 K3 的「。」（只驗證） | 確認已解決，沒有改程式 | `test/core/text/k3_punctuation_test.dart`、golden `test/goldens/k3_rule_card_320.png` |
| 審查 RC1、RC3 回鍋判定改看 `plan_active_dates`，回鍋要有卡可碰 | 完成 | `rust/tests/return_after_break.rs`；`jp_plan/tests/budget.rs` 的 `nothing_to_review_is_not_a_return_after_break`；`flow_recovery.rs` 的 `nothing_to_review_after_a_break_still_offers_new_content` |
| 審查 RC2 `verify` F04 恢復 0 錯誤 | 完成 | `ruby_kinsoku.dart` 的表用 `\uXXXX` 寫內容用不到的字；`content_tool/tests/verify_cli.rs` 的 `documented_fixture_verify_passes_with_the_bundled_fonts_and_lib` 納入 F04 |
| 審查 RC4、RC6 回鍋落在休息日 | 完成，待確認 | `jp_plan/tests/budget.rs` 的 `rest_day_return_after_break_restarts_recovery_days`、`rest_day_return_after_break_still_halves_the_cap`；`flow_recovery.rs` 的 `return_on_a_rest_day_does_not_skip_the_first_two_days`；邊界模擬「週一到週五＋每 40 天缺席」的學習者 |
| 審查 RC11 `gr.kai_freq` 跨詞的 ruby 拆開 | 完成 | `content_tool --stage p0 lint`、`verify --strict` 0 警告 |
| 審查 RC5 休息日空清單不顯示受限文案 | 完成 | `test/features/today/today_screen_test.dart` |
| 審查 F1、F3 字級放大時 `って` 不落行首、`MixedText` 段首與空白 | 完成，F3 待確認 | `test/core/text/ruby_kinsoku_test.dart`、`ruby_kinsoku_cuts_test.dart`；真實內容掃描同 U2 |
| 審查 F2、F-A T1 只剩收尾新卡不蓋章 | 完成，待確認 | `today_row_stamp_test.dart` 的「只剩收尾新卡時不蓋完成章」；J3 |
| 審查 F4、F6、F-B 斜線對比、未到對話的報讀、S6 相同形不畫箭頭 | 完成（S6 的部分後於 O13 移除） | `learn_home_screen_test.dart`；`dialogues_screen_test.dart` 的「未到的對話，報讀念出「還沒學到」」；`zone_item_view_test.dart` |

**第四輪：移除專區（2026-11-15，依負責人裁決，記在 `RULINGS.md` O13）**

移除日劇聽解專區、日文歌專區、短劇、看劇聽歌任務、預告語塊、`contraction_decode` 題型、專區排程與進度、學習目標設定，以及 Flutter 的專區畫面與 1.2 倍語速。範圍、已定案的決定、失效的既有裁決與移除後的量測都在 O13。只移除，沒有加新功能；保留行為的測試沒有刪除或放寬，只刪只驗被移除功能的測試。專案沒有版本控制，移除前的完整備份是專案目錄上一層的 `backup-before-zone-removal-2026-11-15.tar.gz`。

| 範圍 | 狀態 | 驗證出處 |
|---|---|---|
| 內容（`rust/content/`） | 完成 | 刪 39 個內容檔共 1,421 筆與 `dr.l14.ffr.002`，`no.ff.yakusoku` 改為不綁單字；`content_tool --stage p0`、`--stage p0a` 的 lint、`verify --strict` 都是 0 錯誤 0 警告，`stats` 全部達標 |
| Rust 核心與 FRB 綁定 | 完成 | `cargo fmt --all -- --check`、`cargo clippy --workspace --all-targets -- -D warnings` 通過；`cargo test --workspace --no-fail-fast` 1,257 通過、0 失敗、23 略過；長模擬 15＋7 個全過，量測在 O13；`flutter_rust_bridge_codegen generate` 重跑後產生檔不變 |
| Flutter `lib/` 與 `test/support/` | 完成 | `flutter analyze --no-pub lib test/support` 0 個問題；`dart format --output=none --set-exit-if-changed lib test/support` 267 個檔案 0 個有變動 |
| Flutter 測試（`test/`、`integration_test/`） | 完成 | 2026-11-16：`flutter analyze --no-pub` 0 個問題；`dart format --output=none --set-exit-if-changed lib test integration_test` 397 個檔案 0 個有變動；`flutter test --no-pub` 1,430 通過（移除前 1,540，刪 115、增 5，逐案比對吻合）；golden 12 張與移除前逐位元組相同；整合測試七個檔 15 個測試全過。刪除 `test/features/zones/` 與 `integration_test/support/` 的 `zone_steps.dart`、`ruby_layout*.dart`（三個檔） |
| 文件 | 完成 | `curriculum-zones.md` 已刪除；`curriculum.md`、`reuse-and-verification.md`、`RULINGS.md`、`rust-core.md`、`flutter-app*.md`、`docs/PRD.md`、`README.md`、`docs/TTS_DEVICE_CHECKLIST.md`、`integration_test/README.md` 與本檔已同步。`cargo test -p jp_content --test content_schema`（解析 `curriculum.md` §12.4–12.6 的範例）6 通過 |

**文件同步（2026-11-10，第二輪修正之後）**

- `docs/TTS_DEVICE_CHECKLIST.md` 補上 `p0` 的 H–K 區：L08 以後的主線例句 22 句（強制送假名 8 句、送漢字原文的日期數字與多音字 14 句）、日劇專區 8 項（縮約形 4 項）、歌曲專區 6 項、韻律型（`no_tts_quiz`）6 項、8 篇短劇各一句。ID 都以腳本比對過 `rust/content/`，送出文字照 `analyze_t` 的規則算出。（I–K 區後於 O13 移除，只留 H 區）
- `rust-core.md` §1.2、§1.3 改為實際的 workspace 與 `rust/crates/*` 結構；`reuse-and-verification.md` §9.2、§9.4、§9.11 註明 T01、T02 與 `tts-checklist` 未實作。

**審查修正（2026-11-10，每項都先寫會失敗的測試）**

- 振假名對齊（`rust-core.md` §4.6）：§4.2 標點表的字元（`？`、`、`、`〜` 等）改當錨點，不再放進振假名。修正前 `{ja:大丈夫？|だいじょうぶ？}` 的 `？`、`{ja:〜と思います|〜とおもいます}` 的 `〜` 會出現在振假名上。測試：`jp_lang/tests/kana_furigana.rs`、`jp_content/tests/mixed.rs`。內容中 200 處含標點的 `{ja:…|…}`，讀音裡的標點都與基字一致；`--stage p0`、`p0a` 的 lint 結果不變。
- `plan_view.zone_forecast_end`（§7.5）：專區全部發完以後停在最後一項的 `item_intro.logical_date`，不再每天跟著今天移動。新增 `PlanRepo::introduced_dates` 與 `CursorState.introduced_on`。測試：`jp_store/tests/progress_repo.rs`、`jp_plan/tests/forecast.rs`、`rust/tests/zones_fixture.rs`；`p0_learning_loop.rs` 原本的 `finding_zone_forecast_settles_on_the_actual_completion_date` 改為一般長模擬 `zone_forecast_settles_on_the_actual_completion_date`，release 實測通過。（`zone_forecast_end` 與這些專區測試後於 O13 移除）
- O4 粗估（`plan_estimate_copy.dart`）：`p0a` 就算後端回傳專區日期也不列專區行，與 P1 的 `scope_copy.zoneForecastLine` 一致（O7）。（專區行後於 O13 移除）
- `test/ffi/core_ffi_test.dart` 改斷言預設 `p0`（三個入口露出、課程到 L30），`rust/target/release/libjp_core.so` 已用預設 `p0` 重建。（專區的兩個入口後於 O13 移除）
- 夾具 `verify`：`reuse-and-verification.md` §5.4、§9.8、§9.11 的路徑改為 `rust/crates/jp_content/tests/fixtures/full`；夾具新增 `lint/verify_allow.toml`，登錄 `lib/` 圖示字 暦、済、聴 的覆寫（與 `rust/content/` 相同）。由 `verify_cli.rs` 的 `documented_fixture_verify_passes_with_the_bundled_fonts_and_lib` 固定。

## 進行中

下列項目在進行中或在等外部條件：

| 項目 | 現況 |
|---|---|
| TTS 實機檢查 | 需要實機與人耳，清單已備妥（含 `p0` 的 H 區），結果欄都是空的 |
| 人工審閱 | 日語母語者、台語讀音，見待辦。機器檢查不到自然度、語意與原創性（`reuse-and-verification.md` §9.10） |
| 待負責人確認的事項 | 見下方 |

## 待辦

### Android／iOS 建置與實機驗證（上架前必要）

- [x] 2026-11-23 以 Android SDK 35／36、NDK 28.2.13676358 建置通用 release APK；
  Cargokit 以 Rust 1.99.1 交叉編譯 armv7、arm64、x86_64，APK 79 MiB，v2 簽章驗證通過。
- [x] `python3 tools/verify/check_offline.py --apk build/app/outputs/flutter-apk/app-release.apk --require-apk`：
  2026-11-23 L03、L05–L08 全部通過，release APK 不含 `INTERNET`。
- [ ] iOS 建置與簽章，需要 macOS。
- [ ] 把 `com.example.*` 換成正式的 application id／bundle id（`android:label` 已改為「日文學習」）。
- [ ] 依 `docs/TTS_DEVICE_CHECKLIST.md` 實機檢查，結果回寫內容。檢查時一併決定裁決 U15 留下的兩項：`ん` 的 `tts_text`（`verify` J04 不允許換成以 ん 開頭的其他文字，實機若念不好只能設 `listen_disabled`，或先調整 J04）、音調入門規則卡的例字（沒有 `listen_disabled` 欄位，語音示範關掉配對後規則卡仍會播）。
- [ ] `flutter-app.md` §9 其他待實機項目：注音輸入法下打字題的鍵盤、Klee 小字清晰度。
- [ ] 手機上的內容載入時間（`AppCore::open`）。只在 x86 桌機量過合成資料，真實 `p0` 內容沒在手機量過。
- [ ] 上架前決定 Rust 套件授權是否要附全文。`assets/licenses/rust_crates.txt` 目前只有名稱、版本與 SPDX；MIT、Apache 通常要求附上著作權聲明與授權全文。

### 人工審閱

- [ ] 日語母語者審閱 `p0a`：L01–L07 例句與 7 篇對話。
- [ ] 日語母語者審閱 `p0`：全部 S1 句子（`reuse-and-verification.md` §9.10）。
- [ ] 台語讀音母語者抽查：讀音規律筆記 20 則（`no.rd.*`）的 `examples[].tai`，依 RULINGS O10 以教育部《臺灣閩南語常用詞辭典》的文讀音為準。

### `p0` 收尾

- [x] `docs/TTS_DEVICE_CHECKLIST.md` 同步 `p0`：補上 H–K 區（L08 以後的例句、日劇與歌曲專區、韻律型、短劇，見上方「文件同步」）。優先項目、F、G 的 L01–L03 例句仍在 `p0` 內，保留。之後內容改動仍要手動同步（`tts-checklist` 未實作，見「工程項目」）。（I–K 區後於 O13 移除）
- [x] `test/ffi/core_ffi_test.dart` 改斷言預設 `p0`，release `.so` 已重建（見上方「審查修正」）。
- [x] `content_tool --stage p0 verify --strict` 結束碼 0：18 個警告逐一查證後登錄 `rust/content/lint/verify_allow.toml`（`p0a` 也是 0）。
- [x] 10 個整句 `{ja:S|K}` 標記已拆成逐詞，R19 多解 0（第三輪 C1）。
- [x] 夾具 `verify`：路徑已更正、夾具補上 `lib` 圖示字的覆寫，實測結束碼 0（見上方「審查修正」）。

### 工程項目

- [x] CI/CD：`.github/workflows/ci-cd.yml` 已接上 Rust／Flutter 覆蓋率、FRB 產生碼同步、
  Flutter／FFI／golden、內容驗證、APK 簽章與離線檢查，以及 main／tag 的 Linux release、長模擬與整合測試；
  `vMAJOR.MINOR.PATCH` tag 另要求受保護 Environment 的正式簽章後發布 GitHub Release。
- [ ] 截圖回歸矩陣：規格列了 T1、K1、K3 等多個畫面，目前 `test/goldens/` 只有設計樣張、文字元件與 K3 規則卡的文字（`k3_rule_card_320.png`）。
- [ ] `content_tool tts-checklist` 與 T01、T02 檢查（`reuse-and-verification.md` §9.13）未實作，TTS 清單目前手動同步。
- [ ] `cargo deny check licenses` 未導入（`reuse-and-verification.md` §10）。
- [x] `tools/fonts`、`tools/licenses` 的 Python 測試與 Rust 授權清單同步檢查已接進 CI。
- [ ] T2 前景跨換日的 `expected_logical_date`（需要 FRB codegen）。
- [ ] 例句、演練、計畫預設沒有列舉 API，`real_content_p0.rs` 的這三類仍讀載入後的 `ContentStore`（等同 lint R17），其餘類別已改走公開 API。
- [x] `rust/tests/common/loop_invariants.rs` 已拆出 `budget.rs` 子模組（580＋222 行）。
- [ ] 函式長度的舊債（<50 行的規則，都不是第三輪改的）：`jp_lang/tests/conjugate.rs` 三個 66／52／50 行、`jp_content/tests/load.rs` 58 行、`rust/tests/content_api.rs` 57 行、`jp_quiz/tests/drill_edge_cases.rs` 51 行；Dart 剛好 50 行的 `plan_adjust_sheet.dart:111`、`confusable_view.dart:19`、`kana_cell.dart:62`。
- [ ] 學習迴路模擬的答錯模式（選用）：`wrong_payload` 補 Reorder、Typing、Match、Shadow 的錯答。實測答錯率已是 29.5%（review_rust R2-L8 判定不成立），只是讓名稱完全成立。
- [ ] `rust/content/lint/r10_allow.txt` 裡寫錯的 ID 不會被報告，lint 只檢查理由與「已重現」。
- [ ] C1 不在 `p0_learning_loop_edges.rs` 的 `RULES` 內，「週一到週五＋每 40 天缺席」的學習者超出 C1 上界 2 天，只列量測。

### `full` 與 P1

- [ ] `full` 內容：L31–L48。`course.json` 已列出 L31–L48 與里程碑 `ms.n4_mid`、`ms.n4`，其他內容都還沒寫，`--stage full` 載入失敗（`le.l31: R03 dialogue 指向不存在的項目`）。
- [ ] P1：本機每日提醒、備份匯出與匯入、錄音回放、手寫描紅與筆順、VOICEVOX、術語卡的首次彈窗。
- [ ] P1：寬螢幕（768／1024）版面。目前多數頁靠左最大 720、右側留白，1024 的 T1 沒有右欄，K1 詳情仍在底部（第三輪 U13 延後：手機優先）。

## 待負責人裁決

第三輪已裁決的 31 項逐條記在 `docs/design/RULINGS.md` O12，第四輪（移除專區）已定案的決定記在 O13，這裡不再列。下列是還沒定案、或第三輪、第四輪修正時多做的判斷，需要確認：

| 項目 | 現況與選項 |
|---|---|
| 回鍋要有卡可碰（RC1） | 到期卡與收尾新卡都是 0 時不判 `ReturnAfterBreak`，否則那天做不了事、不會變成活躍日，天天判回鍋。裁決沒提到，修正時加的。改回見 O12 |
| 回鍋落在休息日（RC4、RC6） | `recovery_days` 歸 0，下個學習日從 1 起算，和 P2 字面「維持前一筆」有出入；`review_cap` 照樣減半。理由與改回見 O12 |
| T1 只剩收尾新卡的列（review_f F2、integ F-A） | 裁決 U5 要繼續列，所以保留，改成不蓋完成章、副標「最後再看 N 張新卡」。也可以選擇整列不列、只留清單下方的「收尾」列（`today_copy.dart` 的 `visibleTasks`） |
| `MixedText` 段首的小書き假名（review_f F3） | 中文後面的 `{ja:って}` 現在也不落在行首（段首插 U+2060，空白後面接這種字時空白換成 U+00A0，只有段落第一個字例外）。單獨舉例的假名因此會和前一個字一起換行。要改回：`mixed_text.dart` 的 `_textSpan` 拿掉 `afterText` 與 `withNoBreakSpaces` |
| `JaText` 的禁則 | U1、U2 的範圍是 `MixedText` 與 `RubyLine`。`JaText` 長句換行時，引擎同樣可能在小書き假名前換行，沒有處理（ftext 未解決 3）。要做只要套 `withLineStartJoiners` 與 `semanticsLabel` |
| 主線內容裡提到日劇、戲劇或歌詞的語感說明（第四輪） | `gr.te_wa_ikenai`、`gr.plain_style`、`gr.kedo_soft`、`gr.da_copula`、`gr.sfp_kana`、`vo.boku` 的說明文字保留，因為是對日語用法的一般描述，不指向被移除的功能。要拿掉就改這幾則的文字（O13） |
| 完整版期望說明的「無法做到無字幕追劇」（第四輪） | `expectation_copy.dart` 的 `ContentStage.full` 保留這句限制說明，只拿掉「聽得出常見語尾與縮約形」。`full` 還沒有內容，目前不會顯示 |
| 「關於程度」不再有日劇與歌曲的限制說明（第四輪） | `scope_copy.dart` 的兩段限制文字隨「聽懂日劇」「理解日文歌」兩列一起刪除，沒有併進其他列 |
| `/welcome/o2` 與 `/listen/zone/...`（第四輪） | 引導路徑不重新編號，`o2` 落到預設分支顯示歡迎頁；`/listen/zone/...` 沒有對應路由，走 go_router 的預設錯誤頁。App 沒有外部深連結，使用者走不到 |
| RULINGS O11、O12 的量測表（第四輪） | 保留含專區時的原文並加附註，移除後的數字只寫在 O13。也可以改成直接更新 O11 的表 |

## 目前的驗證狀態

2026-11-11 第三輪修正後在 Linux 上實際執行，下表是修正完成後的最終數字。沒有設 `CONTENT_STAGE`，也就是預設的 `p0`；標 `p0a` 的列另外指定階段。之後的文件同步沒有改程式與內容，又重跑過一次較快的項目，結果相同（見最後一列）。

第四輪（移除專區，RULINGS O13）之後，下表除了最後一列都在 2026-11-15、16 重跑過，結果欄有標日期（「文件裡的其他指令」那一列的 `coverage` 與「Linux 建置」的啟動冒煙沒有重跑，各自寫在該列）。最後一列「文件同步時重跑」是 2026-11-11 的歷史紀錄，保留原文。

| 檢查 | 指令 | 結果 |
|---|---|---|
| Dart 靜態分析 | `flutter analyze` | 2026-11-16：0 個問題 |
| Dart 格式 | `dart format --output=none --set-exit-if-changed lib test integration_test` | 2026-11-16：397 個檔案，0 個有變動（移除前 420 個） |
| Flutter 測試 | `flutter test --no-pub` | 2026-11-16：1,430 通過、0 失敗、0 略過，連跑三次相同。移除前 1,540：刪 115 個只驗被移除功能的案例（`test/features/zones/` 83 個，其餘 32 個分散在 14 個檔），新增 5 個（4 個反向回歸，1 個驗已存的 1.2 倍語速顯示成 1 倍），另有 36 個案例改了名稱（含群組「八種任務」改「六種任務」的 12 個）。golden 12 張與移除前逐位元組相同，`flutter test --no-pub --tags golden` 12 通過 |
| FFI 冒煙 | 包含在 `flutter test`（`test/ffi/core_ffi_test.dart`） | 2026-11-16：12 個測試通過、沒有略過，載入 2026-11-15 移除專區後以預設 `p0` 重建的 `rust/target/release/libjp_core.so`（比 `rust/` 下所有原始檔新） |
| Flutter 覆蓋率 | `flutter test --coverage`，`lib/` 排除 `lib/src/rust/**` | 2026-11-16：96.07%（10,602／11,036 行，237 個檔；移除前 11,305／11,767 行、248 個檔，百分比剛好相同） |
| Rust 測試 | `cargo test --workspace --no-fail-fast`（在 `rust/`） | 2026-11-16：98 組結果，1,257 通過，0 失敗，23 略過（`real_jmdict_catches_deliberate_mistakes` 需要真實資料；`p0_learning_loop.rs` 15 個、`p0_learning_loop_edges.rs` 7 個是下一列的長模擬） |
| 學習迴路長模擬 | `cargo test --release --test p0_learning_loop -- --ignored`；`--test p0_learning_loop_edges -- --ignored` | 2026-11-15：15 通過（137.59 秒）；7 通過（51.53 秒）。九位學習者的不變量違反數都是 0，量測見 RULINGS O13 |
| Rust 覆蓋率 | `cargo llvm-cov -p jp_core --ignore-filename-regex 'frb_generated' --fail-under-lines 80` | 2026-11-16：lines 98.94%（3,028 行，未覆蓋 32 行）、functions 98.19%（443 個，未覆蓋 8 個）、regions 94.93%，通過 |
| Clippy | `cargo clippy --workspace --all-targets -- -D warnings` | 2026-11-15：通過（另用全新的建置目錄從零跑一次，0 警告） |
| Rust 格式 | `cargo fmt --all -- --check` | 2026-11-15：通過 |
| 內容 lint | `content_tool --stage p0 lint` | 2026-11-16：0 錯誤，0 警告 |
| 內容驗證 | `content_tool --stage p0 verify`、`verify --strict` | 2026-11-15：29 條規則，0 錯誤，0 警告，5 則報告；`--strict` 結束碼 0 |
| `p0a` 內容 | `content_tool --stage p0a lint`、`verify`、`verify --strict` | 2026-11-15：lint 0 錯誤 0 警告；verify 29 條規則，0 錯誤 0 警告，`--strict` 結束碼 0 |
| 內容統計 | `content_tool --stage p0 stats` | 2026-11-16：全部達到 `p0` 目標；高於目標的有單字 812／800、主線例句 1,932／1,140、課程演練 1,082／900 |
| 夾具 verify | `content_tool verify --content-root rust/crates/jp_content/tests/fixtures/full --stage full --only J04,Z01,Z02,F01,F03`；`verify_cli.rs` 的夾具測試另含 F04 | 2026-11-16：5 條規則，0 錯誤、0 警告，結束碼 0 |
| 離線檢查 | `python3 tools/verify/check_offline.py` | 2026-11-23：靜態檢查與 79 MiB 通用 release APK 的 L07 都通過，APK 不含 `INTERNET` |
| Android APK | `flutter build apk --release`；`apksigner verify --verbose` | 2026-11-23：armv7、arm64、x86_64 通用 APK 建置成功，APK Signature Scheme v2 通過；尚未在實機啟動 |
| Linux 建置 | `flutter build linux --release` | 2026-11-16：通過（18.3 秒）。bundle 共 42,972,800 bytes（約 41 MiB）：`lib/` 34,784,509 bytes（`libflutter_linux_gtk.so` 17,256,536、`libjp_core.so` 9,423,464、`libapp.so` 7,947,144、`libdartjni.so` 157,320），`data/` 8,164,451，執行檔 23,840。10 秒啟動冒煙（`xvfb-run -a timeout 10 …/japanese_learn_app`）這次沒有重跑：release 執行檔會開這台機器上真正的 App 資料目錄；2026-11-11 的結果是結束碼 124（撐滿 10 秒） |
| 整合測試 | `JLA_SHOTS_DIR=… bash integration_test/run_all.sh`（xvfb-run） | 2026-11-16：七個檔案、15 個測試全過（first_run 4、multi_day 1、all_tabs 4、main_lesson 2、after_l21 2、no_voice 1、boot 1），共 13 分 40 秒（各檔 86、110、183、205、114、61、61 秒），截圖 27 張。實際執行的是與 `run_all.sh` 相同的七個指令，另加 `--no-pub`。之後依複核補上 J9「常體對話進 S4 跑完四階段」與 `le.k05` 的課程目標文字，七個檔在最終狀態再各跑一次，15 個測試全過（各檔時間沒有重量） |
| 整合測試的純規則單元測試 | `flutter --show-test-device test integration_test/support/p0_copy_rules_test.dart -d flutter-tester` | 2026-11-16：35 通過（`ruby_layout_rules_test.dart` 的 13 個已隨檔案於 O13 移除） |
| Python 工具測試 | `python3 -m unittest discover -s tools/fonts`、`tools/licenses`；`make_rust_crates.py --check` | 2026-11-16：各 4 個測試通過；`--check` 結束碼 0 |
| 文件裡的其他指令 | `content_tool available le.l03`；`--stage p0 charset`、`coverage`（`--repo-root` 指到暫存目錄，不寫進專案的 `build/`）；`cargo test --manifest-path rust/Cargo.toml -p jp_content --test content_lint`；`cargo test --manifest-path rust/Cargo.toml --test real_content_p0 --test real_content_p0_slices --test curriculum_days_real_content` | 2026-11-16 重跑其中四項：`available` 283 行、結束碼 0；`charset` 836／1,620 字；`content_lint` 61 通過；後者 12＋4＋5 通過。`coverage` 沒有重跑（2026-11-11 結束碼 0）。`--stage full charset` 結束碼 1（`le.l31: R03`，`full` 內容不存在，符合預期） |
| 文件同步時重跑（修正完成之後，Rust 用獨立的建置目錄，`content_tool` 的輸出指到暫存目錄） | `cargo fmt --all -- --check`；`cargo clippy --workspace --all-targets -- -D warnings`；`cargo test --workspace --no-fail-fast`；`cargo test -p jp_lang`；`cargo llvm-cov -p jp_lang --fail-under-lines 80`；`cargo build --manifest-path rust/Cargo.toml --workspace`；`cargo build --release --manifest-path rust/Cargo.toml`；`cargo test --release --test p0_learning_loop -- --ignored --exact report_every_learner --nocapture`；`flutter analyze --no-pub`；`dart format`（同上）；`flutter test --no-pub`；`flutter test --no-pub --tags golden`；上面的 `content_tool`、純規則單元測試、Python 工具與離線檢查 | 全部結束碼 0（`--stage full charset` 維持 1）。Rust 1,360 通過、0 失敗、27 略過；`jp_lang` 115 通過，lines 98.76%；`report_every_learner` 183.36 秒，五位學習者與 O12 的 5 倍列逐項相同；Flutter 1,540 通過；golden 12 通過。`flutter_rust_bridge_codegen generate`、`flutter pub get`、`make_charset.py --subset`、`fetch_data.sh` 只確認工具與選項存在，沒有實際執行，以免改動產生的檔案或連網；`run_all.sh` 沒有重跑，數字是上面整合測試那一列 |

**沒有驗證的事**

- 2026-11-23 已重跑 Linux release 的 10 秒啟動冒煙（結束碼 124，表示持續執行）；`run_all.sh` 本次沒有整支重跑，仍沿用上表七個旅程各自通過的結果。
- 真實內容加真實字型的振假名餘量與行首行尾禁則：原本由 J9 在專區畫面上量（`integration_test/support/ruby_layout*.dart`），隨專區移除後整合測試不再量，只剩 `test/core/text/` 的 widget test。
- 受限日（回鍋、積壓）的 T1：整合測試現在沒有任何旅程讓真實後端進入受限狀態，J3、J5、J7 都是連續學習日。移除前 J9 為了走到專區開放日會推進 7 天，那天後端判定回鍋，T1 在 375 與 320＋2 倍字級各畫過一次（只有每站共用的守門，沒有針對回鍋的斷言），這段隨專區移除。回鍋與積壓的判定、文案只由 Rust 測試（`rust/tests/return_after_break.rs`、`p0_learning_loop_edges.rs`、`jp_plan/tests/`）與 widget test（`test/features/today/today_screen_test.dart`、`today_copy_test.dart`，預設寬度）驗。
- Android 三 ABI 的 release APK 與 Rust 交叉編譯已驗證，但尚未在 Android 實機啟動，因此 FRB 在手機上的載入、內容載入時間、注音輸入法下的打字題、非線性字級縮放下振假名的位置仍未驗證；iOS 仍未建置。
- 實機 TTS：任何語音的實際聲音。整合測試用假引擎，開發環境沒有音效輸出。`docs/TTS_DEVICE_CHECKLIST.md` 的結果欄全空。
- 日語母語者審閱：內容的語意與自然度，`p0a`、`p0` 都還沒有人看過（含第二輪改寫的 26 句例句、第三輪的 `dr.l06.sub.001` 與 11 處拆開的標記）。
- 台語讀音的母語者抽查：`no.rd.*` 的台羅讀音。
- 原創性的人工抽查：主線例句與對話沒有機械的原創性檢查（只比對拒絕清單的 R14 已隨專區移除），還沒有人抽查過。
- `full`：內容不存在，`--stage full charset` 無法執行。
- `CONTENT_STAGE=p0a flutter build linux`（README 的範例）沒有實跑，不確定 cargokit 會把環境變數傳給 Rust 建置；`p0a` 只由 `cargo test`（測試內固定 `ContentStage::P0a`）與 `content_tool --stage p0a` 驗證。
- 學習迴路模擬只涵蓋主模擬 5 位與邊界 4 位學習者；真實使用者的作答分布、FSRS 參數是否適合初學者都要上線後用 `review_log` 校正。
- 淺色主題的真實畫面：這台機器在 xvfb 下系統主題是深色，整合測試的截圖除了 L1 進度條的兩張之外都是深色；淺色只靠 widget 測試與 golden。
- 振假名兩階段排版的效能：只在 `flutter test` 的除錯模式比較過改前改後（200 段的只重排最多約 3 倍，絕對值 24 毫秒，真實內容單一字串最多 16 個 ruby），沒有 profile 模式或手機的數字。
- Lighthouse 類的效能量測與跨平台截圖比對。
