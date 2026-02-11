import 'package:flutter/material.dart';
import '../../models/feed_item.dart';
import 'feed_item_card.dart';

class FeedList extends StatelessWidget {
  final List<FeedItem> items;
  final bool loading;
  final String? error;
  final void Function(FeedItem item) onTapItem;

  const FeedList({
    super.key,
    required this.items,
    required this.loading,
    required this.error,
    required this.onTapItem,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            error!,
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Text(
            'Sin publicaciones.',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          FeedItemCard(item: items[i], onTap: () => onTapItem(items[i])),
          if (i != items.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
