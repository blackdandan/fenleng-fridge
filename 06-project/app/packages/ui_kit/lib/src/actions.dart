import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'design_icon.dart';
import 'design_layout.dart';
import 'product_tokens.dart';
import 'theme.dart';

class FridgeAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool secondary;
  final FridgeIconName? icon;
  final double? fontSize;
  final double? minHeight;
  const FridgeAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.secondary = false,
    this.icon,
    this.fontSize,
    this.minHeight,
  });
  @override
  Widget build(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final ink = palette.color(secondary ? 'secondaryInk' : 'onPrimary');
    final style = TextButton.styleFrom(
      backgroundColor: palette.color(secondary ? 'surface' : 'primary'),
      foregroundColor: ink,
      minimumSize: Size(
        0,
        math.max(
          44,
          layout.d(minHeight ?? FridgeProductTokens.sizeActionHeight),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: layout.d(17),
        vertical: layout.d(12),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      side: secondary
          ? BorderSide(
              color: palette.border,
              width: layout.d(FridgeProductTokens.sizeBorder),
            )
          : BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          layout.d(FridgeProductTokens.radiusControl),
        ),
      ),
      textStyle: TextStyle(
        letterSpacing: 0,
        fontSize: layout.font(fontSize ?? FridgeProductTokens.fontLabel),
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
    );
    return TextButton(
      onPressed: onPressed,
      style: style,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            FridgeIcon(icon!, scale: layout.scale, color: ink),
            SizedBox(width: layout.d(7)),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class FridgeChoice extends StatelessWidget {
  final String label;
  final bool selected, destructive;
  final double? fontSize;
  final VoidCallback? onPressed;
  const FridgeChoice({
    super.key,
    required this.label,
    required this.onPressed,
    this.selected = false,
    this.destructive = false,
    this.fontSize,
  });
  @override
  Widget build(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final role = destructive
        ? 'gone'
        : selected
        ? 'selected'
        : 'choice';
    return Semantics(
      selected: selected,
      child: Opacity(
        opacity: onPressed == null ? 0.5 : 1.0,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            backgroundColor: palette.color('${role}Surface'),
            foregroundColor: palette.color('${role}Ink'),
            side: BorderSide(
              color: palette.color('${role}Line'),
              width: layout.d(FridgeProductTokens.sizeBorder),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                layout.d(FridgeProductTokens.radiusChoice),
              ),
            ),
            minimumSize: Size(
              0,
              math.max(44, layout.d(FridgeProductTokens.sizeChoiceHeight)),
            ),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            padding: EdgeInsets.symmetric(
              horizontal: layout.d(FridgeProductTokens.spaceChoiceHorizontal),
              vertical: layout.d(FridgeProductTokens.spaceChoiceVertical),
            ),
            textStyle: TextStyle(
              letterSpacing: 0,
              fontSize: layout.font(fontSize ?? FridgeProductTokens.fontChoice),
              height: 1.3,
              fontWeight: FontWeight.w400,
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
