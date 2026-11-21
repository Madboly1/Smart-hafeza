import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/bouga_tokens.dart';
import '../../legacy_import/data/bouga_database.dart';
import '../data/app_backup_envelope.dart';
import '../data/backup_settings.dart';
import '../data/bouga_account.dart';
import '../data/cloud_restore.dart';
import '../data/drive_backup_service.dart';

/// Google account + personal Drive backup section. Everything here is
/// optional and manual: no auto-upload, no auto-restore, and sign-out
/// never touches local data or previous backups.
class CloudAccountSection extends StatefulWidget {
  const CloudAccountSection({
    super.key,
    required this.database,
    required this.onLibraryRestored,
  });

  final BougaDatabase database;
  final Future<void> Function() onLibraryRestored;

  @override
  State<CloudAccountSection> createState() => _CloudAccountSectionState();
}

class _CloudAccountSectionState extends State<CloudAccountSection> {
  final _drive = DriveBackupService();
  bool _busy = false;
  String? _lastBackupName;

  BougaAccount get _account => BougaAccount.instance;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signIn() async {
    setState(() => _busy = true);
    final error = await _account.signIn();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error == null) return;
    if (error == 'canceled') return;
    _showMessage('تعذر تسجيل الدخول: $error');
  }

  Future<void> _signOut() async {
    await _account.signOut();
    if (!mounted) return;
    setState(() => _lastBackupName = null);
    _showMessage('تم تسجيل الخروج. بياناتك ونسخك السابقة محفوظة زي ما هي.');
  }

  Future<Map<String, String>?> _headers() async {
    final headers = await _account.driveHeaders(promptIfNeeded: true);
    if (headers == null && mounted) {
      _showMessage(
        'محتاج إذن الوصول لدرايف عشان النسخ الاحتياطي. جرّب تاني ووافق على الإذن.',
      );
    }
    return headers;
  }

  Future<void> _backupNow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final headers = await _headers();
      if (headers == null) return;
      final legacy = await widget.database.exportLegacyJson();
      final settings = await BougaBackupSettings.capture();
      final email = _account.currentUser.value?.email;
      final envelope = AppBackupEnvelope.build(
        legacyExportJson: legacy,
        settings: settings,
        account: email,
      );
      final stamp = DateTime.now()
          .toUtc()
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;
      final name = '${DriveBackupService.namePrefix}$stamp.json';
      await _drive.uploadBackup(headers, utf8.encode(envelope), name);
      if (!mounted) return;
      setState(() => _lastBackupName = name);
      _showMessage('اتحفظت نسخة جديدة في درايف: $name');
    } on DriveBackupException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('تعذر النسخ الاحتياطي، حاول تاني.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreFlow() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final headers = await _headers();
      if (headers == null) return;
      final backups = await _drive.listBackups(headers);
      if (!mounted) return;
      if (backups.isEmpty) {
        _showMessage('مفيش نسخ سابقة في درايف للحساب ده.');
        return;
      }
      final picked = await showDialog<DriveBackupFile>(
        context: context,
        builder: (dialogContext) => SimpleDialog(
          title: const Text('اختار نسخة للاستعادة'),
          children: backups
              .map(
                (file) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(dialogContext, file),
                  child: Text(_describeFile(file)),
                ),
              )
              .toList(),
        ),
      );
      if (picked == null || !mounted) return;
      final bytes = await _drive.downloadBackup(headers, picked.id);
      final backup = AppBackupEnvelope.parse(utf8.decode(bytes));
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('استعادة النسخة دي؟'),
          content: Text(_previewText(backup)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('استعادة'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await CloudRestore.writeSafetySnapshot(
        widget.database,
        account: _account.currentUser.value?.email,
      );
      final report = await CloudRestore.applyBackup(widget.database, backup);
      await widget.onLibraryRestored();
      if (!mounted) return;
      _showMessage(
        report.skippedAsDuplicate
            ? 'نفس البيانات موجودة بالفعل، مفيش حاجة اتكررت.'
            : 'تمت الاستعادة: ${report.linkCount} رابط و${report.categoryCount} تصنيف.',
      );
    } on DriveBackupException catch (error) {
      _showMessage(error.message);
    } on FormatException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('تعذرت الاستعادة، حاول تاني.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _describeFile(DriveBackupFile file) {
    final created = file.createdTime?.toLocal();
    final date = created == null
        ? file.name
        : '${created.year}-${created.month.toString().padLeft(2, '0')}-${created.day.toString().padLeft(2, '0')} ${created.hour.toString().padLeft(2, '0')}:${created.minute.toString().padLeft(2, '0')}';
    final size = file.sizeBytes == null
        ? ''
        : ' • ${(file.sizeBytes! / 1024).toStringAsFixed(0)} ك.ب';
    return '$date$size';
  }

  String _previewText(AppBackup backup) {
    final buffer = StringBuffer()
      ..writeln('تاريخ النسخة: ${backup.exportedAt ?? 'غير معروف'}')
      ..writeln(
        'المحتوى: ${backup.linkCount} رابط و${backup.categoryCount} تصنيف',
      );
    final account = backup.account;
    final current = _account.currentUser.value?.email;
    if (account != null && account.isNotEmpty) {
      buffer.writeln('الحساب اللي عمل النسخة: $account');
      if (current != null && account != current) {
        buffer.writeln('تنبيه: النسخة دي من حساب مختلف عن اللي مسجل دلوقتي.');
      }
    }
    buffer.write(
      'بياناتك الحالية هتفضل محفوظة محليًا كنسخة أمان قبل الاستعادة.',
    );
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (!BougaAccount.configured) return const SizedBox.shrink();
    return ValueListenableBuilder(
      valueListenable: _account.currentUser,
      builder: (context, user, _) {
        if (user == null) {
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.login)),
              title: const Text('تسجيل الدخول بحساب جوجل'),
              subtitle: const Text(
                'اختياري — عشان تحتفظ بنسخة احتياطية في جوجل درايف بتاعك. التطبيق شغال بالكامل من غيره.',
              ),
              trailing: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(
                      Icons.chevron_left,
                      textDirection: TextDirection.ltr,
                    ),
              onTap: _busy ? null : _signIn,
            ),
          );
        }
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.account_circle_outlined),
                ),
                title: Text(
                  user.displayName?.isNotEmpty == true
                      ? user.displayName!
                      : user.email,
                ),
                subtitle: Text(user.email),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.cloud_upload_outlined,
                  color: BougaColors.mint,
                ),
                title: const Text('نسخ احتياطي الآن في درايف'),
                subtitle: Text(
                  _lastBackupName == null
                      ? 'نسخة مؤرخة جديدة في المجلد الخاص بالتطبيق في درايف بتاعك. النسخ القديمة بتفضل زي ما هي.'
                      : 'آخر نسخة: $_lastBackupName',
                ),
                onTap: _busy ? null : _backupNow,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(
                  Icons.cloud_download_outlined,
                  color: BougaColors.mint,
                ),
                title: const Text('استعادة من درايف'),
                subtitle: const Text(
                  'يعرض النسخ المتاحة بتاريخها وعدد روابطها قبل ما تختار. بياناتك الحالية بتتحفظ كنسخة أمان الأول.',
                ),
                onTap: _busy ? null : _restoreFlow,
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.logout, color: BougaColors.muted),
                title: const Text('تسجيل الخروج'),
                subtitle: const Text(
                  'بيمسح تسجيل الدخول بس — بياناتك ونسخك محفوظة.',
                ),
                onTap: _busy ? null : _signOut,
              ),
              if (_busy) const LinearProgressIndicator(),
            ],
          ),
        );
      },
    );
  }
}
