import 'package:flutter/foundation.dart';

import '../../../models/feed_item.dart';
import '../../../services/feed_service.dart';

class HomeFeedController {
  final ValueNotifier<bool> loadingFeed = ValueNotifier<bool>(false);
  final ValueNotifier<bool> loadingMore = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasMore = ValueNotifier<bool>(true);
  final ValueNotifier<String?> error = ValueNotifier<String?>(null);

  final ValueNotifier<DateTime> selectedDate = ValueNotifier<DateTime>(
    DateTime.now(),
  );
  final ValueNotifier<List<FeedItem>> feed = ValueNotifier<List<FeedItem>>(
    <FeedItem>[],
  );

  static const int _pageSize = 10;
  int _page = 1;

  DateTime onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  void setDate(DateTime d) {
    selectedDate.value = onlyDate(d);
  }

  Future<void> load({required bool reset}) async {
    if (loadingFeed.value) return;

    loadingFeed.value = true;
    error.value = null;

    if (reset) {
      feed.value = <FeedItem>[];
      _page = 1;
      hasMore.value = true;
    }

    try {
      final limit = (_pageSize * _page).clamp(1, 50);

      final items = await FeedService.fetchFeed(
        limit: limit,
        date: onlyDate(selectedDate.value),
      );

      final current = feed.value;
      final existingIds = current.map((e) => e.id).toSet();

      final newOnes = <FeedItem>[];
      for (final it in items) {
        if (!existingIds.contains(it.id)) newOnes.add(it);
      }

      if (reset) {
        feed.value = List<FeedItem>.from(items);
      } else {
        feed.value = List<FeedItem>.from(current)..addAll(newOnes);
      }

      if (items.length < limit) {
        hasMore.value = false;
      } else {
        if (newOnes.isEmpty && feed.value.isNotEmpty) {
          hasMore.value = false;
        } else {
          hasMore.value = true;
        }
      }
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
    if (error.value != null) return;

    loadingMore.value = true;

    try {
      final nextPage = _page + 1;
      final nextLimit = (_pageSize * nextPage).clamp(1, 50);

      final items = await FeedService.fetchFeed(
        limit: nextLimit,
        date: onlyDate(selectedDate.value),
      );

      final current = feed.value;
      final existingIds = current.map((e) => e.id).toSet();

      final newOnes = <FeedItem>[];
      for (final it in items) {
        if (!existingIds.contains(it.id)) newOnes.add(it);
      }

      if (newOnes.isNotEmpty) {
        _page = nextPage;
        feed.value = List<FeedItem>.from(current)..addAll(newOnes);
      }

      if (newOnes.isEmpty) hasMore.value = false;
      if (items.length < nextLimit) hasMore.value = false;
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
    selectedDate.dispose();
    feed.dispose();
  }
}
