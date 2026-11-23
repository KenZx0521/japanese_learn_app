#!/usr/bin/env bash
# 依序跑全部整合測試；說明見 integration_test/README.md。
# Linux 桌面一次只能啟動一個測試 App，多個檔案要分開執行（第二個檔案會連不上除錯連線）。
# 截圖：JLA_SHOTS_DIR=<目錄> bash integration_test/run_all.sh（J4、J9 沿途存 PNG）。
# 文案守門的單元測試不需要開 App，另外跑（見 README）。
set -euo pipefail
cd "$(dirname "$0")/.."

# 函式庫：App 在 Linux 先載執行檔旁 bundle/lib 打包的 libjp_core.so（native_library.dart），
# 不會再載到工作目錄下舊的 rust/target/release，不需要額外設定環境變數。

screen=(-a -s "-screen 0 1400x1100x24")
fake=(-d linux --dart-define=JLA_TTS=fake --dart-define=JLA_TEST_HOOKS=true)
if [[ -n "${JLA_SHOTS_DIR:-}" ]]; then
  fake+=(--dart-define=JLA_SHOTS_DIR="$JLA_SHOTS_DIR")
fi

for test in first_run multi_day all_tabs main_lesson after_l21; do
  xvfb-run "${screen[@]}" flutter test "integration_test/${test}_journey_test.dart" "${fake[@]}"
done

xvfb-run "${screen[@]}" flutter test integration_test/no_voice_journey_test.dart \
  -d linux --dart-define=JLA_TTS=unavailable --dart-define=JLA_TEST_HOOKS=true

JLA_DATA_DIR="$(mktemp -d)" xvfb-run "${screen[@]}" flutter test \
  integration_test/boot_test.dart -d linux --dart-define=JLA_TTS=fake
