import 'package:flutter/material.dart';

class UserNote {
  final int id;
  final String title;
  final String content;
  final String color;
  final List<NoteHighlight> highlights;
  final bool isPinned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserNote({
    required this.id,
    required this.title,
    required this.content,
    required this.color,
    this.highlights = const <NoteHighlight>[],
    this.isPinned = false,
    this.createdAt,
    this.updatedAt,
  });

  factory UserNote.fromJson(Map<String, dynamic> json) {
    final rawHighlights = json['highlights'];
    return UserNote(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      color: NotePalette.normalizeCardColor(json['color']?.toString()),
      highlights: rawHighlights is List
          ? rawHighlights
                .whereType<Map>()
                .map(
                  (item) =>
                      NoteHighlight.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.end > item.start)
                .toList(growable: false)
          : const <NoteHighlight>[],
      isPinned:
          json['is_pinned'] == true || json['is_pinned']?.toString() == '1',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? ''),
    );
  }
}

class NoteHighlight {
  final int start;
  final int end;
  final String color;

  const NoteHighlight({
    required this.start,
    required this.end,
    required this.color,
  });

  factory NoteHighlight.fromJson(Map<String, dynamic> json) {
    return NoteHighlight(
      start: int.tryParse(json['start']?.toString() ?? '') ?? 0,
      end: int.tryParse(json['end']?.toString() ?? '') ?? 0,
      color: NotePalette.normalizeMarkerColor(json['color']?.toString()),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'start': start,
    'end': end,
    'color': color,
  };

  NoteHighlight copyWith({int? start, int? end, String? color}) {
    return NoteHighlight(
      start: start ?? this.start,
      end: end ?? this.end,
      color: color ?? this.color,
    );
  }
}

class NotePalette {
  static const cardColors = <String>[
    'neutral',
    'yellow',
    'blue',
    'green',
    'pink',
    'purple',
    'orange',
  ];

  static const markerColors = <String>[
    'yellow',
    'green',
    'blue',
    'pink',
    'purple',
    'orange',
  ];

  static String normalizeCardColor(String? value) {
    return cardColors.contains(value) ? value! : 'neutral';
  }

  static String normalizeMarkerColor(String? value) {
    return markerColors.contains(value) ? value! : 'yellow';
  }

  static Color cardBackground(String value) {
    return switch (normalizeCardColor(value)) {
      'yellow' => const Color(0xFFFFF7CC),
      'blue' => const Color(0xFFDFF1FF),
      'green' => const Color(0xFFE3F7E8),
      'pink' => const Color(0xFFFFE3EE),
      'purple' => const Color(0xFFEDE5FF),
      'orange' => const Color(0xFFFFE9D3),
      _ => const Color(0xFFF8FAFC),
    };
  }

  static Color cardAccent(String value) {
    return switch (normalizeCardColor(value)) {
      'yellow' => const Color(0xFFE3A008),
      'blue' => const Color(0xFF1976D2),
      'green' => const Color(0xFF2E7D32),
      'pink' => const Color(0xFFC2185B),
      'purple' => const Color(0xFF6A1B9A),
      'orange' => const Color(0xFFE65100),
      _ => const Color(0xFF475569),
    };
  }

  static Color marker(String value) {
    return switch (normalizeMarkerColor(value)) {
      'green' => const Color(0xFFB9F6CA),
      'blue' => const Color(0xFFB3E5FC),
      'pink' => const Color(0xFFF8BBD0),
      'purple' => const Color(0xFFD1C4E9),
      'orange' => const Color(0xFFFFCC80),
      _ => const Color(0xFFFFF59D),
    };
  }
}
