import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/bouga_motion.dart';
import '../../../core/theme/bouga_tokens.dart';
import '../data/link_preview_service.dart';

class SavedLinkCard extends StatelessWidget {
  const SavedLinkCard({
    super.key,
    required this.item,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    this.previewService,
  });

  final Map<String, Object?> item;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
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
        final title =
            manualTitle.isNotEmpty ? manualTitle : snapshot.data?.title ?? url;
        final image = snapshot.data?.image;
        final fallback = Container(
          color: BougaColors.mint.withValues(alpha: .12),
          child: Icon(
            video ? Icons.play_arrow_outlined : Icons.link,
            color: BougaColors.mint,
            size: 30,
          ),
        );

        return BougaPress(
          child: InkWell(
            onTap: onOpen,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: BougaColors.outline),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: SizedBox(
                      width: 96,
                      height: 65,
                      child: image == null
                          ? fallback
                          : Image.network(
                              image.toString(),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => fallback,
                            ),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          host,
                          textDirection: TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: BougaColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        if ((item['category']?.toString() ?? '').isNotEmpty)
                          Text(
                            item['category'].toString(),
                            style: const TextStyle(
                              color: BougaColors.muted,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'المزيد',
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) async {
                      if (action == 'open') {
                        onOpen();
                      } else if (action == 'copy') {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('اتنسخ الرابط')),
                          );
                        }
                      } else if (action == 'edit') {
                        onEdit();
                      } else if (action == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'open',
                        child: Row(
                          children: [
                            Icon(Icons.open_in_new, size: 19),
                            SizedBox(width: 10),
                            Text('فتح الرابط'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 19),
                            SizedBox(width: 10),
                            Text('نسخ الرابط'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 19),
                            SizedBox(width: 10),
                            Text('تعديل'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 19,
                              color: BougaColors.danger,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'حذف',
                              style: TextStyle(color: BougaColors.danger),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
