# Flutter App TTS 服務（flutter-app-tts.md）

本文件是 [flutter-app.md](flutter-app.md) 的 §6，章節編號沿用。文中的 §3、§4 指主文件，§5 指 [flutter-app-architecture.md](flutter-app-architecture.md)。

## 6. TTS 服務

### 6.1 介面（已編譯並通過測試）

```dart
enum TtsSpeed { normal, slow }
enum TtsAvailabilityKind { unknown, ready, voiceNotDownloaded, noJapaneseVoice, engineMissing }

final class SpeechRequest {   // id 用內容 ID，例如 se.l05.001
  const SpeechRequest({required this.id, required this.text, required this.kana,
      this.speed = TtsSpeed.normal, this.voice = VoiceSlot.a});
  final String id, text, kana;   // text＝SpeechDto.text（行動平台）；kana＝SpeechDto.kana（Linux）
  final TtsSpeed speed;
  final VoiceSlot voice;
}

sealed class TtsEvent { const TtsEvent(this.id); final String id; }   // TtsStarted、TtsCompleted、TtsFailed

abstract interface class TtsEngine {
  Stream<TtsEvent> get events;
  Future<TtsAvailability> probe();
  Future<void> speak(SpeechRequest request);
  Future<void> stop();
}
```

`unknown` 是 `ttsAvailabilityProvider` 的初值，表示第一次探測尚未完成，`probe()` 不回傳這個值（§6.6）；它不在已編譯的原型內，實作時連同測試補上。

所有播放來源都帶 `SpeechDto`（句子、對話、選項、假名、單字、語音示範組），`SpeechRequest.fromDto(id, dto)` 直接取 `text`、`kana`，Dart 不自行組字串也不判斷誤讀。逐詞播放時兩者都傳 `WordDto.speech_kana`（助詞 は 已是 わ）。

### 6.2 平台支援（讀 flutter_tts 4.2.5 原始碼）

| 平台 | 實作 | `isLanguageAvailable` | `getVoices` | `setSpeechRate` | 完成回呼 | 不支援時 |
|---|---|---|---|---|---|---|
| Android | `TextToSpeech` | ≥`LANG_AVAILABLE`，語音資料未下載也可能為 true，要另用 `isLanguageInstalled` | `name`、`locale`、`quality`、`latency`、`network_required`、`features`；可能回 null | 傳入值×2：0.5＝原生 1.0；範圍 0–1.5 | `speak.onStart`／`onComplete`／`onCancel`／`onError` | |
| iOS | `AVSpeechSynthesizer` | 比對 `speechVoices` 前綴 | `name`、`locale`、`quality`（default/enhanced/premium）、`gender`、`identifier` | 直接傳：0.5＝預設；範圍 0–1 | start／complete／cancel；**無 error 回呼** | |
| macOS | 同 iOS | 有 | 有 | 同 iOS | 同 iOS | 非目標平台 |
| Web | `speechSynthesis` | 有 | 有 | 直接傳，**1＝正常**，與行動端尺度不同 | 有 | 非目標平台 |
| Windows | SAPI／WinRT | **未實作**（`NotImplemented`） | 有 | `(rate-0.5)*15` | 有 | 非目標平台 |
| Linux | 無 | `MissingPluginException` | 同左 | 同左 | 無 | 【實測】全部方法都拋例外 |

選擇引擎：`Platform.isLinux` 用 `SpdSayTtsEngine`，其餘用 `FlutterTtsEngine(FlutterTts(), isAndroid: Platform.isAndroid)`。`integration_test` 用 `--dart-define=JLA_TTS=fake` 可換成假引擎。

### 6.3 FlutterTtsEngine

**探測順序**（每步 5 秒 timeout，timeout 視為 `engineMissing`）：

1. Android：`getEngines` 為空 → `engineMissing`。
2. `isLanguageAvailable('ja-JP')` 非 true → `noJapaneseVoice`。
3. Android：`isLanguageInstalled('ja-JP')` 非 true → `voiceNotDownloaded`。
4. iOS：`setSharedInstance(true)`，再 `setIosAudioCategory(playback, [duckOthers], spokenAudio)`。**否則靜音開關打開時按播放沒有聲音**，初學者會以為壞了。
5. `setLanguage('ja-JP')`。
6. `getVoices` 過濾 `locale` 開頭為 `ja`、Android 排除 `network_required=="1"`（維持離線），依 quality 選最佳後 `setVoice`。

**語音事件歸屬**：flutter_tts 的回呼不帶 utterance id，由引擎自己管理：

