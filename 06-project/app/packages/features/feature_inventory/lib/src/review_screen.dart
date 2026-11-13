import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

part 'review_card.dart';

class ReviewScreen extends StatefulWidget {
  final String? title;
  final List<FoodRecord> foods;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final Future<void> Function(FoodRecord, Remaining) onConfirm;
  final ValueChanged<FoodRecord> onOpen;
  final bool completedReminder;
  const ReviewScreen({
    super.key,
    this.title,
    required this.foods,
    required this.strings,
    required this.photo,
    required this.onConfirm,
    required this.onOpen,
    this.completedReminder = false,
  });
  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  bool busy = false, failed = false;
  Future<void> confirm(FoodRecord food, Remaining remaining) async {
    if (busy) return;
    setState(() {
      busy = true;
      failed = false;
    });
    try {
      await widget.onConfirm(food, remaining);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FridgePage(
    title: widget.title ?? widget.strings.text('organize'),
    count: widget.strings.format('recordCount', {'count': widget.foods.length}),
    child: Builder(
      builder: (context) {
        final layout = FridgeLayout.of(context);
        final palette = Theme.of(context).extension<FridgePalette>()!;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(
                  top: layout.d(FridgeProductTokens.spaceIntroTop),
                ),
                child: Text(
                  widget.strings.text('reviewHint'),
                  style: TextStyle(
                    letterSpacing: 0,
                    fontSize: layout.font(FridgeProductTokens.fontSecondary),
                    height: 1.8,
                    color: palette.muted,
                  ),
                ),
              ),
            ),
            if (failed)
              SliverToBoxAdapter(
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    widget.strings.text('error'),
                    style: TextStyle(color: palette.color('danger')),
                  ),
                ),
              ),
            if (widget.foods.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: layout.d(FridgeSpace.large),
                  ),
                  child: Column(
                    children: [
                      Text(
                        widget.strings.text(
                          widget.completedReminder
                              ? 'allHandled'
                              : 'emptyReview',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: layout.d(FridgeSpace.medium)),
                      FridgeAction(
                        label: widget.strings.text('back'),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ],
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.only(
                top: layout.d(FridgeProductTokens.spaceActionTop),
                bottom: layout.d(FridgeProductTokens.spaceBottom),
              ),
              sliver: SliverList.separated(
                itemCount: widget.foods.length,
                separatorBuilder: (_, _) => SizedBox(
                  height: layout.d(FridgeProductTokens.spaceReviewCards),
                ),
                itemBuilder: (context, index) => _ReviewCard(
                  food: widget.foods[index],
                  strings: widget.strings,
                  photo: widget.photo,
                  busy: busy,
                  onConfirm: confirm,
                  onOpen: widget.onOpen,
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}
