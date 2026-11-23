import 'package:material_ui/material_ui.dart';

const tablePadding = EdgeInsets.fromLTRB(10, 6, 10, 8);

const tableFelt = RadialGradient(
  center: Alignment(0, -.24),
  radius: 1.22,
  colors: [Color(0xFF284E41), Color(0xFF122A23)],
);

class TableBoard extends StatelessWidget {
  const TableBoard({required this.active, required this.child, super.key});

  final bool active;
  final Widget child;

  static final _colors =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFDDB66D),
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFF0CD8D),
        onPrimary: const Color(0xFF29210F),
        primaryContainer: const Color(0xFF404633),
        onPrimaryContainer: const Color(0xFFFFE0A7),
        surface: const Color(0xFF19332A),
        surfaceContainerLowest: const Color(0xFF142B24),
        surfaceContainerLow: const Color(0xFF173128),
        surfaceContainer: const Color(0xFF234237),
        surfaceContainerHigh: const Color(0xFF2B4F43),
        secondaryContainer: const Color(0xFF33584B),
        onSecondaryContainer: const Color(0xFFF6F0E1),
        onSurface: const Color(0xFFF6F0E1),
        onSurfaceVariant: const Color(0xFFC1D1C6),
        outline: const Color(0xFF839C8D),
        outlineVariant: const Color(0xFF436759),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = active ? _colors : theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(gradient: active ? tableFelt : null),
      child: Theme(
        data: active
            ? theme.copyWith(
                colorScheme: colors,
                textTheme: theme.textTheme.apply(
                  bodyColor: colors.onSurface,
                  displayColor: colors.onSurface,
                ),
              )
            : theme,
        child: DefaultTextStyle.merge(
          style: TextStyle(color: colors.onSurface),
          child: child,
        ),
      ),
    );
  }
}

class CardTray extends StatelessWidget {
  const CardTray({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: colors.surfaceContainerLowest.withValues(alpha: .76),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: child,
      ),
    );
  }
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
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(3, 0, 3, 3),
        child: Row(
          spacing: 7,
          children: [
            Icon(
              complete
                  ? Icons.emoji_events_outlined
                  : yourTurn
                  ? Icons.play_arrow_rounded
                  : Icons.hourglass_bottom_rounded,
              size: 16,
              color: emphasized ? colors.primary : colors.onSurfaceVariant,
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
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                progress,
                textAlign: TextAlign.end,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
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
    this.statusLines = 1,
    super.key,
  });

  final List<String> names;
  final List<String> status;
  final int? activeSeat;
  final int statusLines;

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
              statusLines: statusLines,
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
    required this.statusLines,
  });

  final String name;
  final String status;
  final bool active;
  final int statusLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Tooltip(
      message: '$name · $status',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: active ? colors.primaryContainer : colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active
                ? colors.primary.withValues(alpha: .64)
                : colors.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 1,
            children: [
              Row(
                spacing: 5,
                children: [
                  if (active)
                    Icon(
                      Icons.circle,
                      size: 6,
                      color: colors.primary,
                      semanticLabel: 'Current turn',
                    ),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
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
                maxLines: statusLines,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: active
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
