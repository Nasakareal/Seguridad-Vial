import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/routes.dart';
import '../academy/models/vial_question.dart' show AcademiaMode;
import '../academy/screens/academia_vial_screen.dart';
import '../../../screens/welcome_screen.dart';
import '../../../services/auth_service.dart';
import '../games/detecta_peligro_screen.dart';
import '../games/quien_pasa_primero_screen.dart';
import '../games/un_segundo_antes_screen.dart';
import '../services/cultura_vial_audio_service.dart';
import '../services/cultura_vial_progress_service.dart';
import '../widgets/game_ui.dart';

class CulturaVialGameHubScreen extends StatefulWidget {
  const CulturaVialGameHubScreen({super.key});

  @override
  State<CulturaVialGameHubScreen> createState() =>
      _CulturaVialGameHubScreenState();
}

class _CulturaVialGameHubScreenState extends State<CulturaVialGameHubScreen>
    with SingleTickerProviderStateMixin {
  final _audio = CulturaVialAudioService.instance;
  final _progress = CulturaVialProgressService.instance;
  late final AnimationController _world;
  bool _enteredAudio = false;

  @override
  void initState() {
    super.initState();
    _world = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
    _enter();
  }

  Future<void> _enter() async {
    await _audio.enterModule();
    _enteredAudio = true;
    await _progress.load();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _world.dispose();
    if (_enteredAudio) _audio.exitModule();
    super.dispose();
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  Future<void> _open(Widget screen) async {
    _audio.notifyInteraction();
    await Navigator.push(context, _GamePageRoute(builder: (_) => screen));
    await _progress.load();
    if (mounted) setState(() {});
  }

  void _audioSettings() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const AudioSettingsSheet(),
  );

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _audio.notifyInteraction(),
      child: Scaffold(
        backgroundColor: const Color(0xFFEAF5FF),
        body: AnimatedBuilder(
          animation: Listenable.merge([_world, _progress, _audio]),
          builder: (context, _) {
            final progress = _progress.progress;
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: MediaQuery.sizeOf(context).width < 380
                      ? 330
                      : 260,
                  backgroundColor: const Color(0xFF123A73),
                  foregroundColor: Colors.white,
                  title: const Text(
                    'Michoacán al Volante',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  actions: [
                    IconButton(
                      onPressed: _audioSettings,
                      tooltip: 'Música y efectos',
                      icon: Icon(
                        _audio.musicEnabled
                            ? Icons.music_note_rounded
                            : Icons.music_off_rounded,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Cuenta y progreso',
                      onSelected: (value) {
                        if (value == 'profile') {
                          _showProfile(context);
                        } else if (value == 'logout') {
                          _logout();
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'profile',
                          child: ListTile(
                            leading: Icon(Icons.account_circle_rounded),
                            title: Text('Mi progreso'),
                          ),
                        ),
                        PopupMenuItem(
                          value: 'logout',
                          child: ListTile(
                            leading: Icon(Icons.logout_rounded),
                            title: Text('Cerrar sesión'),
                          ),
                        ),
                      ],
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        CustomPaint(painter: _HubWorldPainter(_world.value)),
                        SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 52, 20, 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text(
                                  'Tu ruta hacia decisiones seguras',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 25,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: const BoxDecoration(
                                        color: culturaYellow,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${progress.level}',
                                          style: const TextStyle(
                                            color: culturaInk,
                                            fontSize: 23,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'NIVEL ${progress.level} · ${progress.xp} XP',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: progress.levelProgress,
                                            minHeight: 10,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            backgroundColor: Colors.white24,
                                            color: culturaYellow,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    _topPill(
                                      Icons.star_rounded,
                                      '${progress.totalStars}',
                                    ),
                                    _topPill(
                                      Icons.local_fire_department_rounded,
                                      '${progress.dayStreak}',
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
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 30),
                  sliver: SliverList.list(
                    children: [
                      _challengeCard(progress),
                      const SizedBox(height: 22),
                      const Row(
                        children: [
                          Icon(
                            Icons.sports_esports_rounded,
                            color: culturaBlue,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Elige tu misión',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                                color: culturaInk,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Partidas rápidas, decisiones reales y tres estrellas por dominar.',
                        style: TextStyle(color: Color(0xFF5E7288)),
                      ),
                      const SizedBox(height: 14),
                      LayoutBuilder(
                        builder: (_, constraints) {
                          final columns = constraints.maxWidth >= 1050
                              ? 3
                              : constraints.maxWidth >= 650
                              ? 2
                              : 1;
                          final width =
                              (constraints.maxWidth - (columns - 1) * 14) /
                              columns;
                          return Wrap(
                            spacing: 14,
                            runSpacing: 14,
                            children: [
                              SizedBox(
                                width: width,
                                child: _gameCard(
                                  id: 'detecta_peligro',
                                  title: 'Detecta el peligro',
                                  subtitle: 'Reflejos y observación',
                                  tag: '4 escenas',
                                  color: const Color(0xFFF05252),
                                  icon: Icons.visibility_rounded,
                                  stars: progress.stars['detecta_peligro'] ?? 0,
                                  best:
                                      progress.bestScores['detecta_peligro'] ??
                                      0,
                                  onTap: () =>
                                      _open(const DetectaPeligroScreen()),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _gameCard(
                                  id: 'quien_pasa',
                                  title: '¿Quién pasa primero?',
                                  subtitle: 'Rompecabezas de cruces',
                                  tag: 'Arrastra y ordena',
                                  color: const Color(0xFF7C3AED),
                                  icon: Icons.alt_route_rounded,
                                  stars: progress.stars['quien_pasa'] ?? 0,
                                  best: progress.bestScores['quien_pasa'] ?? 0,
                                  onTap: () =>
                                      _open(const QuienPasaPrimeroScreen()),
                                ),
                              ),
                              SizedBox(
                                width: width,
                                child: _gameCard(
                                  id: 'segundo_antes',
                                  title: 'Un segundo antes',
                                  subtitle: 'Cambia el desenlace',
                                  tag: 'Decisiones ramificadas',
                                  color: const Color(0xFF0284C7),
                                  icon: Icons.replay_circle_filled_rounded,
                                  stars: progress.stars['segundo_antes'] ?? 0,
                                  best:
                                      progress.bestScores['segundo_antes'] ?? 0,
                                  onTap: () =>
                                      _open(const UnSegundoAntesScreen()),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _academyCard(),
                      const SizedBox(height: 14),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.culturaVialJoin,
                        ),
                        icon: const Icon(Icons.qr_code_scanner_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('Entrar a una partida grupal con código'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Experiencia educativa. No sustituye cursos, trámites ni evaluaciones oficiales.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF60758A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topPill(IconData icon, String value) => Container(
    margin: const EdgeInsets.only(left: 6),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .15),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: culturaYellow),
        const SizedBox(width: 3),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );

  Widget _challengeCard(CulturaVialProgress progress) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF113F75), Color(0xFF1769E0)],
      ),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x331769E0),
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: culturaYellow,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            color: culturaInk,
            size: 29,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DESAFÍO DEL DÍA',
                style: TextStyle(
                  color: culturaYellow,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _progress.dailyChallenge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        Column(
          children: [
            Text(
              '${_progress.dailyChallengeValue}/${_progress.dailyChallengeTarget}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            SizedBox(
              width: 48,
              child: LinearProgressIndicator(
                value: _progress.dailyChallengeProgress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(7),
                backgroundColor: Colors.white24,
                color: culturaYellow,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _gameCard({
    required String id,
    required String title,
    required String subtitle,
    required String tag,
    required Color color,
    required IconData icon,
    required int stars,
    required int best,
    required VoidCallback onTap,
  }) => _BouncyCard(
    onTap: onTap,
    child: Container(
      height: 210,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -22,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 19,
            top: 21,
            child: Icon(icon, size: 54, color: color),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    color: culturaInk,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF60758A)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    StarDisplay(stars: stars, size: 25),
                    const Spacer(),
                    if (best > 0)
                      Text(
                        'Récord $best',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF60758A),
                        ),
                      ),
                    const SizedBox(width: 5),
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: color,
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _academyCard() => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7DB),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFFFDA67)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            CircleAvatar(
              backgroundColor: culturaYellow,
              child: Icon(Icons.school_rounded, color: culturaInk),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Academia y simulador',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: culturaInk,
                    ),
                  ),
                  Text(
                    'Estudia cuando quieras cambiar del juego al examen.',
                    style: TextStyle(color: Color(0xFF6D6042)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.lightbulb_outline, size: 18),
              label: const Text('Aprender'),
              onPressed: () => _open(
                const AcademiaVialScreen(initialMode: AcademiaMode.aprender),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.fitness_center, size: 18),
              label: const Text('Practicar'),
              onPressed: () => _open(
                const AcademiaVialScreen(initialMode: AcademiaMode.practicar),
              ),
            ),
            ActionChip(
              avatar: const Icon(Icons.timer_outlined, size: 18),
              label: const Text('Simulacro'),
              onPressed: () => _open(
                const AcademiaVialScreen(initialMode: AcademiaMode.simulacro),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  void _showProfile(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ProgressSheet(
      progress: _progress.progress,
      daily: _progress.dailyChallenge,
      weekly: '${_progress.weeklyMission} (${_progress.weeklyMissionStars}/6)',
    ),
  );
}

class _ProgressSheet extends StatelessWidget {
  final CulturaVialProgress progress;
  final String daily;
  final String weekly;
  const _ProgressSheet({
    required this.progress,
    required this.daily,
    required this.weekly,
  });
  @override
  Widget build(BuildContext context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .45,
      maxChildSize: .94,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
        children: [
          Row(
            children: [
              Container(
                width: 66,
                height: 66,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [culturaBlue, culturaSky]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Colors.white,
                  size: 38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nivel ${progress.level}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: culturaInk,
                      ),
                    ),
                    Text(
                      '${progress.xp} XP · ${progress.totalStars} estrellas · racha de ${progress.dayStreak} días',
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          LinearProgressIndicator(
            value: progress.levelProgress,
            minHeight: 12,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(height: 22),
          const Text(
            'Retos',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEAF2FF),
              child: Icon(Icons.today_rounded, color: culturaBlue),
            ),
            title: Text(daily),
            subtitle: const Text('Desafío diario'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFFFF4D1),
              child: Icon(
                Icons.calendar_view_week_rounded,
                color: Color(0xFFC57A00),
              ),
            ),
            title: Text(weekly),
            subtitle: const Text('Misión semanal'),
          ),
          const Divider(height: 28),
          const Text(
            'Medallas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final achievement in culturaVialAchievements)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: progress.achievements.contains(achievement.id)
                    ? const Color(0xFFFFF0B5)
                    : const Color(0xFFE7ECF2),
                child: Text(
                  progress.achievements.contains(achievement.id)
                      ? achievement.icon
                      : '🔒',
                ),
              ),
              title: Text(
                achievement.title,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: progress.achievements.contains(achievement.id)
                      ? culturaInk
                      : const Color(0xFF8796A7),
                ),
              ),
              subtitle: Text(achievement.description),
            ),
        ],
      ),
    ),
  );
}

class _BouncyCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _BouncyCard({required this.child, required this.onTap});
  @override
  State<_BouncyCard> createState() => _BouncyCardState();
}

class _BouncyCardState extends State<_BouncyCard> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: pressed ? .97 : 1,
    duration: const Duration(milliseconds: 90),
    child: GestureDetector(
      onTapDown: (_) => setState(() => pressed = true),
      onTapCancel: () => setState(() => pressed = false),
      onTapUp: (_) {
        setState(() => pressed = false);
        CulturaVialAudioService.instance.playEffect(CulturaVialSound.tap);
        widget.onTap();
      },
      child: widget.child,
    ),
  );
}

class _GamePageRoute<T> extends PageRouteBuilder<T> {
  _GamePageRoute({required WidgetBuilder builder})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (_, animation, secondary, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(.06, .02),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      );
}

class _HubWorldPainter extends CustomPainter {
  final double progress;
  _HubWorldPainter(this.progress);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF123A73), Color(0xFF1769E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    final road = Path()
      ..moveTo(size.width * .52, size.height * .28)
      ..lineTo(size.width * .95, size.height)
      ..lineTo(size.width * .42, size.height)
      ..close();
    canvas.drawPath(
      road,
      Paint()..color = const Color(0xFF25374B).withValues(alpha: .62),
    );
    for (var i = 0; i < 5; i++) {
      final y = ((i + progress) % 5) * size.height / 4;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(size.width * (.64 + y / size.height * .06), y),
            width: 7 + y / size.height * 8,
            height: 22 + y / size.height * 20,
          ),
          const Radius.circular(3),
        ),
        Paint()..color = Colors.white.withValues(alpha: .6),
      );
    }
    final x = size.width * (.68 + math.sin(progress * math.pi * 2) * .02);
    final y = size.height * .63;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, y), width: 46, height: 72),
        const Radius.circular(13),
      ),
      Paint()..color = culturaYellow,
    );
    for (var i = 0; i < 18; i++) {
      final px = (i * 89.0 + progress * 40) % size.width;
      final py = (i * 47.0) % size.height;
      canvas.drawCircle(
        Offset(px, py),
        1.5 + i % 3,
        Paint()..color = Colors.white.withValues(alpha: .18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HubWorldPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
