//! §5.2 遷移。已發布的遷移不可修改，新需求一律加新檔。

use rusqlite::{Connection, TransactionBehavior};

use crate::error::StoreError;

const MIGRATIONS: &[&str] = &[include_str!("sql/001_init.sql")];

/// App 目前認得的 schema 版本，等於遷移數量。
pub const LATEST_SCHEMA_VERSION: i32 = MIGRATIONS.len() as i32;

pub(crate) fn migrate(conn: &mut Connection) -> Result<(), StoreError> {
    run(conn, MIGRATIONS)
}

fn run(conn: &mut Connection, migrations: &[&str]) -> Result<(), StoreError> {
    let latest = migrations.len() as i32; // 遷移數量遠小於 i32::MAX
    let current = user_version(conn).map_err(|err| failure(0, err))?;
    if !(0..=latest).contains(&current) {
        return Err(failure(
            current,
            format!("database version {current} is outside 0..={latest}"),
        ));
    }
    for (target, sql) in (1..=latest).zip(migrations) {
        if target > current {
            apply_step(conn, target, sql).map_err(|err| failure(target - 1, err))?;
        }
    }
    Ok(())
}

/// 版本與 DDL 在同一個 transaction，失敗時一起回滾。
fn apply_step(conn: &mut Connection, target: i32, sql: &str) -> rusqlite::Result<()> {
    let tx = conn.transaction_with_behavior(TransactionBehavior::Immediate)?;
    // hot restart 時可能有另一條連線剛完成同一步。
    if user_version(&tx)? < target {
        tx.execute_batch(sql)?;
        tx.pragma_update(None, "user_version", target)?;
    }
    tx.commit()
}

fn user_version(conn: &Connection) -> rusqlite::Result<i32> {
    conn.query_row("PRAGMA user_version", [], |row| row.get(0))
}

fn failure(from_version: i32, message: impl ToString) -> StoreError {
    StoreError::MigrationFailed {
        from_version,
        message: message.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIRST: &str = "CREATE TABLE a(x INTEGER);";
    const SECOND: &str = "CREATE TABLE b(x INTEGER);";
    const BROKEN: &str = "CREATE TABLE c(x INTEGER); THIS IS NOT SQL;";

    fn table_exists(conn: &Connection, name: &str) -> bool {
        conn.query_row(
            "SELECT COUNT(*) FROM sqlite_master WHERE name = ?1",
            [name],
            |row| row.get::<_, i64>(0),
        )
        .unwrap()
            == 1
    }

    #[test]
    fn applies_only_pending_steps() {
        let mut conn = Connection::open_in_memory().unwrap();
        run(&mut conn, &[FIRST]).unwrap();

        run(&mut conn, &[FIRST, SECOND]).unwrap();

        assert_eq!(user_version(&conn).unwrap(), 2);
        assert!(table_exists(&conn, "b"));
    }

    #[test]
    fn failing_step_keeps_earlier_steps_and_reports_its_starting_version() {
        let mut conn = Connection::open_in_memory().unwrap();

        let err = run(&mut conn, &[FIRST, BROKEN]).unwrap_err();

        assert!(
            matches!(
                err,
                StoreError::MigrationFailed {
                    from_version: 1,
                    ..
                }
            ),
            "{err:?}"
        );
        assert_eq!(user_version(&conn).unwrap(), 1);
        assert!(table_exists(&conn, "a"));
        assert!(!table_exists(&conn, "c"));
    }

    #[test]
    fn step_already_done_by_another_connection_is_skipped() {
        let mut conn = Connection::open_in_memory().unwrap();
        conn.pragma_update(None, "user_version", 1).unwrap();

        apply_step(&mut conn, 1, BROKEN).unwrap();

        assert_eq!(user_version(&conn).unwrap(), 1);
    }

    #[test]
    fn latest_version_matches_migration_count() {
        assert_eq!(LATEST_SCHEMA_VERSION as usize, MIGRATIONS.len());
    }
}
