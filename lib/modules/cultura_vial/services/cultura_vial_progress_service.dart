import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/auth_service.dart';

class CulturaVialAchievement {
  final String id;
  final String title;
  final String description;
  final String icon;

  const CulturaVialAchievement(
    this.id,
    this.title,
    this.description,
    this.icon,
  );
}

const culturaVialAchievements = <CulturaVialAchievement>[
  CulturaVialAchievement(
    'ojo_aguila',
    'Ojo de Águila',
    'Identifica 20 peligros.',
    '👁️',
  ),
  CulturaVialAchievement(
    'maestro_cruceros',
    'Maestro de Cruceros',
    'Resuelve 10 intersecciones.',
    '🚦',
  ),
  CulturaVialAchievement(
    'cero_riesgos',
    'Cero Riesgos',
    'Completa una misión sin errores.',
    '🛡️',
  ),
  CulturaVialAchievement(
    'conductor_precavido',
    'Conductor Precavido',
    'Supera 5 escenarios preventivos.',
    '🚙',
  ),
  CulturaVialAchievement(
    'leyenda_volante',
    'Leyenda del Volante',
    'Consigue 3 estrellas en todos los juegos.',
    '🏆',
  ),
];

class CulturaVialProgress {
  final int xp;
  final Map<String, int> stars;
  final Map<String, int> bestScores;
  final Map<String, int> plays;
  final Map<String, int> counters;
  final Set<String> achievements;
  final String? lastPlayedDay;
  final int dayStreak;
  final String? challengeDay;
  final int challengeValue;
  final bool challengeCompleted;

  const CulturaVialProgress({
    this.xp = 0,
    this.stars = const {},
    this.bestScores = const {},
    this.plays = const {},
    this.counters = const {},
    this.achievements = const {},
    this.lastPlayedDay,
    this.dayStreak = 0,
    this.challengeDay,
    this.challengeValue = 0,
    this.challengeCompleted = false,
  });

  int get level => 1 + xp ~/ 500;
  int get xpInLevel => xp % 500;
  double get levelProgress => xpInLevel / 500;
  int get totalStars => stars.values.fold(0, (sum, value) => sum + value);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'xp': xp,
    'stars': stars,
    'best_scores': bestScores,
    'plays': plays,
    'counters': counters,
    'achievements': achievements.toList(),
    'last_played_day': lastPlayedDay,
    'day_streak': dayStreak,
    'challenge_day': challengeDay,
    'challenge_value': challengeValue,
    'challenge_completed': challengeCompleted,
  };

  factory CulturaVialProgress.fromJson(Map<String, dynamic> json) {
    Map<String, int> ints(dynamic raw) => raw is Map
        ? raw.map(
            (key, value) =>
                MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
          )
        : <String, int>{};
    return CulturaVialProgress(
      xp: int.tryParse('${json['xp'] ?? 0}') ?? 0,
      stars: ints(json['stars']),
      bestScores: ints(json['best_scores']),
      plays: ints(json['plays']),
      counters: ints(json['counters']),
      achievements: json['achievements'] is List
          ? (json['achievements'] as List).map((e) => e.toString()).toSet()
          : <String>{},
      lastPlayedDay: json['last_played_day']?.toString(),
      dayStreak: int.tryParse('${json['day_streak'] ?? 0}') ?? 0,
      challengeDay: json['challenge_day']?.toString(),
      challengeValue: int.tryParse('${json['challenge_value'] ?? 0}') ?? 0,
      challengeCompleted: json['challenge_completed'] == true,
    );
  }
}

class CulturaVialReward {
  final int xpEarned;
  final int stars;
  final int previousBest;
  final List<CulturaVialAchievement> unlocked;
  final bool dailyChallengeCompleted;
  const CulturaVialReward({
    required this.xpEarned,
    required this.stars,
    required this.previousBest,
    required this.unlocked,
    required this.dailyChallengeCompleted,
  });
}

class CulturaVialProgressService extends ChangeNotifier {
  CulturaVialProgressService._();
  static final CulturaVialProgressService instance =
      CulturaVialProgressService._();

  CulturaVialProgress progress = const CulturaVialProgress();
  bool loaded = false;
  String _owner = 'invitado';

  Future<void> load() async {
    final owner = await _ownerKey();
    if (loaded && owner == _owner) return;
    _owner = owner;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('cultura_vial_progress_v2_$owner');
    if (raw != null) {
      try {
        progress = CulturaVialProgress.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      } catch (_) {
        progress = const CulturaVialProgress();
      }
    } else {
      progress = const CulturaVialProgress();
    }
    loaded = true;
    notifyListeners();
  }

