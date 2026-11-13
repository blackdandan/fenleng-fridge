import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'product_tokens.dart';
import 'design_layout.dart';
import 'design_icon.dart';

class FridgePage extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;
  final bool back;
  final String? count;
  final double? headerTop;
  final double titleGap;
  final FridgeIconName backIcon;
  final bool backIconOriginalColors;
  final FontWeight? titleWeight;
  final double titleHeight;
  const FridgePage({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
    this.back = true,
    this.count,
    this.headerTop,
    this.titleGap = 0,
    this.backIcon = FridgeIconName.back,
    this.backIconOriginalColors = false,
    this.titleWeight,
    this.titleHeight = 1.4,
  });
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value:
        (Theme.of(context).brightness == Brightness.dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Theme.of(
                context,
              ).scaffoldBackgroundColor,
            ),
    child: Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: FridgeSpace.maxWidth),
            child: LayoutBuilder(
              builder: (context, constraints) => FridgeLayout(
                scale: constraints.maxWidth / 430,
                child: Builder(
                  builder: (context) {
                    final layout = FridgeLayout.of(context);
                    final hasBack = back && Navigator.of(context).canPop();
                    return Column(
                      children: [
                        SizedBox(
                          height: layout.d(
                            headerTop ??
                                (back
                                    ? FridgeProductTokens.spaceBackHeaderTop
                                    : FridgeProductTokens.spaceHeaderTop),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.only(
                            start: layout.d(
                              hasBack ? 10 : FridgeProductTokens.spacePage,
                            ),
                            end: layout.d(FridgeProductTokens.spacePage),
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: layout.d(
                                FridgeProductTokens.sizeCircle,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (hasBack)
                                  SizedBox(
                                    width: 48,
                                    height: 48,
                                    child: IconButton(
                                      tooltip: MaterialLocalizations.of(
                                        context,
                                      ).backButtonTooltip,
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: FridgeIcon(
                                        backIcon,
                                        scale: layout.scale,
                                        originalColors: backIconOriginalColors,
                                      ),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minHeight: 48,
                                        minWidth: 48,
                                      ),
                                    ),
                                  ),
                                if (hasBack && titleGap != 0)
                                  SizedBox(width: layout.d(titleGap)),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                      fontSize: layout.font(
                                        back
                                            ? FridgeProductTokens.fontTitle
                                            : FridgeProductTokens.fontHome,
                                      ),
                                      fontWeight:
                                          titleWeight ??
                                          (back
                                              ? FontWeight.w400
                                              : FontWeight.w600),
                                      height: titleHeight,
                                      letterSpacing: back ? 0 : .5,
                                    ),
                                  ),
                                ),
                                if (count != null) ...[
                                  SizedBox(width: layout.d(8)),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxWidth: layout.d(120),
                                    ),
                                    child: Text(
                                      count!,
                                      style: TextStyle(
                                        letterSpacing: 0,
                                        fontSize: layout.font(
                                          FridgeProductTokens.fontSecondary,
                                        ),
                                        height: 1.4,
                                        color: Theme.of(
                                          context,
                                        ).extension<FridgePalette>()!.muted,
                                      ),
                                    ),
                                  ),
                                ],
                                if (actions.isNotEmpty) ...[
                                  SizedBox(width: layout.d(4)),
                                  Transform.translate(
                                    offset: Offset(layout.d(2), 0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        for (
                                          var i = 0;
                                          i < actions.length;
                                          i++
                                        ) ...[
                                          if (i > 0)
                                            SizedBox(width: layout.d(4)),
                                          actions[i],
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: layout.d(
                                FridgeProductTokens.spacePage,
                              ),
                            ),
                            child: child,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class FridgeHeaderIcon extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onPressed;
  const FridgeHeaderIcon({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });
  @override
  Widget build(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final diameter = layout.d(FridgeProductTokens.sizeCircle);
    return SizedBox(
      width: math.max(44, layout.d(FridgeProductTokens.sizeTouch)),
      height: math.max(44, layout.d(FridgeProductTokens.sizeTouch)),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkResponse(
              onTap: onPressed,
              radius: diameter / 2,
              child: Center(
                child: Container(
                  width: diameter,
                  height: diameter,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).extension<FridgePalette>()!.border,
                      width: layout.d(FridgeProductTokens.sizeBorder),
                    ),
                  ),
                  child: Center(child: icon),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FridgeEmpty extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  const FridgeEmpty({super.key, required this.label, this.onPressed});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FridgeSpace.large),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.kitchen_outlined,
            size: FridgeSpace.touch,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: FridgeSpace.medium),
          if (onPressed == null)
            Text(label, textAlign: TextAlign.center)
          else
            TextButton(
              onPressed: onPressed,
              child: Text(label, textAlign: TextAlign.center),
            ),
        ],
      ),
    ),
  );
}
