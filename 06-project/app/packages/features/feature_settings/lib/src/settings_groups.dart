part of 'settings_screen.dart';

extension _SettingsGroups on _SettingsScreenState {
  Widget _section(BuildContext context, String label, {bool first = false}) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return Padding(
      padding: EdgeInsets.only(
        top: l.d(
          first
              ? FridgeProductTokens.spaceSettingsFirstSection
              : FridgeProductTokens.spaceSettingsSection,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: l.font(FridgeProductTokens.fontSecondary),
          height: 1.25,
          color: p.color('settingsSection'),
        ),
      ),
    );
  }

  Widget _group(BuildContext context, List<Widget> children) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    return Container(
      decoration: BoxDecoration(
        color: p.color('surface'),
        borderRadius: BorderRadius.circular(
          l.d(FridgeProductTokens.radiusSettingsCard),
        ),
        border: Border.all(
          color: p.border,
          width: l.d(FridgeProductTokens.sizeBorder),
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: l.d(FridgeProductTokens.spaceSettingsCard),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: l.d(FridgeProductTokens.sizeBorder),
                thickness: l.d(FridgeProductTokens.sizeBorder),
                color: p.border,
              ),
            children[i],
          ],
        ],
      ),
    );
  }

  Widget _link(
    BuildContext context,
    String key,
    VoidCallback action, {
    String? subtitle,
    String? value,
    bool legal = false,
  }) {
    final l = FridgeLayout.of(context);
    final p = Theme.of(context).extension<FridgePalette>()!;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text(key),
          style: TextStyle(
            fontSize: l.font(
              legal
                  ? FridgeProductTokens.fontSettingsLegal
                  : FridgeProductTokens.fontLabel,
            ),
            height: 1.3,
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: l.d(FridgeProductTokens.spacePhotoCaptionTop)),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: l.font(FridgeProductTokens.fontMetadata),
              height: 1.2,
              color: p.muted,
            ),
          ),
        ],
      ],
    );
    return InkWell(
      key: ValueKey('settings-$key'),
      onTap: locked ? null : action,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: l.d(
            legal
                ? FridgeProductTokens.sizeSettingsLegalRow
                : FridgeProductTokens.sizeSettingsRow,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: l.d(FridgeProductTokens.spaceSettingsCard),
          ),
          child: Row(
            children: [
              Expanded(child: title),
              SizedBox(width: l.d(FridgeProductTokens.spaceSmall)),
              if (value != null) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: l.d(FridgeProductTokens.sizeSettingsValueMax),
                  ),
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: l.font(FridgeProductTokens.fontSecondary),
                      height: 1.3,
                      color: p.muted,
                    ),
                  ),
                ),
                SizedBox(width: l.d(FridgeProductTokens.spaceSmall)),
              ],
              ExcludeSemantics(
                child: Icon(
                  Icons.north_east,
                  size: l.font(FridgeProductTokens.fontLabel),
                  color: p.color('ink'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
