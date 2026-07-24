import 'package:flutter/foundation.dart';

import '../../../models/feed_item.dart';
import '../../../services/auth_service.dart';
import '../../../services/feed_service.dart';

class HomeFeedController {
  final ValueNotifier<bool> loadingFeed = ValueNotifier<bool>(false);
  final ValueNotifier<bool> loadingMore = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasMore = ValueNotifier<bool>(true);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);
  final ValueNotifier<bool> puedeFiltrarUnidades = ValueNotifier<bool>(false);
  final ValueNotifier<int?> selectedUnidadId = ValueNotifier<int?>(null);
  final ValueNotifier<int?> selectedDelegacionId = ValueNotifier<int?>(null);
  final ValueNotifier<List<FeedUnidad>> unidadesDisponibles =
      ValueNotifier<List<FeedUnidad>>(<FeedUnidad>[]);
  final ValueNotifier<List<FeedDelegacion>> delegacionesDisponibles =
      ValueNotifier<List<FeedDelegacion>>(<FeedDelegacion>[]);

  final ValueNotifier<DateTime> selectedDate = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  final ValueNotifier<List<FeedItem>> feed = ValueNotifier<List<FeedItem>>(
    <FeedItem>[],
  );

  static const int _pageSize = 10;
  int _page = 1;
  String? _nextCursor;
  bool _usesCursorPagination = true;

  DateTime onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  void setDate(DateTime d) {
    selectedDate.value = onlyDate(d);
  }

  void setUnidadFilter(int? unidadId) {
    selectedUnidadId.value = (unidadId != null && unidadId > 0)
        ? unidadId
        : null;

    if (selectedUnidadId.value != AuthService.unidadDelegacionesId) {
      selectedDelegacionId.value = null;
    }
  }

  void setDelegacionFilter(int? delegacionId) {
    selectedDelegacionId.value = (delegacionId != null && delegacionId > 0)
        ? delegacionId
        : null;
  }

  Future<void> load({required bool reset}) async {
    if (loadingFeed.value) return;

    loadingFeed.value = true;
    error.value = null;

    if (reset) {
      feed.value = <FeedItem>[];
      _page = 1;
      _nextCursor = null;
      _usesCursorPagination = true;
      hasMore.value = true;
    }

    try {
      final limit = reset || _usesCursorPagination
          ? _pageSize
          : (_pageSize * _page).clamp(1, 50);

      final response = await FeedService.fetchFeed(
        limit: limit,
        cursor: reset || !_usesCursorPagination ? null : _nextCursor,
        date: onlyDate(selectedDate.value),
        unidadId: selectedUnidadId.value,
        delegacionId: selectedUnidadId.value == AuthService.unidadDelegacionesId
            ? selectedDelegacionId.value
            : null,
      );
      _syncMetadata(response);
      final items = response.items;

      final current = feed.value;
      final existingIds = current.map(_feedKey).toSet();

      final newOnes = <FeedItem>[];
      for (final it in items) {
        if (!existingIds.contains(_feedKey(it))) newOnes.add(it);
      }

      if (reset) {
        feed.value = List<FeedItem>.from(items);
      } else {
        feed.value = List<FeedItem>.from(current)..addAll(newOnes);
      }

      _usesCursorPagination = response.usesCursorPagination;
      _nextCursor = response.nextCursor;
      hasMore.value =
          response.hasMore &&
          (!_usesCursorPagination || _nextCursor != null) &&
          (reset || newOnes.isNotEmpty || feed.value.isEmpty);
    } catch (_) {
      error.value = 'No se pudo cargar el feed.';
    } finally {
      loadingFeed.value = false;
    }
  }

  Future<void> loadMore() async {
    if (loadingFeed.value) return;
    if (loadingMore.value) return;
    if (!hasMore.value) return;
    loadingMore.value = true;
    error.value = null;

    try {
      final nextPage = _page + 1;
      final nextLimit = _usesCursorPagination
          ? _pageSize
          : (_pageSize * nextPage).clamp(1, 50);

      final response = await FeedService.fetchFeed(
        limit: nextLimit,
        cursor: _usesCursorPagination ? _nextCursor : null,
        date: onlyDate(selectedDate.value),
        unidadId: selectedUnidadId.value,
        delegacionId: selectedUnidadId.value == AuthService.unidadDelegacionesId
            ? selectedDelegacionId.value
            : null,
      );
      _syncMetadata(response);
      final items = response.items;

      final current = feed.value;
      final existingIds = current.map(_feedKey).toSet();

      final newOnes = <FeedItem>[];
      for (final it in items) {
        if (!existingIds.contains(_feedKey(it))) newOnes.add(it);
      }

      if (newOnes.isNotEmpty) {
        _page = nextPage;
        feed.value = List<FeedItem>.from(current)..addAll(newOnes);
      }

      _usesCursorPagination = response.usesCursorPagination;
      _nextCursor = response.nextCursor;
      hasMore.value =
          newOnes.isNotEmpty &&
          response.hasMore &&
          (!_usesCursorPagination || _nextCursor != null);
    } catch (_) {
      error.value = 'No se pudo cargar el feed.';
    } finally {
      loadingMore.value = false;
    }
  }

  void dispose() {
    loadingFeed.dispose();
    loadingMore.dispose();
    hasMore.dispose();
    error.dispose();
    puedeFiltrarUnidades.dispose();
    selectedUnidadId.dispose();
    selectedDelegacionId.dispose();
    unidadesDisponibles.dispose();
    delegacionesDisponibles.dispose();
    selectedDate.dispose();
    feed.dispose();
  }

  void _syncMetadata(FeedResponse response) {
    puedeFiltrarUnidades.value = response.puedeFiltrarUnidades;
    if (response.unidadesFiltrables.isNotEmpty) {
      unidadesDisponibles.value = List<FeedUnidad>.from(
        response.unidadesFiltrables,
      );
    }

    delegacionesDisponibles.value = List<FeedDelegacion>.from(
      response.delegacionesFiltrables,
    );

    if (selectedDelegacionId.value != null &&
        !response.delegacionesFiltrables.any(
          (delegacion) => delegacion.id == selectedDelegacionId.value,
        )) {
      selectedDelegacionId.value = null;
    }
  }

  String _feedKey(FeedItem item) => '${item.type.name}:${item.id}';
}
