import 'package:flutter/material.dart';

import '../../../core/theme/bouga_tokens.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.onImportBackup});

  final Future<void> Function() onImportBackup;

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
                onTap: onImportBackup,
              ),
            ),
            const SizedBox(height: 24),
            const _SectionTitle('التحديثات'),
            const Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Icon(Icons.system_update_alt),
                ),
                title: Text('تحديث التطبيق'),
                subtitle: Text(
                  'قناة التحديثات التلقائية قيد التجهيز. '
                  'لن يتم تثبيت أي تحديث دون موافقتك.',
                ),
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
