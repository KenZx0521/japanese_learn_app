//! §5.1 開檔、§5.5 換檔、§10 單一 `Mutex<Connection>`。

use std::ffi::OsString;
use std::fs;
use std::io;
use std::mem;
use std::path::{Path, PathBuf};
use std::sync::{Mutex, MutexGuard, PoisonError};

use rusqlite::{Connection, Transaction, TransactionBehavior};

use crate::error::StoreError;
use crate::migrate::migrate;
use crate::repo::Repository;

const OPEN_PRAGMAS: &str = "PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA foreign_keys = ON;
PRAGMA busy_timeout = 5000;";

const DATABASE_FILE_SUFFIXES: [&str; 3] = ["", "-wal", "-shm"];

#[derive(Debug)]
pub struct SqliteRepository {
    conn: Mutex<Connection>,
    /// `None` 為記憶體庫。
    path: Option<PathBuf>,
}

impl Repository for SqliteRepository {}

impl SqliteRepository {
    pub fn open(path: impl AsRef<Path>) -> Result<Self, StoreError> {
        let path = path.as_ref().to_path_buf();
        Ok(Self {
            conn: Mutex::new(open_file(&path)?),
            path: Some(path),
        })
    }

    pub fn open_in_memory() -> Result<Self, StoreError> {
        Ok(Self {
            conn: Mutex::new(prepare(Connection::open_in_memory()?)?),
            path: None,
        })
    }

    /// §5.5。全程持有連線的鎖，其他呼叫在鎖上等待，不會打到過渡用的記憶體庫。
    /// 刪檔或重建失敗時回 `Storage`，連線留在沒有 schema 的記憶體庫，下次 `open` 會建新檔。
    pub fn reset_all(&self) -> Result<(), StoreError> {
        let mut guard = self.lock();
        // 舊連線在這裡 drop，關閉時收斂 WAL。
        drop(mem::replace(&mut *guard, Connection::open_in_memory()?));
        let fresh = match &self.path {
            Some(path) => {
                delete_database(path)?;
                open_file(path)
            }
            None => Connection::open_in_memory()
                .map_err(StoreError::from)
                .and_then(prepare),
        };
        *guard = fresh.map_err(|err| StoreError::storage(err.to_string()))?;
        Ok(())
    }

    /// panic 時 `Transaction` 的 Drop 已回滾，資料一致，所以中毒的鎖可以繼續用（§10）。
    fn lock(&self) -> MutexGuard<'_, Connection> {
        self.conn.lock().unwrap_or_else(PoisonError::into_inner)
    }

    pub(crate) fn with_conn<T>(
        &self,
        work: impl FnOnce(&Connection) -> Result<T, StoreError>,
    ) -> Result<T, StoreError> {
        work(&self.lock())
    }

    /// 寫入一律用 `BEGIN IMMEDIATE`；`work` 回 `Err` 時整筆回滾。
    pub(crate) fn with_tx<T>(
        &self,
        work: impl FnOnce(&Transaction<'_>) -> Result<T, StoreError>,
    ) -> Result<T, StoreError> {
        let mut guard = self.lock();
        let tx = guard.transaction_with_behavior(TransactionBehavior::Immediate)?;
        let value = work(&tx)?;
        tx.commit()?;
        Ok(value)
    }
}

fn open_file(path: &Path) -> Result<Connection, StoreError> {
    prepare(Connection::open(path)?)
}

fn prepare(mut conn: Connection) -> Result<Connection, StoreError> {
    conn.execute_batch(OPEN_PRAGMAS)?;
    migrate(&mut conn)?;
    Ok(conn)
}

/// 刪除 `.db`、`-wal`、`-shm`。不存在的檔案不算失敗；某個檔案刪不掉時仍會處理其餘的，
/// 再回傳第一個錯誤。
pub fn delete_database(path: impl AsRef<Path>) -> Result<(), StoreError> {
    let path = path.as_ref();
    let errors: Vec<StoreError> = DATABASE_FILE_SUFFIXES
        .iter()
        .filter_map(|suffix| remove_if_present(&with_suffix(path, suffix)).err())
        .collect();
    errors.into_iter().next().map_or(Ok(()), Err)
}

fn with_suffix(path: &Path, suffix: &str) -> PathBuf {
    let mut name = OsString::from(path);
    name.push(suffix);
    PathBuf::from(name)
}

fn remove_if_present(path: &Path) -> Result<(), StoreError> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(err) if err.kind() == io::ErrorKind::NotFound => Ok(()),
        Err(err) => Err(StoreError::storage(format!(
            "cannot delete {}: {err}",
            path.display()
        ))),
    }
}

#[cfg(test)]
mod tests {
    use std::panic::{catch_unwind, AssertUnwindSafe};

    use super::*;
    use crate::repo::SettingsRepo;

    fn pragma(repo: &SqliteRepository, name: &str) -> i64 {
        repo.with_conn(|conn| Ok(conn.query_row(&format!("PRAGMA {name}"), [], |row| row.get(0))?))
            .unwrap()
    }

    fn app_setting_count(repo: &SqliteRepository) -> i64 {
        repo.with_conn(|conn| {
            Ok(conn.query_row("SELECT COUNT(*) FROM app_setting", [], |row| row.get(0))?)
        })
        .unwrap()
    }

    fn insert_setting(tx: &Transaction<'_>) -> Result<(), StoreError> {
        tx.execute("INSERT INTO app_setting VALUES ('k', 'v')", [])?;
        Ok(())
    }

    #[test]
    fn open_applies_connection_pragmas() {
        let dir = tempfile::tempdir().unwrap();
        let repo = SqliteRepository::open(dir.path().join("jp_core.db")).unwrap();

        // synchronous：NORMAL 為 1。
        assert_eq!(pragma(&repo, "synchronous"), 1);
        assert_eq!(pragma(&repo, "foreign_keys"), 1);
        assert_eq!(pragma(&repo, "busy_timeout"), 5000);
    }

    #[test]
    fn work_error_rolls_back_the_transaction() {
        let repo = SqliteRepository::open_in_memory().unwrap();

        let result: Result<(), StoreError> = repo.with_tx(|tx| {
            insert_setting(tx)?;
            Err(StoreError::storage("boom"))
        });

        assert!(result.is_err());
        assert_eq!(app_setting_count(&repo), 0);
    }

    /// §11.2 review_flow 的「panic 後回滾」，同時驗證 §10 的中毒恢復。
    #[test]
    fn panic_inside_transaction_rolls_back_and_lock_recovers() {
        let repo = SqliteRepository::open_in_memory().unwrap();

        let outcome = catch_unwind(AssertUnwindSafe(|| {
            repo.with_tx(|tx| -> Result<(), StoreError> {
                insert_setting(tx)?;
                panic!("模擬交易中途 panic");
            })
        }));

        assert!(outcome.is_err());
        assert!(repo.conn.is_poisoned());
        assert_eq!(app_setting_count(&repo), 0);
        repo.with_tx(insert_setting).unwrap();
        assert_eq!(app_setting_count(&repo), 1);
        assert!(repo.get_settings().is_ok());
    }

    #[test]
    fn suffix_is_appended_after_the_full_file_name() {
        assert_eq!(
            with_suffix(Path::new("/data/jp_core.db"), "-wal"),
            PathBuf::from("/data/jp_core.db-wal")
        );
    }
}
