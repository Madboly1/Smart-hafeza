import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';

/// Short, local paint-only reveal. No images, network, shaders or particles.
class BougaInkReveal extends StatelessWidget {
  const BougaInkReveal(
      {super.key, required this.animation, required this.child});
  final Animation<double> animation;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          final p = animation.value;
          if (p >= .999) return child!;
          return Stack(fit: StackFit.passthrough, children: [
            Positioned.fill(
                child: ClipPath(
                    clipper: BougaInkClipper((p + .13).clamp(0, 1)),
                    child: const ColoredBox(color: Color(0xFF05080B)))),
            ClipPath(clipper: BougaInkClipper(p), child: child),
          ]);
        });
  }
}

class BougaInkClipper extends CustomClipper<Path> {
  const BougaInkClipper(this.progress);
  final double progress;
  @override
  Path getClip(Size size) {
    if (progress >= .999) return Path()..addRect(Offset.zero & size);
    if (progress <= 0) return Path();
    final center = Offset(size.width * .76, size.height * .28);
    final maxRadius =
        math.sqrt(size.width * size.width + size.height * size.height) * 1.4;
    final radius = maxRadius * progress;
    final path = Path();
    for (var i = 0; i <= 96; i++) {
      final a = i / 96 * math.pi * 2;
      final r =
          radius * (1 + .08 * math.sin(a * 5) + .045 * math.sin(a * 9 + .8));
      final x = center.dx + math.cos(a) * r;
      final y = center.dy + math.sin(a) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    return path..close();
  }

  @override
  bool shouldReclip(BougaInkClipper oldClipper) =>
      oldClipper.progress != progress;
}

Route<T> bougaInkRoute<T>(WidgetBuilder builder) => PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, _, __) => builder(context),
      transitionsBuilder: (context, animation, _, child) =>
          BougaInkReveal(animation: animation, child: child),
    );

class BougaInkSwitch extends StatelessWidget {
  const BougaInkSwitch({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 420),
        reverseDuration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 420),
        layoutBuilder: (current, previous) => Stack(
            alignment: Alignment.topCenter,
            children: [...previous, if (current != null) current]),
        transitionBuilder: (child, animation) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) =>
                animation.status == AnimationStatus.reverse
                    ? child!
                    : BougaInkReveal(animation: animation, child: child!)),
        child: child,
      );
}

class BougaPress extends StatefulWidget {
  const BougaPress({super.key, required this.child});
  final Widget child;
  @override
  State<BougaPress> createState() => _BougaPressState();
}

class _BougaPressState extends State<BougaPress> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => setState(() => _down = true),
        onPointerUp: (_) => setState(() => _down = false),
        onPointerCancel: (_) => setState(() => _down = false),
        child: AnimatedScale(
            scale: _down && !MediaQuery.disableAnimationsOf(context) ? .97 : 1,
            duration: const Duration(milliseconds: 110),
            child: widget.child),
      );
}
