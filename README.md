# KardKhana

KardKhana is a Kathmandu University COMP 311 project for playing Call Break,
Teen Patti, and Marriage with friends on Android. The planned release uses
private rooms over a shared Wi-Fi network or phone hotspot, or over the
internet through a Go WebSocket server.

## Run the Android app

Use Flutter 3.50.1 and complete the Android setup. Connect an Android phone with
USB debugging enabled or start an Android emulator.
[Flutter installation](https://docs.flutter.dev/install) ·
[Android setup](https://docs.flutter.dev/platform-integration/android/setup)

```sh
flutter doctor
cd app
flutter pub get
flutter run
```

Run `flutter analyze` and `flutter test` from `app/` to check the source and
the catalog navigation.

## Current milestone

Choose **Call Break → Play offline** to play on one phone with three CPU
opponents. No network connection or room code is needed. The CPU players
estimate their bids from their hands and choose from the engine's legal moves.

Call Break is playable in landscape with four people on the same Wi-Fi network
or phone hotspot. One player opens **Call Break → Host room**, enters a nickname,
and shares the host IP and six-digit room code. The other three use **Join room**
and enter those details. The host can start when all four seats are ready.

Each match has five rounds. Players bid from 1 to 13 and can lead any suit.
Follow the led suit if possible, otherwise play a spade if you have one. Among
eligible cards, play one that would win the trick if you can. The trick winner
leads next. A bid of 4 earns 4.0 for four tricks, 4.2 for six tricks, and −4.0
for three tricks. The highest total wins and equal totals share the win.
[Call Break rules reference](https://bhoos.games/blog/call-break-rules-how-to-play-callbreak/)

The host validates turns and sends each player their own hand. The room stays
open while the host keeps the table open. A player leaving mid-match ends that
match. Teen Patti and Marriage each have a five-player cap and are at the
catalog stage. Internet play is planned for the Go backend.
