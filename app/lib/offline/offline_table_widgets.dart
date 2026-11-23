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
  late int _players = 4.clamp(widget.minPlayers, widget.maxPlayers).toInt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.title} · Offline')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: 8,
                      children: [
                        Text(
                          'Table size',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Wrap(
                          spacing: 6,
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
                                onSelected: (_) =>
                                    setState(() => _players = count),
                              ),
                          ],
                        ),
                        const Divider(height: 1),
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 14,
                          children: [
                            Text('You and ${_players - 1} CPU players'),
                            FilledButton.icon(
                              onPressed: () {
                                final count = _players;
                                Navigator.of(context)
                                    .pushReplacement<void, void>(
                                      MaterialPageRoute<void>(
                                        builder: (_) => widget.buildGame(count),
                                      ),
                                    );
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Start game'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
