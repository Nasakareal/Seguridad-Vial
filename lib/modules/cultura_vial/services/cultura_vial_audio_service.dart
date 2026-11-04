import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CulturaVialSound { tap, correct, wrong, combo, unlock, reward }

/// Audio lives behind this module-scoped singleton so route changes never
/// create overlapping players. It stops as soon as the educational hub leaves
/// the navigation tree and never runs on operational screens.
class CulturaVialAudioService extends ChangeNotifier
    with WidgetsBindingObserver {
  CulturaVialAudioService._() {
    WidgetsBinding.instance.addObserver(this);
    _musicPlayer.onPlayerComplete.listen((_) => _playNextTrack());
  }

  static final CulturaVialAudioService instance = CulturaVialAudioService._();

  static const _musicEnabledKey = 'cultura_vial_music_enabled_v1';
  static const _effectsEnabledKey = 'cultura_vial_effects_enabled_v1';
  static const _musicVolumeKey = 'cultura_vial_music_volume_v1';
  static const _effectsVolumeKey = 'cultura_vial_effects_volume_v1';
  static const _playlist = <String>['audio/track_01.mp3', 'audio/track_02.mp3'];

  final AudioPlayer _musicPlayer = AudioPlayer(playerId: 'cultura-vial-music');
  final List<AudioPlayer> _effectPlayers = <AudioPlayer>[];
  StreamSubscription<PlayerState>? _stateSubscription;
  int _trackIndex = 0;
  int _moduleDepth = 0;
  bool _loaded = false;
  bool _started = false;
  bool _backgroundPaused = false;
  bool musicEnabled = true;
  bool effectsEnabled = true;
  double musicVolume = .32;
  double effectsVolume = .68;

  bool get isInsideModule => _moduleDepth > 0;
  bool get isPlaying => _started && musicEnabled && isInsideModule;

  Future<void> enterModule() async {
    _moduleDepth++;
    await _loadPreferences();
    notifyListeners();
  }

  Future<void> exitModule() async {
    _moduleDepth = math.max(0, _moduleDepth - 1);
    if (_moduleDepth == 0) {
      _started = false;
      _backgroundPaused = false;
      await _musicPlayer.stop();
    }
    notifyListeners();
  }

  /// Call from the first pointer/keyboard interaction. Browsers may reject the
  /// initial play attempt until this method runs inside a user gesture.
  Future<void> notifyInteraction() async {
    await _loadPreferences();
    if (!isInsideModule || !musicEnabled || _started) return;
    await _startCurrentTrack();
  }

  Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_musicEnabledKey, value);
    if (!value) {
      _started = false;
      await _musicPlayer.stop();
    } else if (isInsideModule) {
      await _startCurrentTrack();
    }
    notifyListeners();
  }

  Future<void> setEffectsEnabled(bool value) async {
    effectsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_effectsEnabledKey, value);
    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    musicVolume = value.clamp(0, 1);
    await _musicPlayer.setVolume(musicVolume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_musicVolumeKey, musicVolume);
    notifyListeners();
  }

  Future<void> setEffectsVolume(double value) async {
    effectsVolume = value.clamp(0, 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_effectsVolumeKey, effectsVolume);
    notifyListeners();
  }

  Future<void> playEffect(CulturaVialSound sound) async {
    if (!effectsEnabled || !isInsideModule || effectsVolume <= 0) return;
    final spec = switch (sound) {
      CulturaVialSound.tap => const _ToneSpec([520], 75, .45),
      CulturaVialSound.correct => const _ToneSpec([620, 820], 210, .8),
      CulturaVialSound.wrong => const _ToneSpec([230, 165], 240, .62),
      CulturaVialSound.combo => const _ToneSpec([660, 880, 1040], 260, .85),
      CulturaVialSound.unlock => const _ToneSpec([440, 660, 880], 420, .9),
      CulturaVialSound.reward => const _ToneSpec([520, 660, 780, 1040], 560, 1),
    };
    final player = AudioPlayer();
    _effectPlayers.add(player);
    try {
      await player.play(
        BytesSource(_toneWav(spec)),
        volume: effectsVolume * spec.gain,
      );
      await player.onPlayerComplete.first.timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    } catch (_) {
      // Visual feedback remains complete when audio is unavailable.
    } finally {
      _effectPlayers.remove(player);
      await player.dispose();
    }
  }

  Future<void> _loadPreferences() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    musicEnabled = prefs.getBool(_musicEnabledKey) ?? true;
    effectsEnabled = prefs.getBool(_effectsEnabledKey) ?? true;
    musicVolume = prefs.getDouble(_musicVolumeKey) ?? .32;
    effectsVolume = prefs.getDouble(_effectsVolumeKey) ?? .68;
    await _musicPlayer.setReleaseMode(ReleaseMode.stop);
    await _musicPlayer.setVolume(musicVolume);
    _stateSubscription ??= _musicPlayer.onPlayerStateChanged.listen((state) {
      notifyListeners();
    });
    _loaded = true;
  }

  Future<void> _startCurrentTrack() async {
    if (!isInsideModule || !musicEnabled) return;
    try {
      await _musicPlayer.play(
        AssetSource(_playlist[_trackIndex]),
        volume: musicVolume,
      );
      _started = true;
    } catch (_) {
      _started = false;
    }
    notifyListeners();
  }

  Future<void> _playNextTrack() async {
    if (!isInsideModule || !musicEnabled) return;
    _trackIndex = (_trackIndex + 1) % _playlist.length;
    _started = false;
    await _startCurrentTrack();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isInsideModule || !musicEnabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _backgroundPaused = _started;
      _musicPlayer.pause();
    } else if (state == AppLifecycleState.resumed && _backgroundPaused) {
      _backgroundPaused = false;
      _musicPlayer.resume();
    }
  }

  Uint8List _toneWav(_ToneSpec spec) {
    const sampleRate = 22050;
    final sampleCount = (sampleRate * spec.durationMs / 1000).round();
    final dataLength = sampleCount * 2;
    final bytes = Uint8List(44 + dataLength);
    final data = ByteData.sublistView(bytes);

    void ascii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        data.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, dataLength, Endian.little);

    for (var i = 0; i < sampleCount; i++) {
      final progress = i / sampleCount;
      final note = math.min(
        spec.frequencies.length - 1,
        (progress * spec.frequencies.length).floor(),
      );
      final frequency = spec.frequencies[note];
      final envelope = math.sin(math.pi * progress) * (1 - progress * .28);
      final wave = math.sin(2 * math.pi * frequency * i / sampleRate);
      data.setInt16(
        44 + i * 2,
        (wave * envelope * 15000).round(),
        Endian.little,
      );
    }
    return bytes;
  }
}

class _ToneSpec {
  final List<double> frequencies;
  final int durationMs;
  final double gain;
  const _ToneSpec(this.frequencies, this.durationMs, this.gain);
}
