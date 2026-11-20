import 'package:flutter/services.dart';
import '../../settings/data/reminder_service.dart';
import '../../../core/theme/bouga_motion.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../links/data/embedded_content.dart';
import '../../links/presentation/saved_link_card.dart';
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
  bool _oldestFirst = false;
  int _tab = 0;
  Map<String, int> _groupCounts = {};
  String _query = '';
  String _category = 'الكل';
  bool _loading = true;
  String? _startupError;
  DateTime? _lastExitBack;

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
      try {
        await ReminderService().initialize();
      } catch (_) {/* Reminder failure never blocks the library. */}
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
    var links = await _repo!
        .list(query: _query, category: _category, oldestFirst: _oldestFirst);
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

  Future<void> _add({String? sharedUrl, String? group}) async {
    final url = TextEditingController(text: sharedUrl);
    final title = TextEditingController();
    final category = TextEditingController(
        text: group ?? (_category == 'الكل' ? '' : _category));
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
                                  bougaInkRoute<void>((_) =>
                                      EmbeddedContentPage(
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

  Future<void> _openGroup(String group) async {
    await Navigator.of(context)
        .push(bougaInkRoute<void>((context) => _GroupLinksPage(
              group: group,
              load: (oldestFirst) =>
                  _repo!.list(category: group, oldestFirst: oldestFirst),
              add: () => _add(group: group),
              details: _details,
              open: _openContent,
            )));
    await _refresh();
  }

  Widget _groups() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('مجموعاتك',
            style: TextStyle(fontSize: 29, fontWeight: FontWeight.bold)),
        const SizedBox(height: 9),
        const Text('بتنشئها وبتسمّيها بنفسك.',
            style: TextStyle(color: BougaColors.muted)),
        const SizedBox(height: 20),
        if (_categories.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text('مفيش مجموعات لسه. اعمل أول مجموعة على مزاجك.',
                  style: TextStyle(color: BougaColors.muted))),
        ..._categories.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: BougaPress(
                child: Material(
                    elevation: 5,
                    shadowColor: Colors.black54,
                    color: BougaColors.surface,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                        onTap: () => _openGroup(c),
                        borderRadius: BorderRadius.circular(22),
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                      color: BougaColors.mint
                                          .withValues(alpha: .12),
                                      borderRadius: BorderRadius.circular(16)),
                                  child: const Icon(Icons.folder_outlined,
                                      color: BougaColors.mint)),
                              const SizedBox(width: 16),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(c,
                                        style: const TextStyle(
                                            fontSize: 19,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 5),
                                    Text('${_groupCounts[c] ?? 0} رابط',
                                        style: const TextStyle(
                                            color: BougaColors.muted,
                                            fontSize: 13))
                                  ])),
                              const Icon(Icons.chevron_left,
                                  textDirection: TextDirection.ltr),
                            ]))))))),
        OutlinedButton.icon(
            onPressed: _newGroup,
            icon: const Icon(Icons.add),
            label: const Padding(
                padding: EdgeInsets.all(17),
                child: Text('مجموعة جديدة', style: TextStyle(fontSize: 17)))),
      ]);

  Future<void> _openContent(Map<String, Object?> item) async {
    final raw = item['url']?.toString() ?? '';
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !['https', 'http'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return;
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        uri.scheme == 'https') {
      final embedded =
          EmbeddedContent.fromUrl(raw) ?? EmbeddedContent(uri, 'قراءة الرابط');
      await _db!.markOpened(item['id'].toString());
      if (!mounted) return;
      await Navigator.of(context).push(bougaInkRoute<void>(
          (_) => EmbeddedContentPage(content: embedded, originalUrl: raw)));
    } else {
      if (await _linkOpener.open(raw) == LinkOpenResult.opened) {
        await _db!.markOpened(item['id'].toString());
      }
    }
    await _refresh();
  }

  Widget _linkRow(Map<String, Object?> item) => SavedLinkCard(
      item: item,
      onOpen: () => _openContent(item),
      onEdit: () => _details(item));

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        final now = DateTime.now();
        if (_lastExitBack != null &&
            now.difference(_lastExitBack!) < const Duration(seconds: 2)) {
          SystemNavigator.pop();
        } else {
          _lastExitBack = now;
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('اضغط رجوع مرة كمان للخروج'),
              duration: Duration(seconds: 2)));
        }
      },
      child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
                toolbarHeight: 88,
                automaticallyImplyLeading: false,
                title: Row(children: [
                  ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Image.asset('assets/icon/bouga-icon-source.jpg',
                          width: 48, height: 48)),
                  const SizedBox(width: 12),
                  const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('بُؤجة',
                            style: TextStyle(
                                fontSize: 30,
                                color: BougaColors.mint,
                                fontWeight: FontWeight.bold)),
                        SizedBox(height: 3),
                        Text('مساحة لأفكارك',
                            style: TextStyle(
                                fontSize: 12, color: BougaColors.muted))
                      ]),
                ]),
                actions: [
                  IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: _loading
                          ? null
                          : () => Navigator.of(context).push(
                              bougaInkRoute<void>((_) => SettingsPage(
                                  onImportBackup: _importBackup,
                                  onExportBackup: _exportBackup))),
                      icon: const Icon(Icons.settings_outlined)),
                  const SizedBox(width: 12)
                ]),
            bottomNavigationBar: Container(
                decoration: const BoxDecoration(
                    border:
                        Border(top: BorderSide(color: BougaColors.outline))),
                child: SafeArea(
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                        child: Row(children: [
                          _navItem(0, Icons.grid_view_rounded, 'الرئيسية'),
                          _navItem(1, Icons.folder_outlined, 'المجموعات'),
                        ])))),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _startupError != null
                    ? Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                                'حصلت مشكلة في فتح بُؤجة:\n$_startupError')))
                    : BougaInkSwitch(
                        child: RefreshIndicator(
                            key: ValueKey(_tab),
                            onRefresh: _refresh,
                            child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(24, 14, 24, 30),
                                children: [
                                  if (_tab == 1)
                                    _groups()
                                  else ...[
                                    TextField(
                                        onChanged: (v) {
                                          _query = v;
                                          _refresh();
                                        },
                                        decoration: InputDecoration(
                                            hintText: 'بتدور على إيه؟',
                                            prefixIcon:
                                                const Icon(Icons.search),
                                            contentPadding:
                                                const EdgeInsets.all(18),
                                            border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                borderSide: BorderSide.none),
                                            enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                borderSide: BorderSide.none))),
                                    if (_links.isEmpty &&
                                        _query.isEmpty &&
                                        !_onlyUnopened) ...[
                                      const SizedBox(height: 66),
                                      Center(
                                          child: Container(
                                              padding: const EdgeInsets.all(24),
                                              decoration: BoxDecoration(
                                                  color: BougaColors.mint
                                                      .withValues(alpha: .12),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          28)),
                                              child: const Icon(Icons.link,
                                                  size: 40,
                                                  color: BougaColors.mint))),
                                      const SizedBox(height: 26),
                                      const Text('حاجات تستاهل ترجع لها.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              fontSize: 27,
                                              fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 15),
                                      const Text(
                                          'احفظ أول رابط ليك، أو شاركه لبُؤجة من أي تطبيق.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                              color: BougaColors.muted,
                                              fontSize: 16,
                                              height: 1.6)),
                                      const SizedBox(height: 44),
                                    ] else ...[
                                      const SizedBox(height: 18),
                                      FilledButton.icon(
                                          onPressed: _add,
                                          icon: const Icon(Icons.add),
                                          label: const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text('إضافة رابط',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold)))),
                                      const SizedBox(height: 20),
                                      Row(children: [
                                        const Expanded(
                                            child: Text('روابطك المحفوظة',
                                                style: TextStyle(
                                                    fontSize: 21,
                                                    fontWeight:
                                                        FontWeight.bold))),
                                        FilterChip(
                                            label: const Text('لسه مفتحتهاش'),
                                            selected: _onlyUnopened,
                                            onSelected: (v) {
                                              setState(() => _onlyUnopened = v);
                                              _refresh();
                                            })
                                      ]),
                                      _DateSort(
                                          oldestFirst: _oldestFirst,
                                          onChanged: (v) {
                                            setState(() => _oldestFirst = v);
                                            _refresh();
                                          }),
                                      if (_onlyUnopened)
                                        const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 10),
                                            child: Text(
                                                'حالة الروابط الأقدم غير معروفة. التصفية للروابط الجديدة.',
                                                style: TextStyle(
                                                    color: BougaColors.muted,
                                                    fontSize: 12))),
                                      if (_links.isEmpty)
                                        const Padding(
                                            padding: EdgeInsets.all(24),
                                            child: Text('مفيش روابط مطابقة.',
                                                textAlign: TextAlign.center)),
                                      ..._links.map(_linkRow),
                                      const SizedBox(height: 20),
                                    ],
                                    if (_links.isEmpty &&
                                        _query.isEmpty &&
                                        !_onlyUnopened)
                                      FilledButton.icon(
                                          onPressed: _add,
                                          icon: const Icon(Icons.add),
                                          label: const Padding(
                                              padding: EdgeInsets.all(16),
                                              child: Text('إضافة رابط',
                                                  style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold)))),
                                  ],
                                ]))),
          )));

  Widget _navItem(int index, IconData icon, String label) => Expanded(
      child: BougaPress(
          child: TextButton(
              onPressed: () {
                setState(() {
                  _tab = index;
                  _category = 'الكل';
                });
                if (index == 0) _refresh();
              },
              child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(icon,
                        color: _tab == index
                            ? BougaColors.mint
                            : BougaColors.muted),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                            color: _tab == index
                                ? BougaColors.mint
                                : BougaColors.muted,
                            fontSize: 12))
                  ])))));
}

