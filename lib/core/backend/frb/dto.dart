// Features 一律 import 這個檔案取得 DTO，不直接 import lib/src/rust（architecture §5.3）。
// `ThemeMode` 與 material_ui 同名，以 `AppThemeMode` 匯出。
import 'package:japanese_learn_app/src/rust/api/dto_plan.dart' as plan;

export 'package:japanese_learn_app/src/rust/api/dto_content.dart';
export 'package:japanese_learn_app/src/rust/api/dto_plan.dart' hide ThemeMode;
export 'package:japanese_learn_app/src/rust/api/dto_study.dart';
export 'package:japanese_learn_app/src/rust/api/error.dart';

typedef AppThemeMode = plan.ThemeMode;
