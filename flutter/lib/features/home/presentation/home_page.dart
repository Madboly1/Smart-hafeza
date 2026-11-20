import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../links/data/embedded_content.dart';
import '../../links/presentation/embedded_content_page.dart';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import '../../links/data/external_link_opener.dart';
import '../../links/data/incoming_share_service.dart';
import '../../legacy_import/data/backup_export_service.dart';
import '../../../core/theme/bouga_tokens.dart';
import '../../legacy_import/data/bouga_database.dart';
import '../../links/data/bouga_links_repository.dart';
import '../../settings/presentation/settings_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ExternalLinkOpener _linkOpener = ExternalLinkOpener();
  final IncomingShareService _incomingShare = IncomingShareService();
  final List<String> _pendingShares = [];
  bool _shareDialogOpen = false;
  BougaDatabase? _db;
  BougaLinksRepository? _repo;
  List<Map<String, Object?>> _links = [];
  List<String> _categories = [];
  bool _onlyUnopened = false;
  Map<String, int> _groupCounts = {};
  String _query = '';
  String _category = 'الكل';
  bool _loading = true;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      _db = await BougaDatabase.open();
      _repo = BougaLinksRepository(_db!);
      await _refresh();
    } catch (error) {
      if (mounted) {
        setState(() => _startupError = error.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        if (_repo != null) {
          unawaited(_incomingShare.start((text) {
            _pendingShares.add(text);
            unawaited(_showPendingShares());
          }));
        }
      }
    }
  }

  Future<void> _refresh() async {
    if (_repo == null) {
      return;
    }
    var links = await _repo!.list(query: _query, category: _category);
    if (_onlyUnopened) {
      links = links.where((item) => item['open_state'] == 'unopened').toList();
    }
    final categories = await _repo!.categories();
    final all = await _repo!.list();
    final counts = <String, int>{};
    for (final item in all) {
      final c = item['category']?.toString() ?? '';
      counts[c] = (counts[c] ?? 0) + 1;
    }
    if (mounted) {
      setState(() {
        _links = links;
        _categories = categories;
        _groupCounts = counts;
      });
    }
  }

  @override
  void dispose() {
    _incomingShare.dispose();
    _db?.close();
    super.dispose();
  }

  Future<void> _importBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) {
        return;
      }
      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        throw const FormatException('تعذر قراءة ملف النسخة الاحتياطية.');
      }

      if (!mounted) {
        return;
      }
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('استيراد نسخة بُؤجة'),
          content: const Text(
            'هنضيف الروابط والتصنيفات الموجودة في الملف إلى مكتبتك الحالية. '
            'الاستيراد بيحافظ على بياناتك الموجودة ومش بيمسح أي روابط. '
            'لو فيه رابط بنفس المعرّف، بيانات النسخة هتحدّثه.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('استيراد ودمج'),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }

      final report = await _db!.importLegacyJson(utf8.decode(bytes));
      await _refresh();
      if (!mounted) {
        return;
      }
      final message = report.skippedAsDuplicate
          ? 'النسخة دي مستوردة بالفعل، مفيش حاجة اتكررت.'
          : 'تم استيراد ${report.linkCount} رابط و${report.categoryCount} تصنيف بنجاح.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on FormatException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('ملف النسخة الاحتياطية غير صالح: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر استيراد النسخة الاحتياطية: $error')),
        );
      }
    }
  }

  Future<void> _exportBackup() async {
    try {
      final saved = await BackupExportService().save(_db!);
      if (!mounted || !saved) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ النسخة الاحتياطية بنجاح.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تصدير النسخة الاحتياطية: $error')),
        );
      }
    }
  }

  Future<void> _newGroup() async {
    var name = '';
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
              title: const Text('مجموعة جديدة'),
              content: TextField(
                  onChanged: (value) => name = value,
                  maxLength: 60,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'اسم المجموعة')),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () {
                      if (name.trim().isNotEmpty) {
                        Navigator.pop(dialogContext, true);
                      }
                    },
                    child: const Text('إنشاء'))
              ],
            ));
    if (confirmed == true) {
      await _db!.addCategory(name);
      await _refresh();
    }
  }

  Future<void> _showPendingShares() async {
    if (_shareDialogOpen || !mounted || _repo == null) return;
    _shareDialogOpen = true;
    try {
      while (mounted && _pendingShares.isNotEmpty) {
        final url =
            IncomingShareService.firstWebUrl(_pendingShares.removeAt(0));
        if (url == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('المشاركة دي مفيهاش رابط ويب صالح.')),
          );
          continue;
        }
        await _add(sharedUrl: url);
      }
    } finally {
      _shareDialogOpen = false;
    }
  }

  Future<void> _add({String? sharedUrl}) async {
    final url = TextEditingController(text: sharedUrl);
    final title = TextEditingController();
    final category =
        TextEditingController(text: _category == 'الكل' ? '' : _category);
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('إضافة رابط'),
              content: Form(
                  key: form,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextFormField(
                        controller: url,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(labelText: 'الرابط'),
                        validator: (v) {
                          final parsed = Uri.tryParse(v?.trim() ?? '');
                          return parsed != null &&
                                  parsed.hasAuthority &&
                                  (parsed.scheme == 'https' ||
                                      parsed.scheme == 'http')
                              ? null
                              : 'اكتب رابط صحيح يبدأ بـ https://';
                        }),
                    TextField(
                        controller: title,
                        decoration: const InputDecoration(
                            labelText: 'العنوان (اختياري)')),
                    if (_categories.isNotEmpty)
                      Wrap(
                          spacing: 6,
                          children: _categories
                              .map((c) => ActionChip(
                                  label: Text(c),
                                  onPressed: () => category.text = c))
                              .toList()),
                    TextField(
                        controller: category,
                        decoration: const InputDecoration(
                            labelText: 'المجموعة (اختياري)')),
                  ])),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('إلغاء')),
                FilledButton(
                    onPressed: () {
                      if (form.currentState!.validate()) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('حفظ')),
              ],
            ));
    if (save == true) {
      final added = await _repo!.add(
          url: url.text,
          title: title.text,
          category: category.text.trim(),
          kind: 'رابط');
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(added == 0 ? 'الرابط محفوظ بالفعل' : 'اتحفظ في بُؤجة')),
        );
      }
    }
    url.dispose();
    title.dispose();
    category.dispose();
  }

  Future<void> _details(Map<String, Object?> item) async {
    final id = item['id'].toString();
    final title = TextEditingController(text: item['title']?.toString() ?? '');
    final category =
        TextEditingController(text: item['category']?.toString() ?? 'أخرى');
    final note = TextEditingController(text: item['note']?.toString() ?? '');
    var progress = (item['progress'] as int? ?? 0).clamp(0, 100);
    final remove = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => StatefulBuilder(
            builder: (context, modalSet) => Padding(
                  padding: EdgeInsets.fromLTRB(20, 12, 20,
                      MediaQuery.of(context).viewInsets.bottom + 24),
                  child: SingleChildScrollView(
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                        Text(item['url'].toString(),
                            textDirection: TextDirection.ltr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final rawUrl = item['url']?.toString() ?? '';
                            final embedded = EmbeddedContent.fromUrl(rawUrl);
                            if (embedded != null &&
                                !kIsWeb &&
                                defaultTargetPlatform ==
                                    TargetPlatform.android) {
                              await _db!.markOpened(item['id'].toString());
                              if (!context.mounted) return;
                              await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                      builder: (_) => EmbeddedContentPage(
                                          content: embedded,
                                          originalUrl: rawUrl)));
                              return;
                            }
                            final result = await _linkOpener.open(rawUrl);
                            if (result == LinkOpenResult.opened) {
                              await _db!.markOpened(item['id'].toString());
                            }
                            if (!context.mounted) return;
                            final message = switch (result) {
                              LinkOpenResult.opened => null,
                              LinkOpenResult.invalidUrl =>
                                'الرابط غير صالح أو غير آمن للفتح.',
                              LinkOpenResult.launchFailed =>
                                'تعذر فتح الرابط. حاول مرة أخرى.',
                            };
                            if (message != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(message)),
                              );
                            }
                          },
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('فتح الرابط'),
                        ),
                        TextField(
                            controller: title,
                            decoration:
                                const InputDecoration(labelText: 'العنوان')),
                        TextField(
                            controller: category,
                            decoration: const InputDecoration(
                                labelText: 'المجموعة (اختياري)')),
                        TextField(
                            controller: note,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(labelText: 'ملاحظات')),
                        Text('التقدم: $progress%'),
                        Slider(
                            value: progress.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            onChanged: (v) =>
                                modalSet(() => progress = v.round())),
                        FilledButton(
                            onPressed: () async {
                              await _repo!.update(
                                  id: id,
                                  title: title.text,
                                  category: category.text.trim(),
                                  note: note.text,
                                  progress: progress);
                              if (context.mounted) {
                                Navigator.pop(context, false);
                              }
                            },
                            child: const Text('حفظ التعديلات')),
                        TextButton.icon(
                            onPressed: () => Navigator.pop(context, true),
                            icon: const Icon(Icons.delete_outline,
                                color: BougaColors.danger),
                            label: const Text('حذف الرابط')),
                      ])),
                )));
    if (remove == true) {
      await _repo!.delete(id);
    }
    await _refresh();
    title.dispose();
    category.dispose();
    note.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
              actions: [
                IconButton(
                    tooltip: 'الإعدادات',
                    onPressed: _loading
                        ? null
                        : () => Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => SettingsPage(
                                onImportBackup: _importBackup,
                                onExportBackup: _exportBackup))),
                    icon: const Icon(Icons.settings_outlined))
              ],
              title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('بُؤجة',
                        style: TextStyle(
                            letterSpacing: 2, fontWeight: FontWeight.w800)),
                    Text('روابطك المهمة، في مكان واحد.',
                        style:
                            TextStyle(fontSize: 11, color: BougaColors.muted)),
                  ])),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: FilledButton.icon(
                      onPressed: _loading ? null : _add,
                      icon: const Icon(Icons.add_link),
                      label: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('إضافة رابط',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold)))))),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _startupError != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                              'حصلت مشكلة في فتح بُؤجة:\n$_startupError',
                              textAlign: TextAlign.center)))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const Text('مكتبتك',
                                style: TextStyle(color: BougaColors.mint)),
                            const SizedBox(height: 8),
                            const Text('احفظ. رتّب. وارجع للمهم.',
                                style: TextStyle(
                                    fontSize: 21, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 16),
                            TextField(
                                onChanged: (v) {
                                  _query = v;
                                  _refresh();
                                },
                                decoration: const InputDecoration(
                                    hintText: 'دوّر في بُؤجتك...',
                                    prefixIcon: Icon(Icons.search))),
                            const SizedBox(height: 10),
                            Row(children: [
                              const Text('مجموعاتك',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              TextButton.icon(
                                  onPressed: _newGroup,
                                  icon: const Icon(Icons.add),
                                  label: const Text('مجموعة جديدة'))
                            ]),
                            if (_categories.isEmpty)
                              const Card(
                                  child: Padding(
                                      padding: EdgeInsets.all(22),
                                      child: Text(
                                          'مفيش مجموعات لسه. اعمل أول مجموعة بالاسم اللي يناسبك.'))),
                            if (_categories.isNotEmpty)
                              LayoutBuilder(
                                  builder: (context, constraints) => Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: _categories
                                          .map((c) => SizedBox(
                                              width:
                                                  (constraints.maxWidth - 10) /
                                                      2,
                                              child: Card(
                                                  child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              18),
                                                      onTap: () {
                                                        setState(() =>
                                                            _category = c);
                                                        _refresh();
                                                      },
                                                      child: Padding(
                                                          padding:
                                                              const EdgeInsets
                                                                  .all(18),
                                                          child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Icon(
                                                                    Icons
                                                                        .folder_outlined,
                                                                    color: _category ==
                                                                            c
                                                                        ? BougaColors
                                                                            .gold
                                                                        : BougaColors
                                                                            .mint),
                                                                const SizedBox(
                                                                    height: 12),
                                                                Text(c,
                                                                    style: const TextStyle(
                                                                        fontWeight:
                                                                            FontWeight
                                                                                .bold,
                                                                        fontSize:
                                                                            18)),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                    '${_groupCounts[c] ?? 0} رابط',
                                                                    style: const TextStyle(
                                                                        color: BougaColors
                                                                            .muted))
                                                              ]))))))
                                          .toList())),
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                    onPressed: () {
                                      setState(() => _category = 'الكل');
                                      _refresh();
                                    },
                                    child: Text(_category == 'الكل'
                                        ? 'كل الروابط'
                                        : 'عرض كل الروابط (المحدد: $_category)'))),
                            const SizedBox(height: 14),
                            Card(
                                child: SwitchListTile(
                                    title: const Text('لم أفتحها بعد'),
                                    subtitle: const Text(
                                        'للروابط الجديدة بعد تفعيل التتبع، حالة الروابط الأقدم غير معروفة.'),
                                    value: _onlyUnopened,
                                    onChanged: (value) {
                                      setState(() => _onlyUnopened = value);
                                      _refresh();
                                    })),
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                    'التذكير لسه غير مفعّل. هنحدد معاده لما تختاره.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: BougaColors.muted))),
                            Text('المحفوظات: ${_links.length}',
                                style:
                                    const TextStyle(color: BougaColors.mint)),
                            const SizedBox(height: 8),
                            if (_links.isEmpty)
                              const Card(
                                  child: Padding(
                                      padding: EdgeInsets.all(24),
                                      child: Text(
                                          'ابدأ برابط مهم ليك.\nاضغط «إضافة رابط» أو شاركه لبُؤجة من تطبيق تاني.')))
                            else
                              ..._links.map((item) => Card(
                                      child: ListTile(
                                    onTap: () => _details(item),
                                    leading: const CircleAvatar(
                                        child: Icon(Icons.link)),
                                    title: Text(
                                        (item['title']
                                                    ?.toString()
                                                    .trim()
                                                    .isNotEmpty ??
                                                false)
                                            ? item['title'].toString()
                                            : item['url'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis),
                                    subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              '${item['category']} • ${item['kind']}'),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                              value:
                                                  ((item['progress'] as int? ??
                                                              0)
                                                          .clamp(0, 100)) /
                                                      100),
                                        ]),
                                    trailing: const Icon(Icons.chevron_left),
                                  ))),
                            const SizedBox(height: 80),
                          ])),
        ),
      );
}
