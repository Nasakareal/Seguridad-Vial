import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/cultura_vial_audio_service.dart';
import '../services/cultura_vial_progress_service.dart';

const culturaInk = Color(0xFF102A43);
const culturaBlue = Color(0xFF1769E0);
const culturaSky = Color(0xFF43C6F4);
const culturaYellow = Color(0xFFFFC83D);
const culturaGreen = Color(0xFF21B573);
const culturaRed = Color(0xFFF05252);

class CulturaVialGameScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final Color background;
  final List<Widget>? actions;

  const CulturaVialGameScaffold({
    super.key,
    required this.title,
    required this.child,
    this.background = const Color(0xFFF1F7FF),
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) =>
          CulturaVialAudioService.instance.notifyInteraction(),
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: Colors.white.withValues(alpha: .94),
          foregroundColor: culturaInk,
          actions: actions,
        ),
        body: SafeArea(child: child),
      ),
    );
  }
}

class GamePressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final Color color;
  final EdgeInsets padding;

  const GamePressable({
    super.key,
    required this.child,
    required this.onPressed,
    this.color = culturaBlue,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
  });

  @override
  State<GamePressable> createState() => _GamePressableState();
}

class _GamePressableState extends State<GamePressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 90),
        child: GestureDetector(
          onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
          onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
          onTapUp: enabled
              ? (_) {
                  setState(() => _pressed = false);
                  CulturaVialAudioService.instance.playEffect(
                    CulturaVialSound.tap,
                  );
                  widget.onPressed?.call();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: enabled ? widget.color : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(18),
              boxShadow: enabled && !_pressed
                  ? [
                      BoxShadow(
                        color: widget.color.withValues(alpha: .32),
                        offset: const Offset(0, 6),
                        blurRadius: 0,
                      ),
                    ]
                  : null,
            ),
            child: DefaultTextStyle.merge(
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
              child: IconTheme.merge(
                data: const IconThemeData(color: Colors.white),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StarDisplay extends StatelessWidget {
  final int stars;
  final double size;
  const StarDisplay({super.key, required this.stars, this.size = 30});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(
      3,
      (index) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: index < stars ? 1 : .82),
        duration: Duration(milliseconds: 350 + index * 160),
        curve: Curves.elasticOut,
        builder: (_, value, child) =>
            Transform.scale(scale: value, child: child),
        child: Icon(
          index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
          size: size,
          color: index < stars ? culturaYellow : const Color(0xFF9AA9BC),
        ),
      ),
    ),
  );
}

class GameResultScreen extends StatefulWidget {
  final String gameId;
  final String title;
  final int score;
  final int correct;
  final int mistakes;
  final int stars;
  final int hazards;
  final int intersections;
  final int preventiveChoices;
  final VoidCallback onReplay;

  const GameResultScreen({
    super.key,
    required this.gameId,
    required this.title,
    required this.score,
    required this.correct,
    required this.mistakes,
    required this.stars,
    required this.onReplay,
    this.hazards = 0,
    this.intersections = 0,
    this.preventiveChoices = 0,
  });

  @override
  State<GameResultScreen> createState() => _GameResultScreenState();
}

