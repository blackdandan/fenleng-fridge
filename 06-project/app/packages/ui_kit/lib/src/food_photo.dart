import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'product_tokens.dart';

class FridgeFoodPhoto extends StatelessWidget {
  final ImageProvider image;
  final double size, scale;
  final double borderWidth;
  final String errorLabel;
  const FridgeFoodPhoto({
    super.key,
    required this.image,
    required this.size,
    required this.errorLabel,
    this.scale = 1,
    this.borderWidth = FridgeProductTokens.sizePhotoBorder,
  });
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<FridgePalette>()!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: palette.color('photoBorder'),
          width: borderWidth * scale,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.color('photoShadow'),
            offset: Offset(0, 2 * scale),
            blurRadius: 5 * scale,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: ClipOval(
        child: Image(
          image: ResizeImage.resizeIfNeeded(
            math.max(
              1,
              (size * MediaQuery.devicePixelRatioOf(context) * 2).ceil(),
            ),
            null,
            image,
          ),
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Center(
            child: Semantics(
              label: errorLabel,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: palette.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FridgeMorePhoto extends StatelessWidget {
  final double size, scale;
  final String count;
  const FridgeMorePhoto({
    super.key,
    required this.size,
    required this.count,
    this.scale = 1,
  });
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<FridgePalette>()!;
    return CustomPaint(
      foregroundPainter: _DottedCircle(
        palette.color('moreBorder'),
        FridgeProductTokens.sizeBorder * scale,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: palette.color('moreSurface'),
        ),
        child: Center(
          child: Text(
            count,
            style: TextStyle(
              color: palette.color('more'),
              fontSize: FridgeProductTokens.fontBody,
            ),
          ),
        ),
      ),
    );
  }
}

class _DottedCircle extends CustomPainter {
  final Color color;
  final double width;
  const _DottedCircle(this.color, this.width);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width;
    final bounds = Rect.fromLTWH(
      width / 2,
      width / 2,
      size.width - width,
      size.height - width,
    );
    const segments = 48;
    for (var i = 0; i < segments; i++) {
      canvas.drawArc(
        bounds,
        i * 2 * math.pi / segments,
        math.pi / segments,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DottedCircle oldDelegate) =>
      color != oldDelegate.color || width != oldDelegate.width;
}
