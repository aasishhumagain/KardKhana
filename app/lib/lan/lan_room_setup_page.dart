import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../ui/table_widgets.dart';
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
    final theme = Theme.of(context);
    final nickname = TextFormField(
      controller: _name,
      enabled: !_busy,
      maxLength: 20,
      textCapitalization: TextCapitalization.words,
      decoration: _field('Nickname', Icons.person_outline),
      validator: (value) => value!.trim().isEmpty ? 'Enter a nickname.' : null,
    );
    final address = TextFormField(
      controller: _address,
      enabled: !_busy,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: _field('Host IP address', Icons.wifi_rounded),
      validator: (value) =>
          InternetAddress.tryParse(value!.trim())?.type ==
              InternetAddressType.IPv4
          ? null
          : 'Enter an IPv4 address.',
    );
    final code = TextFormField(
      controller: _code,
      enabled: !_busy,
      keyboardType: TextInputType.number,
      maxLength: 6,
      decoration: _field('Room code', Icons.pin_outlined),
      validator: (value) => RegExp(r'^\d{6}$').hasMatch(value!.trim())
          ? null
          : 'Enter the six-digit room code.',
    );
    return Scaffold(
      appBar: AppBar(title: Text(action)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card.outlined(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 9,
                        children: [
                          const Text(
                            'Use the same Wi-Fi or hotspot as the other players.',
                          ),
                          nickname,
                          if (widget.host &&
                              widget.minPlayers < widget.maxPlayers)
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
                                    onSelected: _busy
                                        ? null
                                        : (_) =>
                                              setState(() => _players = count),
                                  ),
                              ],
                            ),
                          if (!widget.host)
                            LayoutBuilder(
                              builder: (context, limits) =>
                                  limits.maxWidth >= 385
                                  ? Row(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(flex: 3, child: address),
                                        Expanded(flex: 2, child: code),
                                      ],
                                    )
                                  : Column(
                                      spacing: 8,
                                      children: [address, code],
                                    ),
                            ),
                          if (_error case final error?)
                            Text(
                              error,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.icon(
                              onPressed: _busy ? null : _enterRoom,
                              icon: Icon(
                                widget.host
                                    ? Icons.add_rounded
                                    : Icons.login_rounded,
                              ),
                              label: Text(_busy ? 'Connecting…' : action),
                            ),
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
      ),
    );
  }

  InputDecoration _field(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 19),
    counterText: '',
    isDense: true,
    filled: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
  );
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
    final theme = Theme.of(context);
    final players = (room.view['players'] as List).cast<Map<String, dynamic>>();
    final seat = room.view['seat'] as int;
    final ready = players[seat]['ready'] == true;
    final canStart = players.every((player) => player['ready'] == true);
    final occupied = players.where((player) => player['name'] != null).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        if (room.isHost)
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Wrap(
                spacing: 24,
                runSpacing: 7,
                children: [
                  _RoomDetail(label: 'Room code', value: room.roomCode ?? ''),
                  _RoomDetail(
                    label: 'Host IP',
                    value: addresses.isEmpty
                        ? 'Check the host’s network settings'
                        : addresses.join(' · '),
                  ),
                ],
              ),
            ),
          ),
        Text(
          '$occupied of ${players.length} seated · Everyone must be ready',
          style: theme.textTheme.bodySmall,
        ),
        TableSeats(
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
          spacing: 8,
          runSpacing: 4,
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

class _RoomDetail extends StatelessWidget {
  const _RoomDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: style.labelMedium),
        SelectableText(
          value,
          style: style.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
