import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/bouga_tokens.dart';
import '../../legacy_import/data/bouga_database.dart';
import '../../links/data/bouga_links_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  BougaDatabase? _db;
  BougaLinksRepository? _repo;
  List<Map<String, Object?>> _links = [];
  List<String> _categories = ['أخرى'];
  String _query = '';
  String _category = 'الكل';
  bool _loading = true;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      _db = await BougaDatabase.open();
      _repo = BougaLinksRepository(_db!);
      await _refresh();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    if (_repo == null) return;
    final links = await _repo!.list(query: _query, category: _category);
    final categories = await _repo!.categories();
    if (mounted) setState(() { _links = links; _categories = categories; });
  }

  @override
  void dispose() { _db?.close(); super.dispose(); }

  Future<void> _importBackup() async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final bytes = picked.files.single.bytes;
      if (bytes == null) throw const FormatException('تعذر قراءة ملف النسخة الاحتياطية.');
      final report = await _db!.importLegacyJson(utf8.decode(bytes));
      await _refresh();
      if (!mounted) return;
      final message = report.skippedAsDuplicate
          ? 'النسخة دي مستوردة بالفعل، مفيش حاجة اتكررت.'
          : 'تم استيراد ${report.linkCount} رابط و${report.categoryCount} تصنيف بنجاح.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } on FormatException catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ملف النسخة الاحتياطية غير صالح: ${error.message}')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر استيراد النسخة الاحتياطية: $error')),
      );
    }
  }

  Future<void> _add() async {
    final url = TextEditingController();
    final title = TextEditingController();
    final category = TextEditingController(text: 'أخرى');
    final form = GlobalKey<FormState>();
    final save = await showDialog<bool>(context: context, builder: (context) => AlertDialog(
      title: const Text('إضافة رابط'),
      content: Form(key: form, child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: url, keyboardType: TextInputType.url, decoration: const InputDecoration(labelText: 'الرابط'), validator: (v) {
          final parsed = Uri.tryParse(v?.trim() ?? '');
          return parsed != null && parsed.hasAuthority && (parsed.scheme == 'https' || parsed.scheme == 'http') ? null : 'اكتب رابط صحيح يبدأ بـ https://';
        }),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان (اختياري)')),
        TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        FilledButton(onPressed: () { if (form.currentState!.validate()) Navigator.pop(context, true); }, child: const Text('حفظ')),
      ],
    ));
    if (save == true) {
      final added = await _repo!.add(url: url.text, title: title.text, category: category.text.trim().isEmpty ? 'أخرى' : category.text.trim(), kind: 'رابط');
      await _refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(added == 0 ? 'الرابط محفوظ بالفعل' : 'اتحفظ في بُؤجة')));
    }
    url.dispose(); title.dispose(); category.dispose();
  }

  Future<void> _details(Map<String, Object?> item) async {
    final id = item['id'].toString();
    final title = TextEditingController(text: item['title']?.toString() ?? '');
    final category = TextEditingController(text: item['category']?.toString() ?? 'أخرى');
    final note = TextEditingController(text: item['note']?.toString() ?? '');
    var progress = (item['progress'] as int? ?? 0).clamp(0, 100);
    final remove = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true,
      builder: (context) => StatefulBuilder(builder: (context, modalSet) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 24),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(item['url'].toString(), textDirection: TextDirection.ltr, maxLines: 2, overflow: TextOverflow.ellipsis),
          TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان')),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
          TextField(controller: note, maxLines: 3, decoration: const InputDecoration(labelText: 'ملاحظات')),
          Text('التقدم: ' + progress.toString() + '%'),
          Slider(value: progress.toDouble(), min: 0, max: 100, divisions: 20, onChanged: (v) => modalSet(() => progress = v.round())),
          FilledButton(onPressed: () async {
            await _repo!.update(id: id, title: title.text, category: category.text.trim().isEmpty ? 'أخرى' : category.text.trim(), note: note.text, progress: progress);
            if (context.mounted) Navigator.pop(context, false);
          }, child: const Text('حفظ التعديلات')),
          TextButton.icon(onPressed: () => Navigator.pop(context, true), icon: const Icon(Icons.delete_outline, color: BougaColors.danger), label: const Text('حذف الرابط')),
        ])),
      )));
    if (remove == true) await _repo!.delete(id);
    await _refresh();
    title.dispose(); category.dispose(); note.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      appBar: AppBar(actions: [IconButton(tooltip: 'استيراد نسخة احتياطية', onPressed: _loading ? null : _importBackup, icon: const Icon(Icons.backup_outlined))], title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('BOUGA', style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.w800)),
        Text('كل اللي يهمك.. في بُؤجة واحدة.', style: TextStyle(fontSize: 11, color: BougaColors.muted)),
      ])),
      floatingActionButton: FloatingActionButton.extended(onPressed: _loading ? null : _add, icon: const Icon(Icons.add_link), label: const Text('إضافة رابط')),
      body: _loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _refresh, child: ListView(padding: const EdgeInsets.all(16), children: [
        const Text('مساحتك الخاصة للمحتوى', style: TextStyle(color: BougaColors.mint)),
        const SizedBox(height: 8),
        const Text('خلي المهم دايمًا في متناول إيدك.', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        TextField(onChanged: (v) { _query = v; _refresh(); }, decoration: const InputDecoration(hintText: 'دوّر في بُؤجتك...', prefixIcon: Icon(Icons.search))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: ['الكل', ..._categories].map((c) => ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) { setState(() => _category = c); _refresh(); })).toList()),
        const SizedBox(height: 12),
        Text('المحفوظات: ' + _links.length.toString(), style: const TextStyle(color: BougaColors.mint)),
        const SizedBox(height: 8),
        if (_links.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(24), child: Text('بُؤجتك لسه فاضية.. احفظ أول رابط مهم عندك.')))
        else ..._links.map((item) => Card(child: ListTile(
          onTap: () => _details(item),
          leading: const CircleAvatar(child: Icon(Icons.link)),
          title: Text((item['title']?.toString().trim().isNotEmpty ?? false) ? item['title'].toString() : item['url'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['category'].toString() + ' • ' + item['kind'].toString()),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: ((item['progress'] as int? ?? 0).clamp(0, 100)) / 100),
          ]),
          trailing: const Icon(Icons.chevron_left),
        ))),
        const SizedBox(height: 80),
      ])),
    ),
  );
}
