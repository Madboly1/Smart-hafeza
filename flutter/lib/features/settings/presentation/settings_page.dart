import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/bouga_tokens.dart';
import '../data/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.onImportBackup});

  final Future<void> Function() onImportBackup;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  UpdateStatus? _updateStatus;
  bool _checkingUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() {
      _checkingUpdates = true;
      _updateStatus = null;
    });

    final result = await UpdateService().checkForUpdate();
    if (!mounted) return;
    setState(() {
      _checkingUpdates = false;
      _updateStatus = result.status;
    });

    switch (result.status) {
      case UpdateStatus.noUpdate:
        _showMessage('التطبيق مُحدّث بالفعل، مفيش تحديث جديد.');
        break;
      case UpdateStatus.temporarilyUnavailable:
        _showMessage('تعذر التحقق من التحديثات مؤقتًا. جرّب تاني بعد شوية.');
        break;
      case UpdateStatus.updateAvailable:
        await _showUpdateDialog(result.manifest!);
        break;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _showUpdateDialog(UpdateManifest manifest) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Expanded(child: Text('تحديث جديد متاح')),
            if (manifest.mandatory)
              const Chip(
                label: Text('تحديث مطلوب'),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        content: Text(
          'الإصدار ${manifest.versionName}\n\n'
          '${manifest.releaseMessage}'
          '${manifest.mandatory ? '\n\nسبب إلزامية التحديث: ${manifest.releaseMessage}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('لاحقًا'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final opened = await launchUrl(
                manifest.apkUrl,
                mode: LaunchMode.externalApplication,
              );
              if (!opened && mounted) {
                _showMessage('تعذر فتح رابط التحديث. حاول مرة أخرى.');
              }
            },
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }

  String get _updateSubtitle {
    if (_checkingUpdates) return 'جارٍ التحقق من التحديثات...';
    switch (_updateStatus) {
      case UpdateStatus.noUpdate:
        return 'لا يوجد تحديث جديد.';
      case UpdateStatus.updateAvailable:
        return 'يوجد تحديث جديد متاح.';
      case UpdateStatus.temporarilyUnavailable:
        return 'تعذر التحقق مؤقتًا. التطبيق يعمل بشكل طبيعي.';
      case null:
        return 'تحقق من توفر إصدار أحدث للتطبيق.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionTitle('النسخ الاحتياطي'),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.file_upload_outlined),
                ),
                title: const Text('استيراد نسخة احتياطية'),
                subtitle: const Text(
                  'استرجع روابطك وتصنيفاتك من ملف نسخة بُؤجة.',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: widget.onImportBackup,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('التحديثات'),
            Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.system_update_alt),
                ),
                title: const Text('تحديث التطبيق'),
                subtitle: Text(_updateSubtitle),
                trailing: _checkingUpdates
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_left),
                onTap: _checkingUpdates ? null : _checkForUpdates,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('عن بُؤجة'),
            const Card(
              child: Column(
                children: [
                  ListTile(
                    leading: CircleAvatar(
                      child: Icon(Icons.inventory_2_outlined),
                    ),
                    title: Text('BOUGA | بُؤجة'),
                    subtitle: Text('كل اللي يهمك.. في بُؤجة واحدة.'),
                  ),
                  Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: Icon(Icons.info_outline, color: BougaColors.mint),
                    title: Text('الإصدار'),
                    subtitle: Text('1.0.0 • النسخة التأسيسية'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'مساحتك الخاصة للمحتوى الذي يهمك.',
                style: TextStyle(color: BougaColors.muted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: BougaColors.mint,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
