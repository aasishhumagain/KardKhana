# KardKhana

KardKhana is a Kathmandu University COMP 311 project for playing Call Break,
Teen Patti, and Marriage with friends on Android. The planned release uses
private rooms over a shared Wi-Fi network or phone hotspot, or over the
internet through a Go WebSocket server.

## Run the Android app

On Windows, open the repository root in VS Code. Run **Emulator** from the
Command Palette (**Ctrl+Shift+P**) and select your Android virtual phone.
KardKhana builds and opens automatically after the phone boots. The workspace
starts the background task when opened as a trusted folder. Reload the VS Code
window once if it was already open when you added this setup.
[Android iOS Emulator extension](https://marketplace.visualstudio.com/items?itemName=DiemasMichiels.emulate)

This workflow uses the standalone Android Emulator, a virtual device, and
Android SDK Platform-Tools on Windows. The **KardKhana: Run on Android
Emulator** task uses Node.js and the Flutter/Android toolchain in Ubuntu WSL
to build the current source. Set `KARDKHANA_AVD` to target a specific virtual
phone.

Install the VS Code Flutter extension, which also installs Dart support.
[Flutter in VS Code](https://docs.flutter.dev/tools/vs-code)

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

Run `flutter analyze` and `flutter test` from `app/` to check the source,
navigation, and gameplay rules.

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
match.

**Teen Patti** supports tables of three to five offline or on the same Wi-Fi
network or hotspot. Choose **Host room** to set the table size and share the
host IP and room code. Guests join from **Teen Patti → Join room**. Everyone
marks ready before the host starts. Each player starts
with 30 virtual points and pays a one-point boot per hand. Look to play seen,
call with Chaal, raise the blind stake, or Pack. Seen actions cost twice the
blind stake, which caps at eight. With two active players, a blind player
can always request Show if they can pay the stake. A seen player can request
Show when the opponent has also looked. The table automatically compares
active hands after twice the starting table size in turns.
A-K-Q outranks A-2-3, then K-Q-J. Ties split the pot,
with any remainder paid in order from the first seat of the hand.
[Teen Patti rules reference](https://www.teenpatti.com/blog/teen-patti-rules/)

**Marriage** supports tables of two to five offline or on the same Wi-Fi
network or hotspot. The host chooses the table size and shares the IP address
and room code. The game uses three decks, three printed jokers, and 21 cards
per player. Each player unlocks the hidden maal individually.

- **Sequence route.** Select three cards and tap **Lay group**. Three pure
  runs or tunnellas (three identical cards) reveal the maal. Its rank, its
  neighbors in the same suit, and printed jokers become wild for runs and
  trials. Ace sits between king and two when finding the maal neighbors.
  After seeing, a sequence player draws from stock when the top discard is
  wild. Seven declared groups finish the hand after any required discard.
- **Dublee route.** Before laying any three-card groups, collect seven pairs
  of identical ranks and suits and tap **Show 7 Dublees** to reveal the maal.
  Printed jokers and wildcard substitutions cannot make a pair. After the
  show, you can take the top discard only if it makes your final pair with a
  card in your hand. Draw, select the eighth pair, tap **Lay eighth Dublee**,
  and discard one card to finish.
- **Scoring.** Players who saw the maal score the Tiplu, Poplu, and Jhiplu they
  still hold or have laid. One Tiplu is worth 3 and two are worth 7. Poplu and
  Jhiplu are each worth 2, 5, or 10 for one, two, or three copies. A Marriage
  combines all three faces for 10 points, or 30 for two sets. Each card scores
  once. Players exchange the differences in their maal scores. Each opponent
  also pays the finisher 3 points if they saw the maal or 10 otherwise, plus
  5 after a Dublee finish. An exhausted stock ends the hand in a draw.

[Marriage rules reference](https://bhoos.games/blog/learn-to-play-the-best-marriage-card-game/)
[Marriage scoring reference](https://www.pagat.com/rummy/marriage.html#score)

Internet play is planned for the Go backend.