  Future<CulturaVialReward> recordGame({
    required String gameId,
    required int score,
    required int stars,
    required int correct,
    required int mistakes,
    int hazards = 0,
    int intersections = 0,
    int preventiveChoices = 0,
  }) async {
    await load();
    final previousBest = progress.bestScores[gameId] ?? 0;
    final clampedStars = stars.clamp(0, 3);
    var xpEarned =
        35 + correct * 12 + clampedStars * 25 + (mistakes == 0 ? 30 : 0);
    final now = DateTime.now();
    final today = _day(now);
    var streak = progress.dayStreak;
    if (progress.lastPlayedDay != today) {
      final yesterday = _day(now.subtract(const Duration(days: 1)));
      streak = progress.lastPlayedDay == yesterday ? streak + 1 : 1;
    }

    final nextCounters = Map<String, int>.of(progress.counters);
    nextCounters['hazards'] = (nextCounters['hazards'] ?? 0) + hazards;
    nextCounters['intersections'] =
        (nextCounters['intersections'] ?? 0) + intersections;
    nextCounters['preventive'] =
        (nextCounters['preventive'] ?? 0) + preventiveChoices;

    final nextStars = Map<String, int>.of(progress.stars);
    nextStars[gameId] = clampedStars > (nextStars[gameId] ?? 0)
        ? clampedStars
        : (nextStars[gameId] ?? 0);
    final nextScores = Map<String, int>.of(progress.bestScores);
    nextScores[gameId] = score > previousBest ? score : previousBest;
    final nextPlays = Map<String, int>.of(progress.plays);
    nextPlays[gameId] = (nextPlays[gameId] ?? 0) + 1;
    final nextAchievements = Set<String>.of(progress.achievements);
    final challengeReset = progress.challengeDay != today;
    final oldChallengeValue = challengeReset ? 0 : progress.challengeValue;
    final oldChallengeCompleted = challengeReset
        ? false
        : progress.challengeCompleted;
    final challengeDelta = switch (_dailyIndex(now)) {
      0 => hazards,
      1 => intersections,
      2 => preventiveChoices,
      _ => score > previousBest ? 1 : 0,
    };
    final nextChallengeValue = oldChallengeValue + challengeDelta;
    final completedNow =
        !oldChallengeCompleted && nextChallengeValue >= dailyChallengeTarget;
    if (completedNow) xpEarned += 80;

    if ((nextCounters['hazards'] ?? 0) >= 20) {
      nextAchievements.add('ojo_aguila');
    }
    if ((nextCounters['intersections'] ?? 0) >= 10) {
      nextAchievements.add('maestro_cruceros');
    }
    if (mistakes == 0) nextAchievements.add('cero_riesgos');
    if ((nextCounters['preventive'] ?? 0) >= 5) {
      nextAchievements.add('conductor_precavido');
    }
    if (const [
      'detecta_peligro',
      'quien_pasa',
      'segundo_antes',
    ].every((id) => (nextStars[id] ?? 0) >= 3)) {
      nextAchievements.add('leyenda_volante');
    }

    final unlockedIds = nextAchievements.difference(progress.achievements);
    progress = CulturaVialProgress(
      xp: progress.xp + xpEarned,
      stars: nextStars,
      bestScores: nextScores,
      plays: nextPlays,
      counters: nextCounters,
      achievements: nextAchievements,
      lastPlayedDay: today,
      dayStreak: streak,
      challengeDay: today,
      challengeValue: nextChallengeValue,
      challengeCompleted: oldChallengeCompleted || completedNow,
    );
    await _save();
    notifyListeners();
    return CulturaVialReward(
      xpEarned: xpEarned,
      stars: clampedStars,
      previousBest: previousBest,
      unlocked: culturaVialAchievements
          .where((achievement) => unlockedIds.contains(achievement.id))
          .toList(),
      dailyChallengeCompleted: completedNow,
    );
  }

  String get dailyChallenge {
    return const [
      'Identifica 5 peligros sin falsas alarmas',
      'Resuelve 3 cruces con dos o más estrellas',
      'Toma 4 decisiones preventivas',
      'Mejora uno de tus récords personales',
    ][_dailyIndex(DateTime.now())];
  }

  String get weeklyMission => 'Consigue 6 estrellas entre los tres juegos';

  int get dailyChallengeTarget =>
      const [5, 3, 4, 1][_dailyIndex(DateTime.now())];

  int get dailyChallengeValue => progress.challengeDay == _day(DateTime.now())
      ? progress.challengeValue.clamp(0, dailyChallengeTarget)
      : 0;

  double get dailyChallengeProgress =>
      dailyChallengeValue / dailyChallengeTarget;

  int get weeklyMissionStars => const [
    'detecta_peligro',
    'quien_pasa',
    'segundo_antes',
  ].fold(0, (sum, id) => sum + (progress.stars[id] ?? 0));

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'cultura_vial_progress_v2_$_owner',
      jsonEncode(progress.toJson()),
    );
  }

  Future<String> _ownerKey() async {
    final email = (await AuthService.getUserEmail() ?? 'invitado')
        .trim()
        .toLowerCase();
    return email.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  }

  String _day(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  int _dailyIndex(DateTime value) =>
      value.difference(DateTime(2026)).inDays.abs() % 4;
}
