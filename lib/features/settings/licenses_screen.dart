import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntry, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../design/tokens.dart';
import '../../design/widgets/app_text.dart';
import '../../design/widgets/async_body.dart';
import '../../design/widgets/back_line.dart';
import '../../design/widgets/paper_scaffold.dart';
import '../../design/widgets/ruled_list.dart';
import '../../design/widgets/sheet_frame.dart';
import '../../design/widgets/side_rule_note.dart';
import 'license_copy.dart';
import 'rust_crates.dart';
import 'widgets/settings_section.dart';

final fontLicenseTextProvider = FutureProvider.autoDispose
    .family<String, String>(
      (ref, file) => rootBundle.loadString('assets/fonts/licenses/$file'),
    );

final rustCrateListProvider = FutureProvider.autoDispose<List<RustCrateInfo>>(
  (ref) async => parseRustCrates(await rootBundle.loadString(rustCratesAsset)),
);

@immutable
final class PackageLicense {
  const PackageLicense(this.name, this.entries);
  final String name;
  final List<LicenseEntry> entries;
}

/// 字型另有一區，這裡排除，避免重複。
final packageLicensesProvider =
    FutureProvider.autoDispose<List<PackageLicense>>((ref) async {
      final grouped = <String, List<LicenseEntry>>{};
      await for (final entry in LicenseRegistry.licenses) {
        for (final package in entry.packages) {
          if (package.endsWith(fontRegistrySuffix)) continue;
          grouped.putIfAbsent(package, () => []).add(entry);
        }
      }
      final names = grouped.keys.toList()..sort();
      return [for (final name in names) PackageLicense(name, grouped[name]!)];
    });

/// X3 授權（reuse §10）。用稿紙風格的自製頁面呈現 `LicenseRegistry`，
/// 而非 Material 預設的 `showLicensePage`。
class LicensesScreen extends ConsumerWidget {
  const LicensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppTokens.of(context);
    return PaperScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PopBackLine(),
          Semantics(
            header: true,
            child: const AppText('授權', scale: TypeScale.displayM),
          ),
          const SizedBox(height: AppSpace.s5),
          SettingsSection(
            label: '字型',
            children: [for (final font in fontLicenses) _FontRow(font: font)],
          ),
          AppText(
            fontTrademarkNote,
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
          const SizedBox(height: AppSpace.s6),
          const SideRuleNote(
            title: '開發時參照的資料',
            child: AppText(jmdictStatement),
          ),
          const SizedBox(height: AppSpace.s4),
          const SideRuleNote(
            title: '參考級別來源',
            child: AppText(jlptReferenceStatement),
          ),
          const SizedBox(height: AppSpace.s6),
          const SettingsSection(label: 'Rust', children: [_RustCratesRow()]),
          Semantics(header: true, child: const EyebrowText('開放原始碼套件')),
          const SizedBox(height: AppSpace.s2),
          AsyncBody(
            value: ref.watch(packageLicensesProvider),
            onRetry: () => ref.invalidate(packageLicensesProvider),
            data: (packages) => _PackageList(packages: packages),
          ),
        ],
      ),
    );
  }
}

class _FontRow extends StatelessWidget {
  const _FontRow({required this.font});

  final FontLicenseInfo font;

  void _open(BuildContext context) => unawaited(
    showPaperSheet<void>(context, child: _FontLicenseSheet(font: font)),
  );

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return RuledTile(
      title: AppText(font.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(
            font.copyright,
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
          AppText(
            ofLicenseLine,
            scale: TypeScale.caption,
            color: t.ink.secondary,
          ),
        ],
      ),
      trailing: AppText('全文', scale: TypeScale.label, color: t.ai),
      onTap: () => _open(context),
    );
  }
}

class _FontLicenseSheet extends ConsumerWidget {
  const _FontLicenseSheet({required this.font});
  final FontLicenseInfo font;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = fontLicenseTextProvider(font.file);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(font.name, scale: TypeScale.title),
        const SizedBox(height: AppSpace.s3),
        AsyncBody(
          value: ref.watch(provider),
          onRetry: () => ref.invalidate(provider),
          data: (text) => AppText(text, scale: TypeScale.caption),
        ),
      ],
    );
  }
}

class _RustCratesRow extends StatelessWidget {
  const _RustCratesRow();

  void _open(BuildContext context) =>
      unawaited(showPaperSheet<void>(context, child: const _RustCratesSheet()));

  @override
  Widget build(BuildContext context) {
    final t = AppTokens.of(context);
    return RuledTile(
      title: const AppText(rustCratesTitle),
      subtitle: AppText(
        rustCratesSubtitle,
        scale: TypeScale.caption,
        color: t.ink.secondary,
      ),
      trailing: AppText('清單', scale: TypeScale.label, color: t.ai),
      onTap: () => _open(context),
    );
  }
}

class _RustCratesSheet extends ConsumerWidget {
  const _RustCratesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const AppText(rustCratesTitle, scale: TypeScale.title),
      const SizedBox(height: AppSpace.s3),
      AsyncBody(
        value: ref.watch(rustCrateListProvider),
        onRetry: () => ref.invalidate(rustCrateListProvider),
        data: (crates) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [for (final crate in crates) _RustCrateLine(crate: crate)],
        ),
      ),
    ],
  );
}

class _RustCrateLine extends StatelessWidget {
  const _RustCrateLine({required this.crate});
  final RustCrateInfo crate;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpace.s2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText('${crate.name} ${crate.version}', scale: TypeScale.caption),
        AppText(
          crate.license,
          scale: TypeScale.caption,
          color: AppTokens.of(context).ink.secondary,
        ),
      ],
    ),
  );
}

class _PackageList extends StatelessWidget {
  const _PackageList({required this.packages});
  final List<PackageLicense> packages;

  @override
  Widget build(BuildContext context) {
    if (packages.isEmpty) {
      return AppText(
        '這個版本沒有額外的套件授權資料。',
        scale: TypeScale.caption,
        color: AppTokens.of(context).ink.secondary,
      );
    }
    return RuledList(
      children: [
        for (final package in packages)
          RuledTile.text(
            package.name,
            onTap: () => unawaited(
              showPaperSheet<void>(
                context,
                child: _PackageSheet(package: package),
              ),
            ),
          ),
      ],
    );
  }
}

class _PackageSheet extends StatelessWidget {
  const _PackageSheet({required this.package});
  final PackageLicense package;

  static const _indentStep = AppSpace.s3;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      AppText(package.name, scale: TypeScale.title),
      const SizedBox(height: AppSpace.s3),
      for (final entry in package.entries)
        for (final paragraph in entry.paragraphs)
          Padding(
            padding: EdgeInsets.only(
              left: paragraph.indent > 0 ? paragraph.indent * _indentStep : 0,
              bottom: AppSpace.s2,
            ),
            child: AppText(paragraph.text, scale: TypeScale.caption),
          ),
    ],
  );
}