class _GroupLinksPage extends StatefulWidget {
  const _GroupLinksPage(
      {required this.group,
      required this.load,
      required this.add,
      required this.details,
      required this.open});
  final String group;
  final Future<List<Map<String, Object?>>> Function(bool) load;
  final Future<void> Function() add;
  final Future<void> Function(Map<String, Object?>) details;
  final Future<void> Function(Map<String, Object?>) open;
  @override
  State<_GroupLinksPage> createState() => _GroupLinksPageState();
}

class _GroupLinksPageState extends State<_GroupLinksPage> {
  List<Map<String, Object?>> _items = [];
  String _query = '';
  bool _oldestFirst = false;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final items = await widget.load(_oldestFirst);
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items
        .where((i) => '${i['title']} ${i['url']} ${i['note']}'
            .toLowerCase()
            .contains(_query.toLowerCase()))
        .toList();
    return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(title: Text(widget.group)),
          bottomNavigationBar: SafeArea(
              child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: FilledButton.icon(
                      onPressed: () async {
                        await widget.add();
                        await _refresh();
                      },
                      icon: const Icon(Icons.add),
                      label: const Padding(
                          padding: EdgeInsets.all(15),
                          child: Text('إضافة رابط للمجموعة'))))),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(padding: const EdgeInsets.all(24), children: [
                    Text('${_items.length} رابط',
                        style: const TextStyle(color: BougaColors.muted)),
                    const SizedBox(height: 18),
                    TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: const InputDecoration(
                            hintText: 'دوّر جوه المجموعة',
                            prefixIcon: Icon(Icons.search))),
                    const SizedBox(height: 20),
                    _DateSort(
                        oldestFirst: _oldestFirst,
                        onChanged: (v) {
                          setState(() => _oldestFirst = v);
                          _refresh();
                        }),
                    if (items.isEmpty)
                      const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('مفيش روابط هنا لسه.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: BougaColors.muted))),
                    ...items.map((item) => SavedLinkCard(
                        item: item,
                        onOpen: () async {
                          await widget.open(item);
                          await _refresh();
                        },
                        onEdit: () async {
                          await widget.details(item);
                          await _refresh();
                        })),
                  ])),
        ));
  }
}

class _DateSort extends StatelessWidget {
  const _DateSort({required this.oldestFirst, required this.onChanged});
  final bool oldestFirst;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        DropdownButton<bool>(
            value: oldestFirst,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.sort, size: 18),
            items: const [
              DropdownMenuItem(value: false, child: Text('الأحدث أولًا')),
              DropdownMenuItem(value: true, child: Text('الأقدم أولًا'))
            ],
            onChanged: (value) {
              if (value != null) onChanged(value);
            }),
        const Text(
            'حسب تاريخ الحفظ المسجّل؛ القديم المستورد حسب تاريخه المتاح.',
            style: TextStyle(fontSize: 11, color: BougaColors.muted)),
      ]);
}
