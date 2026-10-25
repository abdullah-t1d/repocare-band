import 'package:flutter/material.dart';

import '../../../../core/utils/motion.dart';

/// Heart icon that pulses once for every real beat.
///
/// The pulse is triggered by a change of [beatCount] (one per `B` line from
/// the band), never by a timer, so it shows exactly what the sensor detected.
/// The pulse gets shorter as the heart rate rises. With "reduce motion" on,
/// the icon stays still.
class BeatingHeart extends StatefulWidget {
  const BeatingHeart({
    required this.beatCount,
    required this.color,
    this.bpm,
    this.size = 26,
    super.key,
  });

  /// Key of the scaled icon, for tests.
  static const Key iconKey = ValueKey('beating-heart-icon');

  /// Peak size of a pulse.
  static const double peakScale = 1.28;

  final int beatCount;
  final Color color;
  final double? bpm;
  final double size;

  /// Length of one pulse: 45 % of the beat interval, kept between 180 and
  /// 520 ms so it stays readable at any heart rate.
  static Duration pulseDuration(double? bpm) {
    if (bpm == null || bpm <= 0) return const Duration(milliseconds: 420);
    final ms = (60000 / bpm * 0.45).round().clamp(180, 520);
    return Duration(milliseconds: ms);
  }

  @override
  State<BeatingHeart> createState() => _BeatingHeartState();
}

class _BeatingHeartState extends State<BeatingHeart> with SingleTickerProviderStateMixin {
  static final Animatable<double> _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: BeatingHeart.peakScale).chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: BeatingHeart.peakScale, end: 1.0).chain(CurveTween(curve: Curves.easeIn)),
      weight: 70,
    ),
  ]);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: BeatingHeart.pulseDuration(widget.bpm),
  );

  @override
  void didUpdateWidget(BeatingHeart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.beatCount != oldWidget.beatCount) _pulse();
  }

  void _pulse() {
    if (context.reduceMotion) return;
    _controller.duration = BeatingHeart.pulseDuration(widget.bpm);
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.favorite, color: widget.color, size: widget.size);
    return SizedBox.square(
      dimension: widget.size * 1.4,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final pulsing = t > 0 && t < 1;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // Soft ring that expands and fades with each beat.
              if (pulsing)
                Transform.scale(
                  scale: 1 + t * 1.1,
                  child: Opacity(
                    opacity: (1 - t) * 0.35,
                    child: Icon(Icons.favorite, color: widget.color, size: widget.size),
                  ),
                ),
              Transform.scale(
                key: BeatingHeart.iconKey,
                scale: _scale.evaluate(_controller),
                child: child,
              ),
            ],
          );
        },
        child: icon,
      ),
    );
  }
}
