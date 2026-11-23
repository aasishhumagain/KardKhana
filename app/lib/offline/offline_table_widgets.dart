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
