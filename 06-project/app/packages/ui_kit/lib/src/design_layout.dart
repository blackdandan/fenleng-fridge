import 'dart:math' as math;
import 'package:flutter/widgets.dart';

/// Geometry follows the approved 430px reference. Text never shrinks below its
/// readable logical size, and system text scaling remains fully active.
class FridgeLayout extends InheritedWidget {
  final double scale;
  const FridgeLayout({super.key, required this.scale, required super.child});
  static FridgeLayout of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FridgeLayout>()!;
  double d(double value) => value * scale;
  double font(double value) => value * math.max(1, scale);
  @override
  bool updateShouldNotify(FridgeLayout oldWidget) => scale != oldWidget.scale;
}
