import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../services/app_version_service.dart';
import '../services/feed_service.dart';
import '../services/location_flag_service.dart';
import '../services/push_service.dart';

import '../models/feed_item.dart';

import '../widgets/app_drawer.dart';
import '../widgets/header_card.dart';

import '../main.dart' show AppRoutes;
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _bootstrapped = false;

  DateTime _selectedDate = DateTime.now();

  final ScrollController _scrollController = ScrollController();

  bool _loadingFeed = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _feedError;

  final List<FeedItem> _feed = [];

  static const int _pageSize = 10;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      try {
        await _bootstrapOnce();
      } catch (_) {}

      try {
        await _syncTrackingFromCommanderFlag();
      } catch (_) {}

      try {
        await _loadFeed(reset: true);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= (pos.maxScrollExtent - 350)) {
      _loadMoreFeed();
    }
  }

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _bootstrapOnce() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    try {
      await PushService.ensurePermissions();
    } catch (_) {}

    try {
      PushService.listenTokenRefresh();
    } catch (_) {}

    try {
      await PushService.registerDeviceToken(reason: 'home_bootstrap');
    } catch (_) {}
  }

  Future<void> _syncTrackingFromCommanderFlag() async {
    try {
      final enabledByCommander = await LocationFlagService.isEnabledForMe();
      if (!mounted) return;

      final running = await FlutterForegroundTask.isRunningService;
      if (!mounted) return;

      if (!enabledByCommander) {
        if (running) {
          try {
            await TrackingService.stop();
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() => _trackingOn = false);
        return;
      }

      if (!running) {
        bool started = false;
        try {
          started = await TrackingService.startWithDisclosure(context);
        } catch (_) {
          started = false;
        }
        if (!mounted) return;
        setState(() => _trackingOn = started);
      } else {
        if (!mounted) return;
        setState(() => _trackingOn = true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _trackingOn = false);
    }
  }

  Future<void> _loadFeed({required bool reset}) async {
    if (_loadingFeed) return;

    if (mounted) {
      setState(() {
        _loadingFeed = true;
        _feedError = null;

        if (reset) {
          _feed.clear();
          _page = 1;
          _hasMore = true;
        }
      });
    }

    try {
      final limit = (_pageSize * _page).clamp(1, 50);

      final items = await FeedService.fetchFeed(
        limit: limit,
        date: _onlyDate(_selectedDate),
      );

      if (!mounted) return;

      final existingIds = _feed.map((e) => e.id).toSet();
      final newOnes = <FeedItem>[];

      for (final it in items) {
        if (!existingIds.contains(it.id)) {
          newOnes.add(it);
        }
      }

      setState(() {
        if (reset) {
          _feed.addAll(items);
        } else {
          _feed.addAll(newOnes);
        }

        if (items.length < limit) {
          _hasMore = false;
        } else {
          if (newOnes.isEmpty && _feed.isNotEmpty) {
            _hasMore = false;
          } else {
            _hasMore = true;
          }
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedError = 'No se pudo cargar el feed.');
    } finally {
      if (!mounted) return;
      setState(() => _loadingFeed = false);
    }
  }

  Future<void> _loadMoreFeed() async {
    if (_loadingFeed) return;
    if (_loadingMore) return;
    if (!_hasMore) return;
    if (_feedError != null) return;

    if (mounted) {
      setState(() => _loadingMore = true);
    }

    try {
      final nextPage = _page + 1;
      final nextLimit = (_pageSize * nextPage).clamp(1, 50);

      final items = await FeedService.fetchFeed(
        limit: nextLimit,
        date: _onlyDate(_selectedDate),
      );

      if (!mounted) return;

      final existingIds = _feed.map((e) => e.id).toSet();
      final newOnes = <FeedItem>[];

      for (final it in items) {
        if (!existingIds.contains(it.id)) {
          newOnes.add(it);
        }
      }

      setState(() {
        if (newOnes.isNotEmpty) {
          _feed.addAll(newOnes);
          _page = nextPage;
        }

        if (newOnes.isEmpty) {
          _hasMore = false;
        }

        if (items.length < nextLimit) {
          _hasMore = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _feedError = 'No se pudo cargar el feed.');
    } finally {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        await _syncTrackingFromCommanderFlag();
      } catch (_) {}

      try {
        await PushService.registerDeviceToken(reason: 'app_resumed');
      } catch (_) {}
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      try {
        await AuthService.logout();
      } catch (_) {}
    } finally {
      _busy = false;
    }

    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _go(BuildContext context, String route) {
    Navigator.pushNamed(context, route);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _onlyDate(_selectedDate);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = _onlyDate(picked);
    });

    await _loadFeed(reset: true);
  }

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _openFeedItem(FeedItem item) {
    if (item.type == FeedItemType.hecho) {
      Navigator.pushNamed(
        context,
        '/accidentes/show',
        arguments: {'hechoId': item.id},
      );
      return;
    }

    if (item.type == FeedItemType.actividad) {
      Navigator.pushNamed(
        context,
        AppRoutes.actividadesShow,
        arguments: {'actividad_id': item.id},
      );
    }
  }

  Future<void> _refreshAll() async {
    try {
      await _syncTrackingFromCommanderFlag();
    } catch (_) {}
    try {
      await _loadFeed(reset: true);
    } catch (_) {}
    try {
      await PushService.registerDeviceToken(reason: 'pull_to_refresh');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Sistema Estadístico'),
        actions: [
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () => _go(context, AppRoutes.hechosBuscar),
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshAll,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HeaderCard(trackingOn: _trackingOn),
                      const SizedBox(height: 16),
                      Text(
                        'Accesos rápidos',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickActionsGrid(
                        onAccidentes: () => _go(context, '/accidentes'),
                        onGruas: () => _go(context, '/gruas'),
                        onMapa: () => _go(context, '/mapa'),
                        onSustentoLegal: () => _go(context, '/sustento-legal'),
                        onBuscar: () => _go(context, AppRoutes.hechosBuscar),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.blue.withOpacity(.06),
                          border: Border.all(
                            color: Colors.blue.withOpacity(.18),
                          ),
                        ),
                        child: Text(
                          _trackingOn
                              ? 'Ubicación activa (enviando ubicación en segundo plano).'
                              : 'Ubicación inactiva (puede activarse desde el mapa de patrullas).',
                          style: TextStyle(color: Colors.blue.shade900),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Feed',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _fmtDate(_selectedDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: _buildFeedSliver(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeedSliver() {
    if (_loadingFeed && _feed.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_feedError != null && _feed.isEmpty) {
      return SliverToBoxAdapter(
        child: _ErrorCard(message: 'No se pudo cargar el feed.', onRetry: null),
      );
    }

    if (_feed.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyCard());
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index == _feed.length) {
          if (_feedError != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _ErrorInline(message: _feedError!, onRetry: _loadMoreFeed),
            );
          }

          if (_loadingMore) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (!_hasMore) {
            return const SizedBox(height: 12);
          }

          return const SizedBox(height: 12);
        }

        final item = _feed[index];
        return Padding(
          padding: EdgeInsets.only(bottom: index == _feed.length - 1 ? 0 : 12),
          child: _FeedPostCard(item: item, onTap: () => _openFeedItem(item)),
        );
      }, childCount: _feed.length + 1),
    );
  }
}

class _FeedPostCard extends StatelessWidget {
  final FeedItem item;
  final VoidCallback onTap;

  const _FeedPostCard({required this.item, required this.onTap});

  String get _typeLabel {
    if (item.type == FeedItemType.hecho) return 'SINIESTRO';
    if (item.type == FeedItemType.actividad) return 'PROXIMIDAD SOCIAL';
    return 'PUBLICACIÓN';
  }

  IconData get _icon {
    if (item.type == FeedItemType.hecho) return Icons.car_crash;
    if (item.type == FeedItemType.actividad) return Icons.camera_alt;
    return Icons.feed;
  }

  @override
  Widget build(BuildContext context) {
    final resumen = item.resumen.trim();
    final subtitle = resumen.isNotEmpty ? resumen : 'Publicación';

    final user = item.userName.trim().isNotEmpty
        ? item.userName.trim()
        : 'Usuario';

    final fotoUrl = (item.fotoUrl != null && item.fotoUrl!.trim().isNotEmpty)
        ? item.fotoUrl!.trim()
        : null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_icon, color: Colors.blue, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  user,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Text(
                                  _typeLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (fotoUrl != null) ...[
                Divider(height: 1, color: Colors.grey.shade200),
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  child: _BigFeedImage(url: fotoUrl),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BigFeedImage extends StatelessWidget {
  final String url;
  const _BigFeedImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade100,
      child: AspectRatio(
        aspectRatio: 1,
        child: Image.network(
          url,
          fit: BoxFit.contain,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return const Center(child: CircularProgressIndicator());
          },
          errorBuilder: (_, __, ___) => Center(
            child: Icon(
              Icons.broken_image,
              color: Colors.grey.shade500,
              size: 34,
            ),
          ),
        ),
      ),
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

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onAccidentes;
  final VoidCallback onGruas;
  final VoidCallback onMapa;
  final VoidCallback onSustentoLegal;
  final VoidCallback onBuscar;

  const _QuickActionsGrid({
    required this.onAccidentes,
    required this.onGruas,
    required this.onMapa,
    required this.onSustentoLegal,
    required this.onBuscar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.search,
                title: 'Búsqueda',
                subtitle: 'Por placa, serie, conductor…',
                onTap: onBuscar,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.directions_car,
                title: 'Hechos / Accidentes',
                subtitle: 'Listado y registros',
                onTap: onAccidentes,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.local_shipping,
                title: 'Grúas',
                subtitle: 'Listado y gráfica',
                onTap: onGruas,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _QuickCard(
                icon: Icons.map,
                title: 'Mapa de Patrullas',
                subtitle: 'Ubicaciones activas',
                onTap: onMapa,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _QuickCard(
                icon: Icons.gavel,
                title: 'Sustento Legal',
                subtitle: 'Catálogo y consulta',
                onTap: onSustentoLegal,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
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
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.blue, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade500),
            ],
          ),
        ),
      ),
    );
  }
}
