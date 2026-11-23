import 'package:material_ui/material_ui.dart';

const tablePadding = EdgeInsets.fromLTRB(16, 10, 16, 14);

class CardTray extends StatelessWidget {
  const CardTray({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFF547367)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF315A4C), Color(0xFF213F37)],
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
      child: child,
    ),
  );
}

class TableStatus extends StatelessWidget {
  const TableStatus({
    required this.progress,
    required this.status,
    required this.yourTurn,
    this.complete = false,
    super.key,
  });

  final String progress;
  final String status;
  final bool yourTurn;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final emphasized = yourTurn || complete;
    final ink = emphasized ? colors.onPrimaryContainer : colors.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized ? colors.primaryContainer : colors.surfaceContainer,
        border: Border.all(
          color: emphasized ? colors.primary : colors.outlineVariant,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          spacing: 10,
          children: [
            Icon(
              complete
                  ? Icons.emoji_events_outlined
                  : yourTurn
                  ? Icons.play_arrow_rounded
                  : Icons.hourglass_bottom_rounded,
              size: 19,
              color: ink,
            ),
            Expanded(
              child: Text(
                status,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: ink,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                progress,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium?.copyWith(color: ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TableSeats extends StatelessWidget {
  const TableSeats({
    required this.names,
    required this.status,
    this.activeSeat,
    super.key,
  });

  final List<String> names;
  final List<String> status;
  final int? activeSeat;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      spacing: 6,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var seat = 0; seat < status.length; seat++)
          Expanded(
            child: _TableSeat(
              name: names[seat],
              status: status[seat],
              active: seat == activeSeat,
            ),
          ),
      ],
    ),
  );
}

class _TableSeat extends StatelessWidget {
  const _TableSeat({
    required this.name,
    required this.status,
    required this.active,
  });

  final String name;
  final String status;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: active ? colors.primaryContainer : colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? colors.primary : colors.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 3,
          children: [
            Row(
              spacing: 5,
              children: [
                if (active)
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: colors.primary,
                    semanticLabel: 'Current turn',
                  ),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: active
                          ? colors.onPrimaryContainer
                          : colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: active
                    ? colors.onPrimaryContainer
                    : colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