class _GameResultScreenState extends State<GameResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Future<CulturaVialReward> _reward;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _reward = CulturaVialProgressService.instance.recordGame(
      gameId: widget.gameId,
      score: widget.score,
      stars: widget.stars,
      correct: widget.correct,
      mistakes: widget.mistakes,
      hazards: widget.hazards,
      intersections: widget.intersections,
      preventiveChoices: widget.preventiveChoices,
    );
    CulturaVialAudioService.instance.playEffect(
      widget.stars >= 2 ? CulturaVialSound.reward : CulturaVialSound.unlock,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CulturaVialGameScaffold(
    title: 'Resultado',
    child: Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) => CustomPaint(
                painter: ConfettiPainter(_controller.value, widget.stars),
              ),
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Container(
                    width: 112,
                    height: 112,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: widget.stars >= 2
                            ? const [Color(0xFFFFD54F), Color(0xFFFF8F00)]
                            : const [Color(0xFF73C8FF), Color(0xFF1769E0)],
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 22,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.stars >= 2
                          ? Icons.emoji_events_rounded
                          : Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 62,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    widget.stars == 3
                        ? '¡Misión perfecta!'
                        : widget.stars == 2
                        ? '¡Gran recorrido!'
                        : '¡Buen entrenamiento!',
                    style: const TextStyle(
                      fontSize: 29,
                      fontWeight: FontWeight.w900,
                      color: culturaInk,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 17,
                      color: Color(0xFF52667A),
                    ),
                  ),
                  const SizedBox(height: 18),
                  StarDisplay(stars: widget.stars, size: 48),
                  const SizedBox(height: 18),
                  Text(
                    '${widget.score}',
                    style: const TextStyle(
                      fontSize: 50,
                      fontWeight: FontWeight.w900,
                      color: culturaBlue,
                    ),
                  ),
                  const Text(
                    'PUNTOS',
                    style: TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7F94),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FutureBuilder<CulturaVialReward>(
                    future: _reward,
                    builder: (_, snapshot) {
                      final reward = snapshot.data;
                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: reward == null
                            ? const CircularProgressIndicator()
                            : Column(
                                key: const ValueKey('reward'),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 18,
                                      vertical: 11,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF2FF),
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      '+${reward.xpEarned} XP',
                                      style: const TextStyle(
                                        color: culturaBlue,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  if (reward.dailyChallengeCompleted) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      '🎯 Desafío diario completado · +80 XP',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: culturaGreen,
                                      ),
                                    ),
                                  ],
                                  if (reward.unlocked.isNotEmpty) ...[
                                    const SizedBox(height: 14),
                                    for (final achievement in reward.unlocked)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          '${achievement.icon} Logro desbloqueado: ${achievement.title}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ],
                              ),
                      );
                    },
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: GamePressable(
                      onPressed: widget.onReplay,
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.replay_rounded),
                          SizedBox(width: 8),
                          Text('Jugar otra vez'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Volver a los juegos'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class AudioSettingsSheet extends StatelessWidget {
  const AudioSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final audio = CulturaVialAudioService.instance;
    return AnimatedBuilder(
      animation: audio,
      builder: (_, __) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 6, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Audio del juego',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              SwitchListTile(
                value: audio.musicEnabled,
                onChanged: audio.setMusicEnabled,
                title: const Text('Música'),
                secondary: const Icon(Icons.music_note_rounded),
              ),
              Slider(
                value: audio.musicVolume,
                onChanged: audio.musicEnabled ? audio.setMusicVolume : null,
                label: '${(audio.musicVolume * 100).round()}%',
              ),
              SwitchListTile(
                value: audio.effectsEnabled,
                onChanged: audio.setEffectsEnabled,
                title: const Text('Efectos'),
                secondary: const Icon(Icons.graphic_eq_rounded),
              ),
              Slider(
                value: audio.effectsVolume,
                onChanged: audio.effectsEnabled ? audio.setEffectsVolume : null,
                label: '${(audio.effectsVolume * 100).round()}%',
              ),
              const Text(
                'El juego siempre muestra retroalimentación visual; el sonido es opcional.',
                style: TextStyle(fontSize: 12, color: Color(0xFF60758A)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double progress;
  final int intensity;
  ConfettiPainter(this.progress, this.intensity);

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;
    const colors = [
      culturaYellow,
      culturaGreen,
      culturaSky,
      Color(0xFFE879F9),
      culturaRed,
    ];
    final count = 18 + intensity * 8;
    for (var i = 0; i < count; i++) {
      final x = ((i * 83.0 + math.sin(i * 2.1) * 30) % size.width);
      final y =
          ((progress * size.height * .7 + i * 71) % (size.height + 80)) - 40;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * math.pi * 2 + i);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: 7, height: 14),
          const Radius.circular(2),
        ),
        Paint()..color = colors[i % colors.length].withValues(alpha: .72),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant ConfettiPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.intensity != intensity;
}
