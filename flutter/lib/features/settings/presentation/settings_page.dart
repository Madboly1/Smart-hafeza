import '../../onboarding/presentation/bouga_tour.dart';
import '../data/reminder_service.dart';
import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../data/android_update_service.dart';

import '../../../core/theme/bouga_tokens.dart';
import '../data/update_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage(
      {super.key,
      required this.onImportBackup,
      required this.onExportBackup,
      this.onReplayTour,
      this.tourStart,
      this.tourTotal});

  final Future<void> Function() onImportBackup;
  final Future<void> Function() onExportBackup;
  final Future<void> Function()? onReplayTour;
  final int? tourStart;
  final int? tourTotal;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _reminders = ReminderService();
  final _tourReminders = GlobalKey();
  final _tourBackup = GlobalKey();
  final _tourUpdate = GlobalKey();
  Future<void> _runSettingsTour() async {
    var index = widget.tourStart!;
    final steps = [
      (
        target: _tourReminders,
        title: 'فكّر نفسك باللي محفوظ',
        text:
            'التذكير للروابط اللي لسه ما اتفتحتش. تقدر تغيّر عدد الأيام أو تقفله، ولازم تسمح بالإشعارات. أندرويد ممكن يأخره حسب البطارية.'
      ),
      (
        target: _tourBackup,
        title: 'خلي معاك نسخة',
        text:
            'صدّر ملف JSON تحفظه في مكان آمن، أو استورد نسخة عندك. ده ملف محلي، مش نسخ تلقائي على جوجل.'
      ),
      (
        target: _tourUpdate,
        title: 'التحديث من هنا',
        text:
            'تحقّق من إصدار جديد وثبّته فوق النسخة المنفصلة من غير مسحها. خلصنا، وتقدر تعيد الجولة من إعدادات بؤجة.'
      ),
    ];
    for (final step in steps) {
      if (!mounted) return;
      final next = await showBougaTourStep(context,
          target: step.target,
          title: step.title,
          text: step.text,
          step: ++index,
          total: widget.tourTotal!,
          last: index == widget.tourTotal);
      if (!next) break;
    }
    if (mounted) Navigator.of(context).pop();
  }

  ReminderSettings _reminderSettings = const ReminderSettings();
  bool _savingReminders = false;
  @override
  void initState() {
    super.initState();
    _loadReminders();
    if (widget.tourStart != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSettingsTour();
      });
    }
  }

  Future<void> _loadReminders() async {
    try {
      final value = await _reminders.read();
      if (mounted) setState(() => _reminderSettings = value);
    } catch (_) {
      if (mounted) _showMessage('تعذر قراءة إعدادات التذكير.');
    }
  }

  Future<void> _saveReminders(bool enabled, int days) async {
    if (_savingReminders) return;
    setState(() => _savingReminders = true);
    try {
      final value = await _reminders.save(enabled: enabled, days: days);
      if (!mounted) return;
      setState(() => _reminderSettings = value);
      if (enabled && !value.enabled) {
        _showMessage(
            'الإشعارات مقفولة. اسمح لبؤجة بالإشعارات من إعدادات الموبايل.');
      }
    } catch (_) {
      if (mounted) _showMessage('تعذر حفظ التذكير، حاول تاني.');
    } finally {
      if (mounted) setState(() => _savingReminders = false);
    }
  }

  UpdateStatus? _updateStatus;
  bool _checkingUpdates = false;

  Future<void> _checkForUpdates() async {
    if (_checkingUpdates) return;
    setState(() {
      _checkingUpdates = true;
      _updateStatus = null;
    });

    final result = await AndroidUpdateService().check();
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
              await _downloadUpdate(manifest);
            },
            child: const Text('تحديث الآن'),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadUpdate(UpdateManifest manifest) async {
    final progress = ValueNotifier<double?>(null);
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('جارٍ تنزيل التحديث'),
          content: ValueListenableBuilder<double?>(
            valueListenable: progress,
            builder: (_, value, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: value),
                const SizedBox(height: 16),
                const Text(
                    'بعد التحقق من الملف هتفتح شاشة تثبيت أندرويد. وافق على التثبيت من المصدر ده لو طلب منك. بياناتك بتفضل زي ما هي، ما تمسحش التطبيق.')
              ],
            ),
          ),
        ),
      ),
    ));
    String? error;
    try {
      await AndroidUpdateService()
          .downloadAndInstall(manifest, (value) => progress.value = value);
    } catch (_) {
      error =
          'تعذر تنزيل أو فتح التحديث. اتأكد من الإنترنت وجرّب تاني. ما تمسحش التطبيق.';
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      progress.dispose();
    }
    if (mounted && error != null) _showMessage(error);
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
            if (widget.onReplayTour != null)
              Card(
                  child: ListTile(
                      leading: const Icon(Icons.explore_outlined,
                          color: BougaColors.gold),
                      title: const Text('إعادة جولة الشرح'),
                      onTap: () => widget.onReplayTour!())),
            const _SectionTitle('تذكير الروابط'),
            Card(
                child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SwitchListTile(
                              key: _tourReminders,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('فكّرني باللي لسه ما اتفتحش'),
                              value: _reminderSettings.enabled,
                              onChanged:
                                  !_reminders.supported || _savingReminders
                                      ? null
                                      : (value) => _saveReminders(
                                          value, _reminderSettings.days)),
                          const Text('بعد كام يوم من الحفظ؟'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                              initialValue: _reminderSettings.days,
                              decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 14)),
                              items: [1, 2, 3, 7, 14, 30]
                                  .map((days) => DropdownMenuItem(
                                      value: days, child: Text('$days أيام')))
                                  .toList(),
                              onChanged: !_reminders.supported ||
                                      _savingReminders
                                  ? null
                                  : (days) {
                                      if (days != null) {
                                        _saveReminders(
                                            _reminderSettings.enabled, days);
                                      }
                                    }),
                          const SizedBox(height: 12),
                          const Text(
                              'تذكير محلي مجمّع، مرة واحدة لكل رابط. المراجعة يوميًا حوالي ١٠ صباحًا، وممكن تتأخر حسب البطارية. الروابط القديمة اللي مش معروف اتفتحت ولا لأ مش بتدخل في التذكير.',
                              style: TextStyle(
                                  color: BougaColors.muted, fontSize: 12)),
                          if (!_reminders.supported)
                            const Text('التذكير متاح في نسخة أندرويد.'),
                          if (_savingReminders) const LinearProgressIndicator(),
                        ]))),
            const SizedBox(height: 24),
            const _SectionTitle('النسخ الاحتياطي'),
            Card(
              key: _tourBackup,
              child: Column(
                children: [
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.file_upload_outlined),
                    ),
                    title: const Text('استيراد نسخة احتياطية'),
                    subtitle: const Text(
                      'استرجع روابطك وتصنيفاتك من ملف نسخة بُؤجة.',
                    ),
                    trailing: const Icon(Icons.chevron_left,
                        textDirection: TextDirection.ltr),
                    onTap: widget.onImportBackup,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.file_download_outlined),
                    ),
                    title: const Text('تصدير نسخة احتياطية'),
                    subtitle: const Text(
                      'احفظ نسخة JSON من روابطك وبياناتك على جهازك.',
                    ),
                    trailing: const Icon(Icons.chevron_left,
                        textDirection: TextDirection.ltr),
                    onTap: widget.onExportBackup,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('التحديثات'),
            Card(
              key: _tourUpdate,
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
                    : const Icon(Icons.chevron_left,
                        textDirection: TextDirection.ltr),
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
                    subtitle:
                        Text('النسخة المنفصلة • تحديثاتها من الزر الموجود فوق'),
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
