import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fridge_core/fridge_core.dart';
import 'package:fridge_ui_kit/fridge_ui_kit.dart';

class HistoryScreen extends StatefulWidget {
  final InventoryState state;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final ValueChanged<FoodRecord> onOpen;
  final Future<void> Function(FoodRecord) onRestore;
  const HistoryScreen({
    super.key,
    required this.state,
    required this.strings,
    required this.photo,
    required this.onOpen,
    required this.onRestore,
  });
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool history = true, failed = false;
  String? restoring;
  Future<void> restore(FoodRecord food) async {
    if (restoring != null) return;
    setState(() {
      restoring = food.id;
      failed = false;
    });
    try {
      await widget.onRestore(food);
    } catch (_) {
      if (mounted) setState(() => failed = true);
    } finally {
      if (mounted) setState(() => restoring = null);
    }
  }

  @override
  Widget build(BuildContext context) => FridgePage(
    title: widget.strings.text('foodRecords'),
    headerTop: FridgeProductTokens.spaceHeaderTop,
    titleGap: FridgeProductTokens.spaceHistoryTitleGap,
    child: Builder(
      builder: (context) {
        final layout = FridgeLayout.of(context);
        final palette = Theme.of(context).extension<FridgePalette>()!;
        final strings = widget.strings;
        final foods = [
          ...(history ? widget.state.history : widget.state.active),
        ]..sort((a, b) => a.id.compareTo(b.id));
        return DefaultTextStyle.merge(
          style: const TextStyle(letterSpacing: 0),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: layout.d(FridgeProductTokens.spaceHistoryTabs),
                  ),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: layout.d(FridgeProductTokens.spaceTiny),
                    ),
                    decoration: BoxDecoration(
                      color: palette.color('dialogClose'),
                      borderRadius: BorderRadius.circular(
                        layout.d(FridgeProductTokens.radiusTabs),
                      ),
                    ),
                    child: Row(
                      children: [
                        for (final tab in [false, true])
                          Expanded(
                            child: Semantics(
                              selected: history == tab,
                              child: InkWell(
                                key: ValueKey(
                                  tab ? 'history-tab' : 'active-tab',
                                ),
                                onTap: restoring != null
                                    ? null
                                    : () => setState(() => history = tab),
                                borderRadius: BorderRadius.circular(
                                  layout.d(FridgeProductTokens.radiusTabs),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: layout.d(
                                      FridgeProductTokens.spaceTiny,
                                    ),
                                  ),
                                  child: Container(
                                    constraints: BoxConstraints(
                                      minHeight: math.max(
                                        44 -
                                            layout.d(
                                                  FridgeProductTokens.spaceTiny,
                                                ) *
                                                2,
                                        layout.d(
                                          FridgeProductTokens.sizeTabSegment,
                                        ),
                                      ),
                                    ),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: layout.d(
                                        FridgeProductTokens.spaceTabSide,
                                      ),
                                      vertical: layout.d(
                                        FridgeProductTokens.spaceSmall,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    decoration: history == tab
                                        ? BoxDecoration(
                                            color: palette.color('surface'),
                                            borderRadius: BorderRadius.circular(
                                              layout.d(
                                                FridgeProductTokens.spaceSmall,
                                              ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: palette.color(
                                                  'tabShadow',
                                                ),
                                                offset: const Offset(0, 2),
                                                blurRadius: 5,
                                              ),
                                            ],
                                          )
                                        : null,
                                    child: Text(
                                      strings.format(
                                        tab
                                            ? 'historyRecords'
                                            : 'activeRecords',
                                        {
                                          'count':
                                              '${tab ? widget.state.history.length : widget.state.active.length}',
                                        },
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: layout.font(
                                          FridgeProductTokens.fontSecondary,
                                        ),
                                        height: 1.3,
                                        color: palette.color(
                                          history == tab ? 'primary' : 'tabInk',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: layout.d(FridgeProductTokens.spacePage),
                  ),
                  child: Text(
                    strings.text(history ? 'historyHint' : 'recordsHint'),
                    style: TextStyle(
                      fontSize: layout.font(FridgeProductTokens.fontMetadata),
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
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: layout.d(FridgeProductTokens.spaceHistoryCards),
                      ),
                      child: Text(
                        strings.text('error'),
                        style: TextStyle(color: palette.color('danger')),
                      ),
                    ),
                  ),
                ),
              if (foods.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(
                        layout.d(FridgeProductTokens.spacePage),
                      ),
                      child: Text(
                        strings.text(history ? 'emptyHistory' : 'empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: palette.muted),
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: layout.d(FridgeProductTokens.spaceHistoryCardsTop),
                    bottom: layout.d(FridgeProductTokens.spaceBottom),
                  ),
                  sliver: SliverList.separated(
                    itemCount: foods.length,
                    separatorBuilder: (_, _) => SizedBox(
                      height: layout.d(FridgeProductTokens.spaceHistoryCards),
                    ),
                    itemBuilder: (context, index) => _HistoryCard(
                      food: foods[index],
                      strings: strings,
                      photo: widget.photo,
                      busy: restoring != null,
                      onOpen: widget.onOpen,
                      onRestore: restore,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  final FoodRecord food;
  final FridgeStrings strings;
  final ImageProvider Function(String) photo;
  final bool busy;
  final ValueChanged<FoodRecord> onOpen;
  final Future<void> Function(FoodRecord) onRestore;
  const _HistoryCard({
    required this.food,
    required this.strings,
    required this.photo,
    required this.busy,
    required this.onOpen,
    required this.onRestore,
  });
  @override
  Widget build(BuildContext context) {
    final layout = FridgeLayout.of(context);
    final palette = Theme.of(context).extension<FridgePalette>()!;
    final details = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: InkWell(
        onTap: busy ? null : () => onOpen(food),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: layout.d(FridgeProductTokens.spacePhotoCaptionTop),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '#${food.id}',
                      style: TextStyle(
                        fontSize: layout.font(FridgeProductTokens.fontLabel),
                        color: palette.color('ink'),
                      ),
                    ),
                    TextSpan(
                      text: ' · ${strings.text(food.zone.name)}',
                      style: TextStyle(
                        fontSize: layout.font(FridgeProductTokens.fontMetadata),
                        color: palette.muted,
                      ),
                    ),
                  ],
                ),
                style: const TextStyle(height: 1.3),
              ),
              SizedBox(height: layout.d(FridgeProductTokens.spaceTabSide)),
              Text(
                '${strings.format('addedCaption', {'date': FridgeDates.short(context, strings.locale, food.addedAt)})} · ${strings.text(food.active ? food.remaining.name : 'removed')}',
                style: TextStyle(
                  fontSize: layout.font(FridgeProductTokens.fontMetadata),
                  height: 1.3,
                  color: palette.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final button = TextButton(
      onPressed: busy ? null : () => onRestore(food),
      style: TextButton.styleFrom(
        alignment: AlignmentDirectional.centerEnd,
        minimumSize: const Size(44, 44),
        padding: EdgeInsets.symmetric(
          horizontal: layout.d(FridgeProductTokens.spaceChoiceHorizontal),
          vertical: layout.d(FridgeProductTokens.spaceSmall),
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: palette.color('primary'),
        textStyle: TextStyle(
          fontSize: layout.font(FridgeProductTokens.fontSecondary),
          letterSpacing: 0,
          fontWeight: FontWeight.w400,
        ),
      ),
      child: Text(strings.text('restore'), textAlign: TextAlign.center),
    );
    return Container(
      key: ValueKey('history-card-${food.id}'),
      padding: EdgeInsets.all(layout.d(FridgeProductTokens.spaceHistoryCard)),
      decoration: BoxDecoration(
        color: palette.color('surface'),
        borderRadius: BorderRadius.circular(
          layout.d(FridgeProductTokens.spaceHistoryCard),
        ),
        border: Border.all(color: palette.border, width: layout.d(.8)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: busy ? null : () => onOpen(food),
            customBorder: const CircleBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              child: Center(
                child: FridgeFoodPhoto(
                  image: photo(food.photoPath),
                  size: layout.d(FridgeProductTokens.sizeHistoryPhoto),
                  scale: layout.scale,
                  errorLabel: strings.text('error'),
                ),
              ),
            ),
          ),
          SizedBox(width: layout.d(FridgeProductTokens.spaceHistoryCard)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 170 ||
                    MediaQuery.textScalerOf(context).scale(12) > 16;
                if (food.active) return details;
                if (stacked)
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      details,
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: button,
                      ),
                    ],
                  );
                return Row(
                  children: [
                    Expanded(child: details),
                    SizedBox(width: layout.d(FridgeProductTokens.spaceSmall)),
                    button,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
