//! 開發用內容工具（reuse-and-verification.md §9.4）：`available`、`lint`、`stats`、`verify`、`coverage`、`charset`。
//!
//! 結束代碼：0 通過、1 內容錯誤（含載入失敗）、2 環境問題（路徑缺失、資料缺失、階段無效）。

use std::io::{self, Write};
use std::path::PathBuf;
use std::process::ExitCode;

use clap::{Args, Parser, Subcommand};

use content_tool::commands::{run_available, run_lint, run_stats, ToolError};
use content_tool::verify::{run_charset, run_verify, VerifyOptions, COVERAGE_RULES};

const EXIT_CONTENT_ERROR: u8 = 1;
const EXIT_ENV_ERROR: u8 = 2;

#[derive(Parser)]
#[command(about = "內容撰寫與檢查工具")]
struct Cli {
    /// 內容目錄（從 repo 根目錄執行）。
    #[arg(long, global = true, default_value = "rust/content")]
    content_root: PathBuf,
    /// 內容階段；省略時取環境變數 CONTENT_STAGE，預設 p0。
    #[arg(long, global = true)]
    stage: Option<String>,
    /// repo 根目錄（報告輸出、pubspec、.gitignore、字型路徑的基準）。
    #[arg(long, global = true, default_value = ".")]
    repo_root: PathBuf,
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// 列出到某課為止可用的項目（TSV：id、surface、kana、lesson）。
    Available { lesson: String },
    /// 執行內容 lint（R01–R25、RC1–RC11）。
    Lint,
    /// 各類別筆數與當前階段目標。
    Stats,
    /// B 層驗證（J／F／C／Z／A／L）。外部資料由 tools/verify/fetch_data.sh 下載到 .verify-cache/。
    Verify(VerifyArgs),
    /// 只產生涵蓋率報告（C01–C04），報告寫到 build/verify/。
    Coverage(CacheArgs),
    /// 輸出字型子集用的字元集到 build/verify/chars_{ja,zh}.txt（§5.3）。
    Charset,
}

#[derive(Args)]
struct CacheArgs {
    /// 外部資料目錄（gitignored，內容見 tools/verify/data.lock.toml）。
    #[arg(long, default_value = ".verify-cache")]
    cache_dir: PathBuf,
}

#[derive(Args)]
struct VerifyArgs {
    #[command(flatten)]
    cache: CacheArgs,
    /// 只跑指定規則，以逗號分隔（例：J01,J05）。
    #[arg(long)]
    only: Option<String>,
    /// 警告也算失敗，且啟用當前階段的 C 門檻。
    #[arg(long)]
    strict: bool,
    /// 字型目錄（預設 <repo-root>/assets/fonts）。
    #[arg(long)]
    font_dir: Option<PathBuf>,
}

fn dispatch(cli: &Cli, out: &mut impl Write) -> Result<(), ToolError> {
    let stage = jp_content::disk::resolve_stage(cli.stage.as_deref())
        .map_err(|value| ToolError::Env(format!("CONTENT_STAGE 無效：{value}")))?;
    match &cli.command {
        Command::Available { lesson } => run_available(&cli.content_root, stage, lesson, out),
        Command::Lint => run_lint(&cli.content_root, stage, out),
        Command::Stats => run_stats(&cli.content_root, stage, out),
        Command::Verify(args) => {
            let opts = VerifyOptions {
                content_root: cli.content_root.clone(),
                repo_root: cli.repo_root.clone(),
                cache_dir: args.cache.cache_dir.clone(),
                font_dir: args.font_dir.clone(),
                stage,
                only: args.only.clone(),
                strict: args.strict,
            };
            run_verify(&opts, out)
        }
        Command::Coverage(args) => {
            let opts = VerifyOptions {
                content_root: cli.content_root.clone(),
                repo_root: cli.repo_root.clone(),
                cache_dir: args.cache_dir.clone(),
                font_dir: None,
                stage,
                only: Some(COVERAGE_RULES.to_owned()),
                strict: false,
            };
            run_verify(&opts, out)
        }
        Command::Charset => run_charset(&cli.content_root, &cli.repo_root, stage, out),
    }
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match dispatch(&cli, &mut io::stdout().lock()) {
        Ok(()) => ExitCode::SUCCESS,
        Err(ToolError::Content(message)) => report_failure(&message, EXIT_CONTENT_ERROR),
        Err(ToolError::Env(message)) => report_failure(&message, EXIT_ENV_ERROR),
    }
}

fn report_failure(message: &str, code: u8) -> ExitCode {
    // stderr 寫入失敗無處可報，結束代碼仍會反映錯誤。
    let _ = writeln!(io::stderr(), "{message}");
    ExitCode::from(code)
}
