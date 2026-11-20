import 'dart:io';
import 'dart:ui';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/bouga_tokens.dart';

class BougaTourStore {
  BougaTourStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationDocumentsDirectory;
  final Future<Directory> Function() _directory;
  Future<File> get _file async =>
      File('${(await _directory()).path}/bouga-tour-v1.seen');
  Future<bool> get seen async => (await _file).exists();
  Future<void> complete() async {
    await (await _file).writeAsString('seen', flush: true);
  }
}

/// Blocks all background input, so spotlighting can never save/delete a link.
Future<bool> showBougaTourStep(BuildContext context,
    {required GlobalKey target,
    required String title,
    required String text,
    required int step,
    required int total,
    bool last = false}) async {
  final targetContext = target.currentContext;
  if (targetContext == null || !context.mounted) return true;
  await Scrollable.ensureVisible(targetContext,
      alignment: .25, duration: Duration.zero);
  await WidgetsBinding.instance.endOfFrame;
  if (!context.mounted || target.currentContext == null) return false;
  return await showGeneralDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.transparent,
          barrierLabel: 'جولة بؤجة',
          transitionDuration: Duration.zero,
          pageBuilder: (dialogContext, _, __) => _TourStep(
              target: target,
              title: title,
              text: text,
              step: step,
              total: total,
              last: last)) ??
      false;
}

class _TourStep extends StatelessWidget {
  const _TourStep(
      {required this.target,
      required this.title,
      required this.text,
      required this.step,
      required this.total,
      required this.last});
  final GlobalKey target;
  final String title;
  final String text;
  final int step;
  final int total;
  final bool last;
  @override
  Widget build(BuildContext context) {
    final box = target.currentContext?.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final rect = box != null && box.hasSize
        ? (box.localToGlobal(Offset.zero, ancestor: overlay) & box.size)
            .inflate(7)
        : Rect.zero;
    final size = MediaQuery.sizeOf(context);
    final safe = MediaQuery.paddingOf(context);
    final spaceAbove = rect.top - safe.top - 36;
    final spaceBelow = size.height - safe.bottom - rect.bottom - 36;
    final above = spaceAbove > spaceBelow;
    final panelMaxHeight =
        (above ? spaceAbove : spaceBelow).clamp(120.0, size.height * .44);
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) Navigator.of(context).pop(false);
        },
        child: Directionality(
            textDirection: TextDirection.rtl,
            child: Material(
                type: MaterialType.transparency,
                child: Stack(children: [
                  Positioned.fill(
                      child: CustomPaint(painter: _Spotlight(rect))),
                  const Positioned.fill(
                      child: ModalBarrier(
                          dismissible: false, color: Colors.transparent)),
                  Positioned(
                      left: 18,
                      right: 18,
                      top: above ? safe.top + 28 : null,
                      bottom: above ? null : safe.bottom + 28,
                      child: Semantics(
                          scopesRoute: true,
                          explicitChildNodes: true,
                          namesRoute: true,
                          label: title,
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: BackdropFilter(
                                  filter:
                                      ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                      constraints: BoxConstraints(
                                          maxHeight: panelMaxHeight),
                                      decoration: BoxDecoration(
                                          color: const Color(0xCF202930),
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          border: Border.all(
                                              color: BougaColors.gold
                                                  .withValues(alpha: .55))),
                                      padding: const EdgeInsets.all(20),
                                      child: SingleChildScrollView(
                                          child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.stretch,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                            Text('$step / $total',
                                                textDirection:
                                                    TextDirection.ltr,
                                                style: const TextStyle(
                                                    color: BougaColors.gold,
                                                    fontSize: 12)),
                                            const SizedBox(height: 8),
                                            Text(title,
                                                style: const TextStyle(
                                                    color: BougaColors.text,
                                                    fontSize: 21,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            const SizedBox(height: 10),
                                            Text(text,
                                                style: const TextStyle(
                                                    color: BougaColors.text,
                                                    fontSize: 15,
                                                    height: 1.5)),
                                            const SizedBox(height: 18),
                                            Wrap(
                                                alignment:
                                                    WrapAlignment.spaceBetween,
                                                spacing: 12,
                                                runSpacing: 8,
                                                children: [
                                                  TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child: const Text(
                                                          'تخطّي الجولة',
                                                          style: TextStyle(
                                                              color: BougaColors
                                                                  .muted))),
                                                  FilledButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child: Text(last
                                                          ? 'إنهاء'
                                                          : 'التالي')),
                                                ]),
                                          ]))))))),
                ]))));
  }
}

class _Spotlight extends CustomPainter {
  const _Spotlight(this.rect);
  final Rect rect;
  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(rect, const Radius.circular(18));
    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(hole);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: .72));
    canvas.drawRRect(
        hole,
        Paint()
          ..color = BougaColors.gold
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_Spotlight oldDelegate) => oldDelegate.rect != rect;
}
