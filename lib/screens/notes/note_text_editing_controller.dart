import 'package:flutter/material.dart';

import '../../models/user_note.dart';

class NoteTextEditingController extends TextEditingController {
  List<NoteHighlight> _highlights;
  late String _previousText;
  bool _handlingTextChange = false;

  NoteTextEditingController({
    String text = '',
    List<NoteHighlight> highlights = const <NoteHighlight>[],
  }) : _highlights = _normalize(highlights, text.length),
       super(text: text) {
    _previousText = text;
    addListener(_onTextChanged);
  }

  List<NoteHighlight> get highlights => List.unmodifiable(_highlights);

  bool applyHighlight(String color) {
    final selected = selection;
    if (!selected.isValid || selected.isCollapsed) return false;
    final start = selected.start < selected.end ? selected.start : selected.end;
    final end = selected.start < selected.end ? selected.end : selected.start;
    _replaceRange(start, end, NotePalette.normalizeMarkerColor(color));
    notifyListeners();
    return true;
  }

  bool clearHighlight() {
    final selected = selection;
    if (!selected.isValid || selected.isCollapsed) return false;
    final start = selected.start < selected.end ? selected.start : selected.end;
    final end = selected.start < selected.end ? selected.end : selected.start;
    _replaceRange(start, end, null);
    notifyListeners();
    return true;
  }

  void _replaceRange(int start, int end, String? color) {
    final next = <NoteHighlight>[];
    for (final item in _highlights) {
      if (item.end <= start || item.start >= end) {
        next.add(item);
        continue;
      }
      if (item.start < start) {
        next.add(item.copyWith(end: start));
      }
      if (item.end > end) {
        next.add(item.copyWith(start: end));
      }
    }
    if (color != null) {
      next.add(NoteHighlight(start: start, end: end, color: color));
    }
    _highlights = _normalize(next, text.length);
  }

  void _onTextChanged() {
    if (_handlingTextChange || text == _previousText) return;
    _handlingTextChange = true;
    try {
      _highlights = _remap(_highlights, _previousText, text);
      _previousText = text;
    } finally {
      _handlingTextChange = false;
    }
  }

  static List<NoteHighlight> _remap(
    List<NoteHighlight> source,
    String oldText,
    String newText,
  ) {
    var prefix = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (prefix < minLength && oldText[prefix] == newText[prefix]) {
      prefix++;
    }

    var suffix = 0;
    while (suffix < oldText.length - prefix &&
        suffix < newText.length - prefix &&
        oldText[oldText.length - 1 - suffix] ==
            newText[newText.length - 1 - suffix]) {
      suffix++;
    }

    final oldChangedEnd = oldText.length - suffix;
    final newChangedEnd = newText.length - suffix;
    final delta = newText.length - oldText.length;
    final next = <NoteHighlight>[];

    for (final item in source) {
      if (item.end <= prefix) {
        next.add(item);
      } else if (item.start >= oldChangedEnd) {
        next.add(
          item.copyWith(start: item.start + delta, end: item.end + delta),
        );
      } else {
        final start = item.start < prefix ? item.start : prefix;
        final end = item.end > oldChangedEnd ? item.end + delta : newChangedEnd;
        if (end > start) next.add(item.copyWith(start: start, end: end));
      }
    }
    return _normalize(next, newText.length);
  }

  static List<NoteHighlight> _normalize(
    List<NoteHighlight> source,
    int textLength,
  ) {
    final items =
        source
            .map(
              (item) => item.copyWith(
                start: item.start.clamp(0, textLength),
                end: item.end.clamp(0, textLength),
                color: NotePalette.normalizeMarkerColor(item.color),
              ),
            )
            .where((item) => item.end > item.start)
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    final normalized = <NoteHighlight>[];
    for (final item in items) {
      if (normalized.isNotEmpty && item.start < normalized.last.end) {
        final previous = normalized.removeLast();
        if (previous.start < item.start) {
          normalized.add(previous.copyWith(end: item.start));
        }
      }
      normalized.add(item);
    }
    return normalized;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_highlights.isEmpty || text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    final children = <InlineSpan>[];
    var offset = 0;
    for (final item in _highlights) {
      if (item.start > offset) {
        children.add(TextSpan(text: text.substring(offset, item.start)));
      }
      children.add(
        TextSpan(
          text: text.substring(item.start, item.end),
          style: TextStyle(
            backgroundColor: NotePalette.marker(item.color),
            color: const Color(0xFF111827),
          ),
        ),
      );
      offset = item.end;
    }
    if (offset < text.length) {
      children.add(TextSpan(text: text.substring(offset)));
    }
    return TextSpan(style: style, children: children);
  }

  @override
  void dispose() {
    removeListener(_onTextChanged);
    super.dispose();
  }
}
