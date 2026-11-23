import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../cards/playing_card.dart';
import '../settings/game_feedback.dart';

class DealAnimation extends StatefulWidget {
  const DealAnimation({
    required this.seats,
    required this.onComplete,
    super.key,
  });

  // The local player is first so their cards always travel to the near end.
  final List<String> seats;
  final VoidCallback onComplete;

  @override
  State<DealAnimation> createState() => _DealAnimationState();
}

class _DealAnimationState extends State<DealAnimation>
    with SingleTickerProviderStateMixin {
  static const _shuffleMs = 750;
  static const _staggerMs = 145;
  static const _flightMs = 300;

  late final AnimationController _motion;
  late final int _durationMs;
  var _sent = 0;
  var _started = false;
  GameFeedback? _feedback;

  @override
  void initState() {
    super.initState();
    _durationMs =
        _shuffleMs + (widget.seats.length - 1) * _staggerMs + _flightMs;
    _motion =
        AnimationController(
            vsync: this,
            duration: Duration(milliseconds: _durationMs),
          )
          ..addListener(_cueDeal)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) widget.onComplete();
          });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _feedback = GameFeedbackScope.maybeOf(context);
    if (_started) return;
    _started = true;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (reduceMotion) {
        widget.onComplete();
        return;
      }
      unawaited(_feedback?.play(CardSound.shuffle));
      _motion.forward();
    });
  }

  void _cueDeal() {
    final elapsed = _motion.value * _durationMs;
    if (_sent == widget.seats.length ||
        elapsed < _shuffleMs + _sent * _staggerMs) {
      return;
    }
    _sent = math.min(
      widget.seats.length,
      1 + (elapsed - _shuffleMs) ~/ _staggerMs,
    );
    unawaited(_feedback?.play(CardSound.deal));
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.scaffoldBackgroundColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const RadialGradient(
              radius: 1.05,
              colors: [Color(0xFF346055), Color(0xFF1B3A33)],
            ),
            border: Border.all(color: const Color(0xFF60796F)),
          ),
          child: LayoutBuilder(
            builder: (context, limits) {
              final center = Offset(limits.maxWidth / 2, limits.maxHeight / 2);
              final targets = List.generate(widget.seats.length, (index) {
                final angle =
                    math.pi / 2 + 2 * math.pi * index / widget.seats.length;
                return center +
                    Offset(
                      math.cos(angle) * limits.maxWidth * .38,
                      math.sin(angle) * limits.maxHeight * .29,
                    );
              });
              return AnimatedBuilder(
                animation: _motion,
                builder: (context, _) {
                  final elapsed = _motion.value * _durationMs;
                  final shuffling = elapsed < _shuffleMs;
                  final riffle = math.sin(math.pi * elapsed / _shuffleMs);
                  final status = shuffling
                      ? 'Shuffling cards'
                      : 'Dealing cards';
                  return Stack(
                    children: [
                      Positioned(
                        top: 10,
                        left: 0,
                        right: 0,
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            status,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      for (var index = 0; index < targets.length; index++)
                        Positioned(
                          left: targets[index].dx - 54,
                          top: targets[index].dy + 18,
                          width: 108,
                          child: Text(
                            widget.seats[index],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: const Color(0xFFF0DAC0),
                            ),
                          ),
                        ),
                      if (shuffling) ...[
                        _card(
                          center + Offset(-8 - 18 * riffle, 0),
                          .88,
                          -.14 - .23 * riffle,
                        ),
                        _card(
                          center + Offset(8 + 18 * riffle, -3 * riffle),
                          .88,
                          .14 + .23 * riffle,
                        ),
                      ] else ...[
                        _card(center + const Offset(-2, 3), .85, -.08),
                        _card(center, .85, .05),
                        for (var index = 0; index < targets.length; index++)
                          if (elapsed >= _shuffleMs + index * _staggerMs)
                            _dealCard(
                              center,
                              targets[index],
                              elapsed - _shuffleMs - index * _staggerMs,
                            ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _dealCard(Offset start, Offset end, double elapsed) {
    final progress = Curves.easeOutCubic.transform(
      (elapsed / _flightMs).clamp(0.0, 1.0),
    );
    final position =
        Offset.lerp(start, end, progress)! -
        Offset(0, 12 * math.sin(math.pi * progress));
    return _card(
      position,
      .85 - .33 * progress,
      .38 * math.sin(math.pi * progress),
    );
  }

  Widget _card(Offset center, double scale, double angle) => Positioned(
    left: center.dx - 25,
    top: center.dy - 33.5,
    child: Transform.rotate(
      angle: angle,
      child: Transform.scale(
        scale: scale,
        child: const ExcludeSemantics(child: PlayingCard.faceDown()),
      ),
    ),
  );
}