```dart
void _onComplete() {
  final id = _id;
  if (id == null || !_started) return;   // 上一句遲到的完成事件
  _id = null;
  _events.add(TtsCompleted(id));
}
```

- **不設定 `setCancelHandler`**。Android 的 `onStop` 是非同步的，前一句遲到的 cancel 可能打斷新一句。停止的狀態轉移由 `TtsController` 自己做。
- **不用 `awaitSpeakCompletion(true)`**（實證 #6）。另外 Android 開啟時，播放中再 `speak` 會直接回 0 並丟棄新句。
- 每次播放前必先 `stop()`。佇列模式維持預設 flush。

**語速**：

| 速度 | Android／iOS 傳入值 | spd-say `-r` |
|---|---|---|
| 正常（1.0 倍） | 0.5 | 0 |
| 慢速（約 0.7 倍） | Android 0.35；iOS 0.42【待實機校準】 | -50（【實測】時間為正常的 1.4 倍） |

iOS 的 rate 與實際語速不是線性，數值放在 `TtsRateProfile` 常數，實機校準只改一處。

### 6.4 SpdSayTtsEngine 與語音不可用的 UX

**探測**：`spd-say -O` 失敗（`ProcessException`）→ `engineMissing`。依序試 `openjtalk`、`espeak-ng`：

```dart
Future<bool> _reallySpeaks(String module) async {
  final sw = Stopwatch()..start();
  final r = await Process.run('spd-say', ['-o', module, '-l', 'ja', '-i', '-100', '-w', 'あ']);
  return r.exitCode == 0 && sw.elapsedMilliseconds >= 150;
}
```

不可用 `-L` 判斷，實證 #8 顯示它會說謊。

播放送 `request.kana`（實證 #9）。`-C` 會清除整台機器的 speech-dispatcher 佇列，可能影響其他 App，Linux 只作驗證平台，可接受。

**使用者看到的內容**（`TtsAvailabilityKind` 對應，`VoiceHelpSheet`）：

| 狀態 | 文案 | 操作步驟 |
|---|---|---|
| `voiceNotDownloaded`（Android） | 手機還沒下載日語語音 | 設定 › 系統 › 語言 › 文字轉語音 › Google 語音服務 › 安裝語音資料 › 日本語。下載由系統進行，本 App 不連網。廠牌路徑不同，依 `docs/TTS_DEVICE_CHECKLIST.md` 的實機結果修訂【待實機】 |
| `noJapaneseVoice`（iOS） | 找不到日語語音 | 設定 › 輔助使用 › 語音內容 › 聲音 › 日文 |
| `engineMissing`（Android） | 手機沒有語音引擎 | 從 Play 商店安裝「Google 語音服務」 |
| `noJapaneseVoice`／`engineMissing`（Linux） | 開發用平台，需要 speech-dispatcher 與日語模組 | `sudo apt install speech-dispatcher-espeak-ng`；音質僅供驗證 |

**O5 的兩個出口**：探測失敗或使用者按「聽不到」時，`VoiceHelpSheet` 內固定有「現在設定」（依上表步驟操作，回到 App 重新探測）與「先用無聲模式」（寫 `silent_mode = true`，繼續引導）。不提供無選擇的略過。

**原則**：語音不可用時**絕不靜默**。

- `SpeakButton` 維持可見，外觀改為有斜線的喇叭，點擊開 `VoiceHelpSheet`。
- T1、S1 頂部顯示 `VoiceBanner`。
- 需要語音的卡片與題目由 `audio_available = false` 從 Rust 端排除（§6.6），Dart 沒有略過按鈕，也不寫 FSRS。
- 使用者裝好語音回到 App 時（`AppLifecycleListener.onResume`），重新探測。
- S2 的音調組固定標註「由裝置合成，僅供參考」，S2 要標示「語音由裝置合成，音調可能不完全正確」（課綱 §10.3）。

### 6.5 TtsController 與播放狀態

狀態為 sealed `TtsPlayback`：`TtsIdle`、`TtsPreparing(id)`、`TtsSpeaking(id)`、`TtsError(id, reason)`。邏輯重點（已通過：過期事件、看門狗、同 id 切換）：

