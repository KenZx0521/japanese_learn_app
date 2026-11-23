CREATE TABLE app_setting(
  key   TEXT PRIMARY KEY,
  value TEXT NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE srs_card(
  card_id           TEXT PRIMARY KEY,
  content_id        TEXT NOT NULL,
  facet             TEXT NOT NULL CHECK (facet IN ('read','listen','recog','produce','use')),
  priority          INTEGER NOT NULL DEFAULT 0 CHECK (priority IN (0,1)),
  state             INTEGER NOT NULL CHECK (state BETWEEN 0 AND 3),
  due_at            INTEGER NOT NULL,
  last_review_at    INTEGER NOT NULL,
  stability         REAL NOT NULL CHECK (stability >= 0),
  difficulty        REAL NOT NULL CHECK (difficulty BETWEEN 0 AND 10),
  elapsed_days      INTEGER NOT NULL,
  scheduled_days    INTEGER NOT NULL,
  reps              INTEGER NOT NULL DEFAULT 0,
  lapses            INTEGER NOT NULL DEFAULT 0,
  last_logical_date TEXT,
  suspended         INTEGER NOT NULL DEFAULT 0 CHECK (suspended IN (0,1)),
  introduced_seq    INTEGER NOT NULL,
  created_at        INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE INDEX idx_card_sched   ON srs_card(state, due_at) WHERE suspended = 0;
CREATE INDEX idx_card_new     ON srs_card(priority, introduced_seq) WHERE suspended = 0 AND state = 0;
CREATE INDEX idx_card_content ON srs_card(content_id, last_logical_date);

CREATE TABLE review_log(
  id                 INTEGER PRIMARY KEY AUTOINCREMENT,
  card_id            TEXT NOT NULL,
  rating             INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 4),
  state_before       INTEGER NOT NULL CHECK (state_before BETWEEN 0 AND 3),
  state_after        INTEGER NOT NULL CHECK (state_after BETWEEN 0 AND 3),
  elapsed_days       INTEGER NOT NULL,
  scheduled_days     INTEGER NOT NULL,
  stability_after    REAL NOT NULL CHECK (stability_after > 0),
  difficulty_after   REAL NOT NULL CHECK (difficulty_after BETWEEN 1 AND 10),
  reviewed_at        INTEGER NOT NULL,
  logical_date       TEXT NOT NULL,
  utc_offset_minutes INTEGER NOT NULL,
  duration_ms        INTEGER NOT NULL CHECK (duration_ms >= 0),
  question_type      TEXT NOT NULL,
  clock_skewed       INTEGER NOT NULL DEFAULT 0 CHECK (clock_skewed IN (0,1))
) STRICT;

CREATE INDEX idx_log_card ON review_log(card_id, id);
CREATE INDEX idx_log_date ON review_log(logical_date);

CREATE TRIGGER review_log_no_update BEFORE UPDATE ON review_log
BEGIN SELECT RAISE(ABORT, 'review_log is append-only'); END;
CREATE TRIGGER review_log_no_delete BEFORE DELETE ON review_log
BEGIN SELECT RAISE(ABORT, 'review_log is append-only'); END;

CREATE TABLE daily_activity(
  logical_date TEXT PRIMARY KEY,
  reviews_done INTEGER NOT NULL DEFAULT 0,
  new_done     INTEGER NOT NULL DEFAULT 0,
  relearn_done INTEGER NOT NULL DEFAULT 0,
  lessons_done INTEGER NOT NULL DEFAULT 0,
  drills_done  INTEGER NOT NULL DEFAULT 0,
  study_ms     INTEGER NOT NULL DEFAULT 0,
  shadow_kept   INTEGER NOT NULL DEFAULT 0,
  shadow_almost INTEGER NOT NULL DEFAULT 0,
  shadow_lost   INTEGER NOT NULL DEFAULT 0
) STRICT, WITHOUT ROWID;

CREATE TABLE plan_version(
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  effective_from TEXT NOT NULL,
  daily_minutes  INTEGER NOT NULL CHECK (daily_minutes IN (10,20,30,45)),
  weekday_mask   INTEGER NOT NULL CHECK (weekday_mask BETWEEN 1 AND 127),
  start_level    TEXT NOT NULL CHECK (start_level IN ('zero','hiragana','kana','basic')),
  target_date    TEXT,
  created_at     INTEGER NOT NULL
) STRICT;

CREATE INDEX idx_plan_effective ON plan_version(effective_from, id);

CREATE TRIGGER plan_version_no_update BEFORE UPDATE ON plan_version
BEGIN SELECT RAISE(ABORT, 'plan_version is append-only'); END;
CREATE TRIGGER plan_version_no_delete BEFORE DELETE ON plan_version
BEGIN SELECT RAISE(ABORT, 'plan_version is append-only'); END;

CREATE TABLE plan_baseline(
  plan_version_id INTEGER NOT NULL REFERENCES plan_version(id),
  milestone_id    TEXT NOT NULL,
  planned_date    TEXT NOT NULL,
  PRIMARY KEY (plan_version_id, milestone_id)
) STRICT, WITHOUT ROWID;

CREATE TABLE item_intro(
  item_id      TEXT PRIMARY KEY,
  lesson_id    TEXT NOT NULL,
  logical_date TEXT NOT NULL,
  introduced_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE INDEX idx_intro_lesson ON item_intro(lesson_id);

CREATE TABLE kana_mastery(
  kana_id       TEXT PRIMARY KEY,
  correct_run   INTEGER NOT NULL DEFAULT 0,
  fast_run      INTEGER NOT NULL DEFAULT 0,
  attempts      INTEGER NOT NULL DEFAULT 0,
  mastered_at   INTEGER,
  fast_badge_at INTEGER
) STRICT, WITHOUT ROWID;

CREATE TABLE lesson_progress(
  lesson_id             TEXT PRIMARY KEY,
  integration_days_done INTEGER NOT NULL DEFAULT 0,
  integration_dialogue  TEXT,
  skipped               INTEGER NOT NULL DEFAULT 0 CHECK (skipped IN (0,1)),
  completed_date        TEXT,
  completed_at          INTEGER
) STRICT, WITHOUT ROWID;

CREATE TABLE milestone_result(
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  milestone_id TEXT NOT NULL,
  correct      INTEGER NOT NULL CHECK (correct >= 0),
  total        INTEGER NOT NULL CHECK (total > 0),
  passed       INTEGER NOT NULL CHECK (passed IN (0,1)),
  logical_date TEXT NOT NULL,
  taken_at     INTEGER NOT NULL
) STRICT;

CREATE INDEX idx_milestone ON milestone_result(milestone_id, id);

CREATE TRIGGER milestone_result_no_update BEFORE UPDATE ON milestone_result
BEGIN SELECT RAISE(ABORT, 'milestone_result is append-only'); END;
CREATE TRIGGER milestone_result_no_delete BEFORE DELETE ON milestone_result
BEGIN SELECT RAISE(ABORT, 'milestone_result is append-only'); END;

CREATE TABLE daily_plan_snapshot(
  logical_date    TEXT PRIMARY KEY,
  plan_version_id INTEGER NOT NULL REFERENCES plan_version(id),
  payload_json    TEXT NOT NULL,
  created_at      INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE daily_task_done(
  logical_date TEXT NOT NULL,
  task_key     TEXT NOT NULL,
  done_at      INTEGER NOT NULL,
  PRIMARY KEY (logical_date, task_key)
) STRICT, WITHOUT ROWID;

CREATE TABLE milestone_dismissed(
  milestone_id TEXT PRIMARY KEY,
  logical_date TEXT NOT NULL,
  dismissed_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;

CREATE TABLE vocab_flag(
  vocab_id   TEXT PRIMARY KEY,
  known      INTEGER NOT NULL DEFAULT 0 CHECK (known IN (0,1)),
  starred    INTEGER NOT NULL DEFAULT 0 CHECK (starred IN (0,1)),
  updated_at INTEGER NOT NULL
) STRICT, WITHOUT ROWID;
