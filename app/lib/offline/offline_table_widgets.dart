import 'package:material_ui/material_ui.dart';

String offlineSeatName(int seat) => seat == 0 ? 'You' : 'CPU $seat';

class OfflineGameSetup extends StatefulWidget {
  const OfflineGameSetup({
    required this.title,
    required this.minPlayers,
    required this.maxPlayers,
    required this.buildGame,
    super.key,
  });

  final String title;
  final int minPlayers;
  final int maxPlayers;
  final Widget Function(int) buildGame;

  @override
  State<OfflineGameSetup> createState() => _OfflineGameSetupState();
}

class _OfflineGameSetupState extends State<OfflineGameSetup> {
  int _players = 4;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · Offline')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Table size', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (
                  var count = widget.minPlayers;
                  count <= widget.maxPlayers;
                  count++
                )
                  ChoiceChip(
                    label: Text('$count players'),
                    selected: _players == count,
                    onSelected: (_) => setState(() => _players = count),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text('You and ${_players - 1} CPU players'),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: () {
                  final count = _players;
                  Navigator.of(context).pushReplacement<void, void>(
                    MaterialPageRoute<void>(
                      builder: (_) => widget.buildGame(count),
                    ),
                  );
                },
                child: const Text('Start game'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OfflineSeats extends StatelessWidget {
  const OfflineSeats({
    required this.status,
    this.activeSeat,
    this.names,
    super.key,
  });

  final List<String> status;
  final int? activeSeat;
  final List<String>? names;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      spacing: 6,
      children: [
        for (var seat = 0; seat < status.length; seat++)
          Expanded(
            child: Card.outlined(
              color: seat == activeSeat
                  ? theme.colorScheme.primaryContainer
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      names?[seat] ?? offlineSeatName(seat),
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(status[seat], style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class OfflineCard extends StatelessWidget {
  const OfflineCard(
    this.label, {
    this.red = false,
    this.selected = false,
    this.onPressed,
    super.key,
  });

  final String label;
  final bool red;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = red ? const Color(0xFF9C233B) : Colors.black87;
    final fill = selected ? colors.primaryContainer : Colors.white;
    if (onPressed != null) {
      return OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(46, 44),
          foregroundColor: ink,
          backgroundColor: fill,
          side: BorderSide(color: selected ? colors.primary : colors.outline),
        ),
        onPressed: onPressed,
        child: Text(label),
      );
    }
    return Card.outlined(
      color: fill,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(label, style: TextStyle(color: ink)),
      ),
    );
  }
}
