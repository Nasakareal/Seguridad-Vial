import 'dart:async';
import 'package:flutter/material.dart';

import 'package:seguridad_vial_app/app/routes.dart';

import '../services/auth_service.dart';
import '../services/app_version_service.dart';
import '../services/push_service.dart';

import '../widgets/app_drawer.dart';
import '../widgets/header_card.dart';
import '../widgets/offline_sync_status_card.dart';

import 'login_screen.dart';

import 'home/controllers/home_permissions_controller.dart';
import 'home/controllers/home_tracking_controller.dart';
import 'home/controllers/home_feed_controller.dart';
import 'home/widgets/quick_actions_grid.dart';
import 'home/widgets/feed_sliver.dart';

import '../models/feed_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _busy = false;
  bool _bootstrapped = false;

  final ScrollController _scrollController = ScrollController();

  final HomePermissionsController _permsCtrl = HomePermissionsController();
  final HomeTrackingController _trackingCtrl = HomeTrackingController();
  final HomeFeedController _feedCtrl = HomeFeedController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
        if (!mounted) return;
      } catch (_) {}

      try {
        await _bootstrapOnce();
        if (!mounted) return;
      } catch (_) {}

      try {
        await _permsCtrl.load(force: true);
        if (!mounted) return;
      } catch (_) {}

      try {
        await _trackingCtrl.syncFromCommanderFlag(context);
        if (!mounted) return;
      } catch (_) {}

      try {
        _feedCtrl.setDate(_feedCtrl.onlyDate(DateTime.now()));
        await _feedCtrl.load(reset: true);
        if (!mounted) return;
      } catch (_) {}

      if (!mounted) return;
      _permsCtrl.startSoftRefresh();
    });
  }

  @override
  void dispose() {
    _permsCtrl.dispose();
    _trackingCtrl.dispose();
    _feedCtrl.dispose();

    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= (pos.maxScrollExtent - 350)) {
      _feedCtrl.loadMore();
    }
  }

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
      Future.delayed(const Duration(seconds: 1), () {
        PushService.registerDeviceToken(reason: 'home_bootstrap');
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        await _permsCtrl.load(force: true);
        if (!mounted) return;
      } catch (_) {}

      try {
        await _trackingCtrl.syncFromCommanderFlag(context);
        if (!mounted) return;
      } catch (_) {}

      try {
        Future.delayed(const Duration(milliseconds: 300), () {
          PushService.registerDeviceToken(reason: 'app_resumed');
        });
      } catch (_) {}
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await _trackingCtrl.stop();
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
    final initial = _feedCtrl.onlyDate(_feedCtrl.selectedDate.value);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked == null) return;

    _feedCtrl.setDate(picked);
    await _feedCtrl.load(reset: true);
  }

  String _fmtDate(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  void _openFeedItem(FeedItem item) {
    if (item.type == FeedItemType.hecho) {
      Navigator.pushNamed(
        context,
        AppRoutes.accidentesShow,
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
      await _trackingCtrl.syncFromCommanderFlag(context);
      if (!mounted) return;
    } catch (_) {}

    try {
      await _permsCtrl.load(force: true);
      if (!mounted) return;
    } catch (_) {}

    try {
      await _feedCtrl.load(reset: true);
      if (!mounted) return;
    } catch (_) {}

    try {
      Future.delayed(const Duration(milliseconds: 250), () {
        PushService.registerDeviceToken(reason: 'pull_to_refresh');
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ValueListenableBuilder<bool>(
      valueListenable: _permsCtrl.loading,
      builder: (context, loadingPerms, _) {
        final canBuscar =
            !loadingPerms &&
            _permsCtrl.allowed(HomePermissionsController.permBusqueda);
        final canHechos =
            !loadingPerms &&
            _permsCtrl.allowed(HomePermissionsController.permHechos);
        final canGruas =
            !loadingPerms &&
            _permsCtrl.allowed(HomePermissionsController.permGruas);
        final canMapa =
            !loadingPerms &&
            _permsCtrl.allowed(HomePermissionsController.permMapa);
        final canSustento =
            !loadingPerms &&
            _permsCtrl.allowed(HomePermissionsController.permSustento);

        return ValueListenableBuilder<bool>(
          valueListenable: _trackingCtrl.trackingOn,
          builder: (context, trackingOn, __) {
            return Scaffold(
              backgroundColor: const Color(0xFFF6F7FB),
              appBar: AppBar(
                elevation: 0,
                backgroundColor: Colors.blue,
                title: const Text('Sistema Estadístico'),
                actions: [
                  if (canBuscar)
                    IconButton(
                      tooltip: 'Buscar',
                      icon: const Icon(Icons.search),
                      onPressed: () => _go(context, AppRoutes.hechosBuscar),
                    ),
                ],
              ),
              drawer: AppDrawer(
                trackingOn: trackingOn,
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
                              HeaderCard(trackingOn: trackingOn),
                              const SizedBox(height: 12),
                              const OfflineSyncStatusCard(),
                              const SizedBox(height: 16),
                              Text(
                                'Accesos rápidos',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 12),
                              QuickActionsGrid(
                                canBuscar: canBuscar,
                                canAccidentes: canHechos,
                                canGruas: canGruas,
                                canMapa: canMapa,
                                canSustento: canSustento,
                                onAccidentes: () =>
                                    _go(context, AppRoutes.accidentes),
                                onGruas: () => _go(context, AppRoutes.gruas),
                                onMapa: () => _go(context, AppRoutes.mapa),
                                onSustentoLegal: () =>
                                    _go(context, AppRoutes.sustentoLegal),
                                onBuscar: () =>
                                    _go(context, AppRoutes.hechosBuscar),
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: Colors.blue.withValues(alpha: 0.06),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.18),
                                  ),
                                ),
                                child: Text(
                                  trackingOn
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
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
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
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.calendar_month,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 8),
                                          ValueListenableBuilder<DateTime>(
                                            valueListenable:
                                                _feedCtrl.selectedDate,
                                            builder: (_, d, __) {
                                              return Text(
                                                _fmtDate(d),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              );
                                            },
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
                        sliver: ValueListenableBuilder<bool>(
                          valueListenable: _feedCtrl.loadingFeed,
                          builder: (context, loadingFeed, _) {
                            return ValueListenableBuilder<bool>(
                              valueListenable: _feedCtrl.loadingMore,
                              builder: (context, loadingMore, __) {
                                return ValueListenableBuilder<bool>(
                                  valueListenable: _feedCtrl.hasMore,
                                  builder: (context, hasMore, ___) {
                                    return ValueListenableBuilder<String?>(
                                      valueListenable: _feedCtrl.error,
                                      builder: (context, feedError, ____) {
                                        return ValueListenableBuilder<
                                          List<FeedItem>
                                        >(
                                          valueListenable: _feedCtrl.feed,
                                          builder: (context, feed, _____) {
                                            return FeedSliver(
                                              loadingFeed: loadingFeed,
                                              loadingMore: loadingMore,
                                              hasMore: hasMore,
                                              feedError: feedError,
                                              feed: feed,
                                              onLoadMore: _feedCtrl.loadMore,
                                              onOpen: _openFeedItem,
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
