import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../offline/offline_table_widgets.dart';
import 'lan_room.dart';

class LanRoomSetupPage<Room extends LanRoom<Object>> extends StatefulWidget {
  const LanRoomSetupPage({
    required this.host,
    required this.minPlayers,
    required this.maxPlayers,
    required this.createRoom,
    required this.joinRoom,
    required this.buildTable,
    super.key,
  });

  final bool host;
  final int minPlayers;
  final int maxPlayers;
  final Future<Room> Function(String name, int players) createRoom;
  final Future<Room> Function(String address, String name, String code)
  joinRoom;
  final Widget Function(Room room, List<String> addresses) buildTable;

  @override
  State<LanRoomSetupPage<Room>> createState() => _LanRoomSetupPageState<Room>();
}

class _LanRoomSetupPageState<Room extends LanRoom<Object>>
    extends State<LanRoomSetupPage<Room>> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _code = TextEditingController();
  late int _players = 4.clamp(widget.minPlayers, widget.maxPlayers).toInt();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _enterRoom() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    Room? room;
    try {
      final name = _name.text.trim();
      room = widget.host
          ? await widget.createRoom(name, _players)
          : await widget.joinRoom(
              _address.text.trim(),
              name,
              _code.text.trim(),
            );
      final addresses = widget.host ? await _localAddresses() : <String>[];
      if (!mounted) {
        room.dispose();
        return;
      }
      final enteredRoom = room;
      final buildTable = widget.buildTable;
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => buildTable(enteredRoom, addresses),
        ),
      );
    } catch (error) {
      room?.dispose();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is LanRoomException
            ? error.message
            : widget.host
            ? 'Could not host. Close any existing room and try again.'
            : 'Could not connect. Check the host IP and join the same network.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final action = widget.host ? 'Host room' : 'Join room';
    return Scaffold(
      appBar: AppBar(title: Text(action)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  TextFormField(
                    controller: _name,
                    enabled: !_busy,
                    maxLength: 20,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                    validator: (value) =>
                        value!.trim().isEmpty ? 'Enter a nickname.' : null,
                  ),
                  if (widget.host && widget.minPlayers < widget.maxPlayers)
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
                            onSelected: _busy
                                ? null
                                : (_) => setState(() => _players = count),
                          ),
                      ],
                    ),
                  if (!widget.host) ...[
                    TextFormField(
                      controller: _address,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Host IP address',
                      ),
                      validator: (value) =>
                          InternetAddress.tryParse(value!.trim())?.type ==
                              InternetAddressType.IPv4
                          ? null
                          : 'Enter an IPv4 address.',
                    ),
                    TextFormField(
                      controller: _code,
                      enabled: !_busy,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      decoration: const InputDecoration(labelText: 'Room code'),
                      validator: (value) =>
                          RegExp(r'^\d{6}$').hasMatch(value!.trim())
                          ? null
                          : 'Enter the six-digit room code.',
                    ),
                  ],
                  if (_error case final error?)
                    Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _enterRoom,
                    child: Text(_busy ? 'Connecting…' : action),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<List<String>> _localAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    final wifi = interfaces.where(
      (interface) => RegExp(r'^(wlan|wifi|ap)').hasMatch(interface.name),
    );
    return [
      for (final interface in wifi.isEmpty ? interfaces : wifi)
        for (final address in interface.addresses) address.address,
    ];
  } on SocketException {
    return [];
  }
}

class LanRoomLobby extends StatelessWidget {
  const LanRoomLobby({required this.room, required this.addresses, super.key});

  final LanRoom<Object> room;
  final List<String> addresses;

  @override
  Widget build(BuildContext context) {
    final players = (room.view['players'] as List).cast<Map<String, dynamic>>();
    final seat = room.view['seat'] as int;
    final ready = players[seat]['ready'] == true;
    final canStart = players.every((player) => player['ready'] == true);
    final occupied = players.where((player) => player['name'] != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        if (room.isHost)
          SelectableText(
            'Room code ${room.roomCode}   •   '
            'Host IP ${addresses.isEmpty ? 'Use the host’s network settings' : addresses.join(' or ')}',
          ),
        Text('$occupied / ${players.length} seated. All seats must be ready.'),
        OfflineSeats(
          names: [
            for (var index = 0; index < players.length; index++)
              index == seat
                  ? 'You'
                  : players[index]['name'] as String? ?? 'Open seat',
          ],
          status: [
            for (final player in players)
              if (player['name'] == null)
                'Waiting'
              else if (player['ready'] == true)
                'Ready'
              else
                'Not ready',
          ],
        ),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => room.send('ready', {'ready': !ready}),
              child: Text(ready ? 'Not ready' : 'Ready'),
            ),
            if (room.isHost)
              FilledButton(
                onPressed: canStart ? () => room.send('start') : null,
                child: const Text('Start match'),
              ),
          ],
        ),
      ],
    );
  }
}
