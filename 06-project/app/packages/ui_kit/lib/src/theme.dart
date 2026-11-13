import 'package:flutter/material.dart';
import 'package:fenleng_theme/fenleng_theme.dart';
import 'package:fenleng_tokens/fenleng_tokens.dart';
import 'product_tokens.dart';

/// Approved product palette mapped once onto the shared Fenleng theme.
class FridgePalette extends ThemeExtension<FridgePalette> {
  final Map<String, Color> colors;
  const FridgePalette(this.colors);
  static const light = FridgePalette(FridgeProductTokens.light);
  static const dark = FridgePalette(FridgeProductTokens.dark);
  Color color(String key) => colors[key]!;
  Color get cold => color('cold');
  Color get frozen => color('frozen');
  Color get pantry => color('pantry');
  Color get muted => color('muted');
  Color get border => color('line');
  @override
  FridgePalette copyWith({Map<String, Color>? colors}) =>
      FridgePalette(colors ?? this.colors);
  @override
  FridgePalette lerp(covariant FridgePalette? other, double t) => other == null
      ? this
      : FridgePalette({
          for (final entry in colors.entries)
            entry.key: Color.lerp(entry.value, other.colors[entry.key], t)!,
        });
}

abstract final class FridgeSpace {
  static const small = 8.0, medium = 16.0, page = 24.0, large = 32.0;
  static const radius = 18.0, touch = 48.0, maxWidth = 600.0;
}

ThemeData fridgeCameraTheme() {
  const product = FridgeProductTokens.light;
  final palette = FridgePalette({
    ...FridgeProductTokens.dark,
    'page': product['camera']!,
    'ink': product['cameraInk']!,
    'muted': product['cameraCaption']!,
  });
  final base = fridgeTheme(dark: true);
  return base.copyWith(
    scaffoldBackgroundColor: palette.color('page'),
    colorScheme: base.colorScheme.copyWith(onSurface: palette.color('ink')),
    extensions: [
      ...base.extensions.values.where((value) => value is! FridgePalette),
      palette,
    ],
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: palette.color('page'),
    ),
  );
}

ThemeData fridgeTheme({bool dark = false}) {
  final base = dark
      ? FenlengThemes.dark(FenlengThemeId.forest)
      : FenlengThemes.light(FenlengThemeId.forest);
  final palette = dark ? FridgePalette.dark : FridgePalette.light;
  final scheme = base.colorScheme.copyWith(
    primary: palette.color('primary'),
    onPrimary: palette.color('onPrimary'),
    surface: palette.color('surface'),
    onSurface: palette.color('ink'),
    error: palette.color('danger'),
    outline: palette.color('line'),
  );
  return base.copyWith(
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.color('page'),
    extensions: [
      ...base.extensions.values,
      dark ? FridgePalette.dark : FridgePalette.light,
    ],
    appBarTheme: AppBarTheme(
      backgroundColor: palette.color('page'),
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: scheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(FridgeSpace.touch, FridgeSpace.touch),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(FridgeSpace.touch, FridgeSpace.touch),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      insetPadding: const EdgeInsets.all(FridgeSpace.medium),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FridgeSpace.radius),
      ),
    ),
  );
}
