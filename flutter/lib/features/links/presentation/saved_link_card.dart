import '../../../core/theme/bouga_motion.dart';
import 'package:material_ui/material_ui.dart';
import '../data/link_preview_service.dart';
import '../../../core/theme/bouga_tokens.dart';

class SavedLinkCard extends StatelessWidget {
  const SavedLinkCard(
      {super.key,
      required this.item,
      required this.onOpen,
      required this.onEdit,
      this.previewService});
  final Map<String, Object?> item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final LinkPreviewService? previewService;
  static final _previews = LinkPreviewService();
  @override
  Widget build(BuildContext context) {
    final url = item['url']?.toString() ?? '';
    final manualTitle = item['title']?.toString().trim() ?? '';
    final host = Uri.tryParse(url)?.host ?? '';
    final video = host == 'youtube.com' ||
        host.endsWith('.youtube.com') ||
        host == 'youtu.be';
    return FutureBuilder<LinkPreview?>(
        future: (previewService ?? _previews).load(url),
        builder: (context, snapshot) {
          final title = manualTitle.isNotEmpty
              ? manualTitle
              : snapshot.data?.title ?? url;
          final image = snapshot.data?.image;
          final fallback = Container(
              color: BougaColors.mint.withValues(alpha: .12),
              child: Icon(video ? Icons.play_arrow_outlined : Icons.link,
                  color: BougaColors.mint, size: 30));
          return BougaPress(
              child: InkWell(
                  onTap: onOpen,
                  child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom: BorderSide(color: BougaColors.outline))),
                      child: Row(children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: SizedBox(
                                width: 96,
                                height: 65,
                                child: image == null
                                    ? fallback
                                    : Image.network(image.toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            fallback))),
                        const SizedBox(width: 13),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Text(host,
                                  textDirection: TextDirection.ltr,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: BougaColors.muted, fontSize: 12)),
                              if ((item['category']?.toString() ?? '')
                                  .isNotEmpty)
                                Text(item['category'].toString(),
                                    style: const TextStyle(
                                        color: BougaColors.muted,
                                        fontSize: 12)),
                            ])),
                        IconButton(
                            tooltip: 'تعديل الرابط',
                            onPressed: onEdit,
                            icon: const Icon(Icons.more_vert)),
                      ]))));
        });
  }
}
