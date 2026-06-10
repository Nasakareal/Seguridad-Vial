import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/app_version_service.dart';
import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';
import '../services/location_flag_service.dart';
import '../services/tracking_service.dart';
import '../widgets/account_drawer.dart';
import '../widgets/app_drawer.dart';
import '../widgets/offline_sync_status_card.dart';
import 'login_screen.dart';

class HomeAgenteVialScreen extends StatefulWidget {
  const HomeAgenteVialScreen({super.key});

  @override
  State<HomeAgenteVialScreen> createState() => _HomeAgenteVialScreenState();
}

class _HomeAgenteVialScreenState extends State<HomeAgenteVialScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
      } catch (_) {}

      if (!mounted) return;
      final allowed = await HomeResolverService.isAgenteVialHomeAvailable();
      if (!mounted) return;
      if (!allowed) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (_) => false,
        );
        return;
      }

      await _syncTrackingFromCommanderFlag();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncTrackingFromCommanderFlag();
    }
  }

  Future<void> _syncTrackingFromCommanderFlag() async {
    try {
      final enabledByCommander = await LocationFlagService.isEnabledForMe();
      if (!mounted) return;

      var running = await TrackingService.isRunning();
      if (!mounted) return;

      if (!running) {
        bool started = false;
        try {
          started = await TrackingService.startWithDisclosure(context);
        } catch (_) {
          started = false;
        }
        if (!mounted) return;
        running = started;
      }

      if (!mounted) return;
      setState(() => _trackingOn = enabledByCommander && running);
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
      await AuthService.logout();
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

  Future<void> _openPreset(_AgenteVialPreset preset) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.actividadesCreate,
      arguments: <String, dynamic>{'actividadPrefill': preset.toPrefill()},
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _agenteVialSections();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Inicio Agente Vial'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: const [AccountMenuAction()],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _Header(trackingOn: _trackingOn),
            const SizedBox(height: 12),
            const _PrimaryActions(),
            const SizedBox(height: 12),
            const OfflineSyncStatusCard(),
            const SizedBox(height: 12),
            for (final section in sections) ...[
              _SectionCard(section: section, onTap: _openPreset),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool trackingOn;

  const _Header({required this.trackingOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Agente Vial',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Unidad de Proteccion en Vialidades Urbanas',
            style: TextStyle(fontSize: 15, height: 1.25),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                icon: trackingOn
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
                label: trackingOn ? 'Ubicacion activa' : 'Ubicacion inactiva',
                color: trackingOn
                    ? const Color(0xFF15803D)
                    : const Color(0xFF64748B),
              ),
              const _StatusChip(
                icon: Icons.notifications_off_outlined,
                label: 'Sin alertas Waze',
                color: Color(0xFFB45309),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PrimaryActions extends StatelessWidget {
  const _PrimaryActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () =>
              Navigator.pushNamed(context, AppRoutes.actividadesCreate),
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('Capturar actividad'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.actividades),
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Actividades'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.offlineSyncErrors),
                icon: const Icon(Icons.sync_problem_outlined),
                label: const Text('Pendientes'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _AgenteVialSection section;
  final ValueChanged<_AgenteVialPreset> onTap;

  const _SectionCard({required this.section, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: section.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(section.icon, color: section.color, size: 30),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in section.presets)
                  _PresetButton(
                    label: preset.label,
                    color: section.color,
                    onTap: () => onTap(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PresetButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 46, minWidth: 132),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withValues(alpha: 0.38)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AgenteVialSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_AgenteVialPreset> presets;

  const _AgenteVialSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.presets,
  });
}

class _AgenteVialPreset {
  static const int abanderamientos = 3;
  static const int monitoreos = 6;
  static const int auxilioVial = 7;
  static const int dispositivos = 8;

  final String label;
  final int categoriaId;
  final int subcategoriaId;
  final String motivo;

  const _AgenteVialPreset({
    required this.label,
    required this.categoriaId,
    required this.subcategoriaId,
    required this.motivo,
  });

  Map<String, String> toPrefill() {
    return {
      'source': 'agente_vial_home',
      'actividad_categoria_id': categoriaId.toString(),
      'actividad_subcategoria_id': subcategoriaId.toString(),
      'municipio': 'MORELIA',
      'motivo': motivo,
      'personas_alcanzadas': '1',
      'personas_participantes': '1',
      'personas_detenidas': '0',
      'elementos_participantes_texto': '1 elemento',
      'patrullas_participantes_texto': 'CRP / Deltas',
    };
  }
}

List<_AgenteVialSection> _agenteVialSections() {
  return const [
    _AgenteVialSection(
      title: 'Atencion vial',
      icon: Icons.traffic,
      color: Color(0xFF2563EB),
      presets: [
        _AgenteVialPreset(
          label: 'Accidente',
          categoriaId: _AgenteVialPreset.abanderamientos,
          subcategoriaId: 17,
          motivo: 'Abanderamiento por hecho de transito',
        ),
        _AgenteVialPreset(
          label: 'Corte vial',
          categoriaId: _AgenteVialPreset.abanderamientos,
          subcategoriaId: 16,
          motivo: 'Corte de circulacion',
        ),
        _AgenteVialPreset(
          label: 'Auxilio vial',
          categoriaId: _AgenteVialPreset.auxilioVial,
          subcategoriaId: 44,
          motivo: 'Auxilio a conductor',
        ),
      ],
    ),
    _AgenteVialSection(
      title: 'Dispositivos y presencia',
      icon: Icons.route_outlined,
      color: Color(0xFF0F766E),
      presets: [
        _AgenteVialPreset(
          label: 'Apoyo vial',
          categoriaId: _AgenteVialPreset.dispositivos,
          subcategoriaId: 49,
          motivo: 'Apoyo a la vialidad',
        ),
        _AgenteVialPreset(
          label: 'Paso peatonal',
          categoriaId: _AgenteVialPreset.dispositivos,
          subcategoriaId: 52,
          motivo: 'Apoyo en paso peatonal',
        ),
        _AgenteVialPreset(
          label: 'Proteccion',
          categoriaId: _AgenteVialPreset.dispositivos,
          subcategoriaId: 53,
          motivo: 'Medidas de proteccion',
        ),
        _AgenteVialPreset(
          label: 'Patrullaje',
          categoriaId: _AgenteVialPreset.dispositivos,
          subcategoriaId: 54,
          motivo: 'Patrullaje preventivo',
        ),
      ],
    ),
    _AgenteVialSection(
      title: 'Monitoreos frecuentes',
      icon: Icons.visibility_outlined,
      color: Color(0xFF7C3AED),
      presets: [
        _AgenteVialPreset(
          label: 'Bancos',
          categoriaId: _AgenteVialPreset.monitoreos,
          subcategoriaId: 39,
          motivo: 'Monitoreo preventivo en bancos',
        ),
        _AgenteVialPreset(
          label: 'Tiendas',
          categoriaId: _AgenteVialPreset.monitoreos,
          subcategoriaId: 38,
          motivo: 'Monitoreo preventivo en tiendas departamentales',
        ),
        _AgenteVialPreset(
          label: 'Oficinas',
          categoriaId: _AgenteVialPreset.monitoreos,
          subcategoriaId: 41,
          motivo: 'Monitoreo preventivo en oficinas publicas',
        ),
        _AgenteVialPreset(
          label: 'Otro',
          categoriaId: _AgenteVialPreset.monitoreos,
          subcategoriaId: 43,
          motivo: 'Otro monitoreo preventivo',
        ),
      ],
    ),
  ];
}
