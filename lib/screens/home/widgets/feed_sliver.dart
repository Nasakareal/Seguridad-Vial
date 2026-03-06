import 'package:flutter/material.dart';
import '../../../models/feed_item.dart';
import 'feed_post_card.dart';

class FeedSliver extends StatelessWidget {
  final bool loadingFeed;
  final bool loadingMore;
  final bool hasMore;
  final String? feedError;
  final List<FeedItem> feed;

  final VoidCallback onLoadMore;
  final void Function(FeedItem item) onOpen;

  const FeedSliver({
    super.key,
    required this.loadingFeed,
    required this.loadingMore,
    required this.hasMore,
    required this.feedError,
    required this.feed,
    required this.onLoadMore,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (loadingFeed && feed.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (feedError != null && feed.isEmpty) {
      return SliverToBoxAdapter(
        child: _ErrorCard(message: 'No se pudo cargar el feed.', onRetry: null),
      );
    }

    if (feed.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyCard());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == feed.length) {
          if (feedError != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ErrorInline(message: feedError!, onRetry: onLoadMore),
            );
          }

          if (loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (!hasMore) {
            return const SizedBox(height: 12);
          }

          return const SizedBox(height: 12);
        }

        final item = feed[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == feed.length - 1 ? 0 : 12),
          child: FeedPostCard(item: item, onTap: () => onOpen(item)),
        );
      }, childCount: feed.length + 1),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: const Center(
        child: Text(
          'Sin publicaciones en este día.',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(.06),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            message,
            style: const TextStyle(
              color: Colors.red,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorInline extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorInline({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.red.withOpacity(.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
