//! `AppCore` 不透明型別、開啟、設定、清除資料（rust-core.md §9.3、§9.4、§10）。

use chrono::{DateTime, Utc};
use flutter_rust_bridge::frb;
use jp_content::ContentStore;

use super::dto_plan::{DisplayContext, DisplayPolicyDto, SettingsDto, SettingsPatchDto};
use super::error::CoreError;
use crate::app::deps::Deps;
use crate::app::settings;

pub struct CoreConfig {
    pub db_path: String,
    pub utc_offset_minutes: i32,
    /// 僅測試用：設定後使用 FixedClock。
    pub fixed_now_utc: Option<DateTime<Utc>>,
}

/// 方法一律 `&self`：FRB 對 `&self` 取共享鎖，`&mut self` 會把所有呼叫序列化（§10）。
#[frb(opaque)]
pub struct AppCore {
    pub(crate) deps: Deps,
}

impl AppCore {
    pub fn open(config: CoreConfig) -> Result<AppCore, CoreError> {
        let content = jp_content::load_embedded()?;
        Self::open_with_content(config, content)
    }

    /// 整合測試用夾具組成 `AppCore`（§3.4）。
    #[frb(ignore)]
    pub fn open_with_content(
        config: CoreConfig,
        content: ContentStore,
    ) -> Result<AppCore, CoreError> {
        Ok(AppCore {
            deps: Deps::open(&config, content)?,
        })
    }

    pub fn set_utc_offset(&self, minutes: i32) -> Result<(), CoreError> {
        self.deps.clock.set_utc_offset(minutes)?;
        Ok(())
    }

    pub fn settings(&self) -> Result<SettingsDto, CoreError> {
        settings::settings(&self.deps)
    }

    pub fn update_settings(&self, patch: SettingsPatchDto) -> Result<SettingsDto, CoreError> {
        settings::update_settings(&self.deps, patch)
    }

    pub fn display_policy(&self, context: DisplayContext) -> Result<DisplayPolicyDto, CoreError> {
        settings::display_policy(&self.deps, &context)
    }

    /// 關閉連線、刪檔、重建（§5.5）。
    pub fn reset_all(&self) -> Result<(), CoreError> {
        settings::reset_all(&self.deps)
    }
}

/// 給 DB 打不開時的「重設資料」，不需要 `AppCore`。
pub fn delete_database(db_path: String) -> Result<(), CoreError> {
    jp_store::delete_database(db_path)?;
    Ok(())
}