- 全 App 同時只播一句。`toggle(req)`：同 id 代表停止，不同 id 代表切換。`_currentId` 是唯一標記，事件 id 不符就丟棄。
- `speak`／`stop` 呼叫有 3 秒 timeout；送出後啟動 5 秒看門狗，沒收到 `TtsStarted` 就轉 `TtsError('no-start-event')`。iOS 沒有 error 回呼，所以這是必要的。
- `playSequence(requests, gap)`：對話連播、逐詞（400ms）、跟讀（句長×1.5）。以遞增 token 判斷被打斷。
- `AppLifecycleListener.onHide` 與離開 session（`ref.onDispose`）時呼叫 `stop()`。

`SpeakButton` 狀態：

| 狀態 | 外觀 | 語意 |
|---|---|---|
| idle | 喇叭線條圖 | 「播放」 |
| preparing | 200ms 後才顯示細環 | 「準備中」 |
| speaking | 三條音波動畫；再按停止 | 「停止播放」 |
| error | `shu` 外框，點擊開說明 | 「播放失敗，查看說明」 |
| unavailable | 斜線喇叭 | 「語音無法使用，查看說明」 |

`SpeedToggle` 在每個播放鈕旁（課綱 §10.1），偏好存入 `tts_rate`（0.7、1.0）。`speedFromRate(rate)`：`rate <= 0.85` 為 `slow`，其餘 `normal`。1.2 倍語速已移除（見 RULINGS O13）；已存的 `tts_rate = 1.2` 讀到時當正常速度，下次切換寫入 0.7。

### 6.6 `audio_available` 與無聲模式

`core/tts/audio_available.dart`：

```dart
final audioAvailableProvider = Provider<bool>((ref) {
  final tts = ref.watch(ttsAvailabilityProvider);
  final silent = ref.watch(settingsProvider.select((s) => s.value?.silentMode ?? false));
  return tts.kind == TtsAvailabilityKind.ready && !silent;
});

// 第一次探測完成且設定已載入時為 true，此時 audioAvailableProvider 的值才算數
final audioResolvedProvider = Provider<bool>((ref) {
  final probed = ref.watch(ttsAvailabilityProvider.select((a) => a.kind != TtsAvailabilityKind.unknown));
  final settingsLoaded = ref.watch(settingsProvider.select((s) => s.hasValue));
  return probed && settingsLoaded;
});
```

- **探測完成前**：`kind == unknown` 時 `audioAvailableProvider` 為 false，但這個 false 不代表語音不可用。此時不得呼叫任何帶 `audio_available` 的 Rust 函式，T1、T2、V4、K2、D2、D3、L3 與 G2 小測驗顯示骨架，否則快照會以 false 凍結一整天。取資料的 provider 與 controller 在 `audioResolvedProvider` 為 false 時停在載入階段，轉 true 才用 `audioAvailableProvider` 的值發出第一次呼叫。唯一例外是 O3 的 `checkpoint_start("ms.hira", 0, false)`（§3.1），它不寫快照。`unknown` 時 `VoiceBanner` 不顯示，不開 `VoiceHelpSheet`，`SpeakButton` 顯示 preparing 外觀且不可點。探測有 timeout（§6.3），不會卡在骨架。
- 所有帶 `audio_available` 參數的 Rust 函式（`rust-core.md` §9.4）都傳這個值。**Dart 不判斷哪些題需要語音**，由 Rust 排除（`rust-core.md` §8.6「需要語音」欄），這些卡不計入到期數與積壓判定。
- **無聲模式**：`SettingsDto.silent_mode`，由 O5 或 X2 設定。`VoiceBanner` 以常駐說明顯示「無聲模式：聽力題暫時不出現，語音恢復後會自動回來」與「設定語音」連結，出現在 T1、S1。`SpeakButton` 維持斜線外觀，點擊開說明。
- **可用性改變時**：T2、V4、K2、D2、L3 的 controller 用 `ref.listen(audioAvailableProvider, ...)`，以**同 seed 重新呼叫**取題函式（`session_next`、`kana_session`、`drill_session`、`listen_session`、`new_content_session`）與 `today_view`。尚未作答的題目直接丟棄，不寫任何資料。**D3 例外**：作答中題目定住不換，已作答的內容不重置；語音由可用轉為不可用且題目含要聽才能作答的題時，顯示「語音改變了，檢定要重新開始。」回到說明頁重新取題。
- **中途播放失敗**（`TtsError` 且本題需要播放才能作答，即題幹為 `hide_text_until_answered` 或只有播放鈕）：題幹區改顯示 `VoiceFailedPanel`：「這題要聽聲音，現在播不出來。」按鈕「重試」與「改用無聲模式」。後者寫 `silent_mode = true`，觸發上一條的重新取題。此畫面不提供略過，也不把這題記錄為答錯。
