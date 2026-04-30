import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';

class LocalDraftService {
  static const String _prefix = 'local_form_draft_v1:';

  static Future<Map<String, dynamic>?> load(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(await _storageKey(draftId));
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final values = decoded['values'];
        if (values is Map) return Map<String, dynamic>.from(values);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<void> save(String draftId, Map<String, dynamic> values) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _storageKey(draftId);
    final cleaned = _clean(values);

    if (_isEmpty(cleaned)) {
      await prefs.remove(key);
      return;
    }

    await prefs.setString(
      key,
      jsonEncode(<String, dynamic>{
        'saved_at': DateTime.now().toUtc().toIso8601String(),
        'values': cleaned,
      }),
    );
  }

  static Future<void> discard(String draftId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(await _storageKey(draftId));
  }

  static Future<String> _storageKey(String draftId) async {
    final owner = (await AuthService.getSessionOwnerKey())?.trim();
    final ownerKey = owner == null || owner.isEmpty ? 'anon' : owner;
    return '$_prefix$ownerKey:$draftId';
  }

  static Map<String, dynamic> _clean(Map<String, dynamic> values) {
    final out = <String, dynamic>{};
    values.forEach((key, value) {
      final cleaned = _cleanValue(value);
      if (!_isEmpty(cleaned)) out[key] = cleaned;
    });
    return out;
  }

  static dynamic _cleanValue(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num || value is bool) return value;
    if (value is DateTime) return value.toUtc().toIso8601String();
    if (value is Iterable) {
      return value.map(_cleanValue).where((item) => !_isEmpty(item)).toList();
    }
    if (value is Map) {
      final out = <String, dynamic>{};
      value.forEach((key, item) {
        final cleaned = _cleanValue(item);
        if (!_isEmpty(cleaned)) out[key.toString()] = cleaned;
      });
      return out;
    }
    return value.toString();
  }

  static bool _isEmpty(dynamic value) {
    if (value == null) return true;
    if (value is String) return value.trim().isEmpty;
    if (value is Iterable || value is Map) return value.isEmpty;
    return false;
  }
}

class LocalDraftAutosave {
  LocalDraftAutosave({
    required this.draftId,
    required this.collect,
    this.delay = const Duration(milliseconds: 450),
  });

  final String draftId;
  final Map<String, dynamic> Function() collect;
  final Duration delay;

  final Map<TextEditingController, VoidCallback> _listeners =
      <TextEditingController, VoidCallback>{};
  Timer? _timer;
  bool _muted = false;
  bool _disposed = false;

  void attachTextControllers(Map<String, TextEditingController> controllers) {
    for (final controller in controllers.values) {
      if (_listeners.containsKey(controller)) continue;
      void listener() => notifyChanged();
      _listeners[controller] = listener;
      controller.addListener(listener);
    }
  }

  Future<bool> restore(void Function(Map<String, dynamic> values) apply) async {
    final values = await LocalDraftService.load(draftId);
    if (values == null || values.isEmpty) return false;

    _muted = true;
    try {
      apply(values);
    } finally {
      _muted = false;
    }
    return true;
  }

  void notifyChanged() {
    if (_muted || _disposed) return;
    _timer?.cancel();
    _timer = Timer(delay, () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    if (_muted || _disposed) return;
    await LocalDraftService.save(draftId, collect());
  }

  Future<void> discard() async {
    _timer?.cancel();
    await LocalDraftService.discard(draftId);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final entry in _listeners.entries) {
      entry.key.removeListener(entry.value);
    }
    _listeners.clear();
  }
}
