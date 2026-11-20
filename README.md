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

The Android prototype opens in landscape and shows each game's player limit
in the catalog and on its detail screen. Call Break requires exactly four
players to start. Teen Patti and Marriage each allow up to five players.
Gameplay and private rooms are planned for later milestones.

Next, agree on one rule variant per game and record worked scoring examples.
Then prototype a phone-hosted room on two physical Android devices with internet
access disabled and use Call Break to exercise the shared room and game interfaces.
