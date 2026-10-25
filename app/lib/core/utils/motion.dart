import 'package:flutter/widgets.dart';

/// Honours the operating system's "reduce motion" setting.
extension MotionX on BuildContext {
  /// The user asked for less motion: no pulsing, no looping animations.
  bool get reduceMotion => MediaQuery.maybeDisableAnimationsOf(this) ?? false;

  /// [duration], or zero when motion is reduced.
  Duration motion(Duration duration) => reduceMotion ? Duration.zero : duration;
}
