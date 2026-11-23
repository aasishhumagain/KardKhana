import 'package:material_ui/material_ui.dart';

enum TableActionTone { primary, secondary, caution }

class TableAction extends StatelessWidget {
  const TableAction({
    required this.label,
    required this.onPressed,
    this.icon,
    this.tone = TableActionTone.secondary,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final TableActionTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(label, textAlign: TextAlign.center);
    final content = icon == null
        ? text
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Icon(icon, size: 16),
              Flexible(child: text),
            ],
          );
    final textStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final padding = EdgeInsets.symmetric(
      horizontal: icon == null ? 6 : 10,
      vertical: 8,
    );
    final style = FilledButton.styleFrom(
      minimumSize: const Size(44, 44),
      padding: padding,
      textStyle: textStyle,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return switch (tone) {
      TableActionTone.primary => FilledButton(
        onPressed: onPressed,
        style: style,
        child: content,
      ),
      TableActionTone.secondary => FilledButton.tonal(
        onPressed: onPressed,
        style: style,
        child: content,
      ),
      TableActionTone.caution => OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          minimumSize: const Size(44, 44),
          padding: padding,
          textStyle: textStyle,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: content,
      ),
    };
  }
}

class TableActionBar extends StatelessWidget {
  const TableActionBar({
    required this.actions,
    this.scrollHorizontally = false,
    super.key,
  });

  final List<Widget> actions;
  final bool scrollHorizontally;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const padding = EdgeInsets.fromLTRB(10, 3, 10, 4);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: scrollHorizontally
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: padding,
              child: Row(spacing: 3, children: actions),
            )
          : Padding(
              padding: padding,
              child: Wrap(spacing: 6, runSpacing: 4, children: actions),
            ),
    );
  }
}
