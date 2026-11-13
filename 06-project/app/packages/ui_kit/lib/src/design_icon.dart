import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum FridgeIconName {
  bell,
  settings,
  cold,
  frozen,
  pantry,
  back,
  camera,
  cameraBack,
  album,
  chevronDown,
  calendar,
  editorChevron,
  settingsCold,
  settingsFrozen,
  settingsPantry,
  clock,
}

/// Original exported SVGs. Intrinsic geometry and aspect ratios stay intact.
class FridgeIcon extends StatelessWidget {
  final FridgeIconName name;
  final double scale;
  final Color? color;
  final bool originalColors;
  const FridgeIcon(
    this.name, {
    super.key,
    this.scale = 1,
    this.color,
    this.originalColors = false,
  });
  @override
  Widget build(BuildContext context) {
    final (file, width, height) = switch (name) {
      FridgeIconName.cold ||
      FridgeIconName.frozen ||
      FridgeIconName.pantry => (name.name, 15.0, 15.0),
      FridgeIconName.back => ('back', 20.0, 20.0),
      FridgeIconName.camera => ('camera', 18.0, 18.0),
      FridgeIconName.cameraBack => ('camera-back', 22.0, 22.0),
      FridgeIconName.chevronDown => ('chevron-down', 10.0, 6.0),
      FridgeIconName.calendar => ('calendar', 11.6667, 12.5),
      FridgeIconName.editorChevron => ('editor-chevron', 10.0, 6.0),
      FridgeIconName.settingsCold => ('settings-cold', 16.0, 16.0),
      FridgeIconName.settingsFrozen => ('settings-frozen', 16.0, 16.0),
      FridgeIconName.settingsPantry => ('settings-pantry', 16.0, 16.0),
      FridgeIconName.clock => ('clock', 11.375, 11.375),
      _ => (name.name, 22.0, 22.0),
    };
    return SvgPicture.asset(
      'assets/icons/$file.svg',
      package: 'fridge_ui_kit',
      width: width * scale,
      height: height * scale,
      excludeFromSemantics: true,
      matchTextDirection:
          name == FridgeIconName.back || name == FridgeIconName.cameraBack,
      colorFilter: color != null
          ? ColorFilter.mode(color!, BlendMode.srcIn)
          : originalColors
          ? null
          : Theme.of(context).brightness == Brightness.dark
          ? ColorFilter.mode(
              Theme.of(context).colorScheme.onSurface,
              BlendMode.srcIn,
            )
          : null,
    );
  }
}
