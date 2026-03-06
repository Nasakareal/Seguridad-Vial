import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../services/app_version_service.dart';
import '../services/location_flag_service.dart';
import '../services/push_service.dart';

import '../widgets/app_drawer.dart';
import '../widgets/header_card.dart';
import '../widgets/riesgo_map_embed.dart';

import '../../app/routes.dart';
import 'login_screen.dart';

class HomePeritoScreen extends StatefulWidget {
  const HomePeritoScreen({super.key});

  @override
  State<HomePeritoScreen> createState() => _HomePeritoScreenState();
}

class _HomePeritoScreenState extends State<HomePeritoScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;
  bool _bootstrapped = false;

  Set<String> _perms = {};
  bool _loadingPerms = true;
  bool _fetchingPerms = false;

  Timer? _permTimer;

  bool _alreadyRedirected = false;

  static const String permHomePerito = 'ver home perito';

  bool _allowed(String p) => _perms.contains(p.trim().toLowerCase());
  bool get _canHomePerito => _allowed(permHomePerito);

  Future<void> _loadPerms({bool force = false}) async {
    if (_fetchingPerms) return;
    _fetchingPerms = true;

    try {
      final list = await AuthService.refreshPermissions();
      if (!mounted) return;

      final set = list.map((e) => e.trim().toLowerCase()).toSet();

      setState(() {
        _perms = set;
        _loadingPerms = false;
      });

      // Evita ping-pong
      if (!_canHomePerito && !_alreadyRedirected) {
        _alreadyRedirected = true;
        if (!mounted) return;
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil(AppRoutes.home, (_) => false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPerms = false);
    } finally {
      _fetchingPerms = false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      try {
        await _bootstrapOnce();
      } catch (_) {}

      try {
        await _loadPerms(force: true);
      } catch (_) {}

      try {
        await _syncTrackingFromCommanderFlag();
      } catch (_) {}

      _startPermSoftRefresh();
    });
  }

  void _startPermSoftRefresh() {
    _permTimer?.cancel();
    _permTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      _loadPerms();
    });
  }

  @override
  void dispose() {
    _permTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
        PushService.registerDeviceToken(reason: 'home_perito_bootstrap');
      });
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

  Future<void> _refreshAll() async {
    try {
      await _syncTrackingFromCommanderFlag();
    } catch (_) {}

    try {
      _alreadyRedirected = false; // permite re-evaluar si cambió el permiso
      await _loadPerms(force: true);
    } catch (_) {}

    try {
      Future.delayed(const Duration(milliseconds: 250), () {
        PushService.registerDeviceToken(reason: 'home_perito_refresh');
      });
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      try {
        _alreadyRedirected = false;
        await _loadPerms(force: true);
      } catch (_) {}

      try {
        await _syncTrackingFromCommanderFlag();
      } catch (_) {}

      try {
        Future.delayed(const Duration(milliseconds: 300), () {
          PushService.registerDeviceToken(reason: 'home_perito_resumed');
        });
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = !_loadingPerms;
    final allowed = _canHomePerito;
    final showMap = ready && allowed;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Perito'),
        actions: [
          IconButton(
            tooltip: 'Recargar',
            icon: const Icon(Icons.refresh),
            onPressed: _refreshAll,
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
          child: showMap
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      child: HeaderCard(trackingOn: _trackingOn),
                    ),
                    SizedBox(
                      height:
                          MediaQuery.of(context).size.height -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.top -
                          16 -
                          12 -
                          120,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: RiesgoMapEmbed(
                          precision: 2,
                          ventanaMin: 60,
                          wazeHoras: 24,
                          top: 60,
                          minScore: 2.0,
                        ),
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    const SizedBox(height: 60),
                    const Center(child: CircularProgressIndicator()),
                    const SizedBox(height: 12),
                    Text(
                      _loadingPerms
                          ? 'Cargando permisos…'
                          : 'Sin permiso para Home Perito.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
