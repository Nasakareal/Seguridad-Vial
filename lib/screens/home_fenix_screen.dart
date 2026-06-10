import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/auth_service.dart';
import '../services/tracking_service.dart';
import '../widgets/account_drawer.dart';
import '../widgets/app_drawer.dart';
import '../widgets/offline_sync_status_card.dart';
import 'login_screen.dart';

class HomeFenixScreen extends StatefulWidget {
  const HomeFenixScreen({super.key});

  @override
  State<HomeFenixScreen> createState() => _HomeFenixScreenState();
}

class _HomeFenixScreenState extends State<HomeFenixScreen> {
  bool _busy = false;

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

  Future<void> _openPreset(_FenixPreset preset) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.actividadesCreate,
      arguments: <String, dynamic>{'actividadPrefill': preset.toPrefill()},
    );
  }

  Future<void> _openPlace(String place) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.actividadesCreate,
      arguments: <String, dynamic>{
        'actividadPrefill': _FenixPreset.placeOnly(place),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = _fenixSections();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Inicio Fénix'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: const [AccountMenuAction()],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            const _Header(),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.actividadesCreate),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Capturar actividad normal'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                textStyle: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const OfflineSyncStatusCard(),
            const SizedBox(height: 12),
            for (final section in sections) ...[
              _SectionCard(section: section, onTap: _openPreset),
              const SizedBox(height: 12),
            ],
            _FrequentPlacesCard(
              places: const [
                'Av. Madero',
                'Casa Michoacán',
                'Paso peatonal SSP',
                'Periférico y Pepsi',
                'Vías férreas',
                'Zona Centro',
                'Bancos Madero',
              ],
              onTap: _openPlace,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inicio Fénix / Pie Tierra',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Selecciona el tipo de actividad que vas a reportar.',
            style: TextStyle(fontSize: 15, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final _FenixSection section;
  final ValueChanged<_FenixPreset> onTap;

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

class _FrequentPlacesCard extends StatelessWidget {
  final List<String> places;
  final ValueChanged<String> onTap;

  const _FrequentPlacesCard({required this.places, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF0F766E);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bookmark_border, color: color),
                SizedBox(width: 8),
                Text(
                  'Mis puntos frecuentes',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final place in places)
                  ActionChip(
                    avatar: const Icon(Icons.place_outlined, size: 18),
                    label: Text(place),
                    onPressed: () => onTap(place),
                    side: BorderSide(color: color.withValues(alpha: 0.28)),
                    labelStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FenixSection {
  final String title;
  final IconData icon;
  final Color color;
  final List<_FenixPreset> presets;

  const _FenixSection({
    required this.title,
    required this.icon,
    required this.color,
    required this.presets,
  });
}

class _FenixPreset {
  static const int instituciones = 1;
  static const int abanderamientos = 3;
  static const int operativos = 4;
  static const int monitoreos = 6;
  static const int auxilioVial = 7;
  static const int dispositivos = 8;
  static const int proximidad = 11;

  final String label;
  final int categoriaId;
  final int subcategoriaId;
  final String motivo;
  final String? lugar;

  const _FenixPreset({
    required this.label,
    required this.categoriaId,
    required this.subcategoriaId,
    required this.motivo,
    this.lugar,
  });

  Map<String, String> toPrefill() {
    final place = (lugar ?? '').trim();
    return {
      'source': 'fenix_home',
      'actividad_categoria_id': categoriaId.toString(),
      'actividad_subcategoria_id': subcategoriaId.toString(),
      'municipio': 'MORELIA',
      if (place.isNotEmpty) 'lugar': place,
      'motivo': motivo,
      'narrativa': _narrative(motivo, place),
      'observaciones': 'Reporte Fénix / Pie Tierra: $label',
      'personas_alcanzadas': '1',
      'personas_participantes': '1',
      'personas_detenidas': '0',
      'elementos_participantes_texto': '1 elemento',
      'patrullas_participantes_texto': 'FÉNIX / PIE TIERRA',
    };
  }

  static Map<String, String> placeOnly(String place) {
    final cleanPlace = place.trim();
    return {
      'source': 'fenix_lugar_frecuente',
      'municipio': 'MORELIA',
      'lugar': cleanPlace,
      'motivo': 'Actividad Fénix / Pie Tierra',
      'narrativa':
          'Se registra punto frecuente para captura de actividad Fénix / Pie Tierra en $cleanPlace.',
      'observaciones': 'Punto frecuente Fénix / Pie Tierra: $cleanPlace',
      'personas_alcanzadas': '1',
      'personas_participantes': '1',
      'personas_detenidas': '0',
      'elementos_participantes_texto': '1 elemento',
      'patrullas_participantes_texto': 'FÉNIX / PIE TIERRA',
    };
  }

  static String _narrative(String motivo, String place) {
    final location = place.trim().isEmpty ? 'la ubicación registrada' : place;
    return 'Se informa actividad Fénix / Pie Tierra en $location, correspondiente a $motivo.';
  }
}

List<_FenixSection> _fenixSections() {
  return const [
    _FenixSection(
      title: 'Dispositivo de vialidad',
      icon: Icons.traffic,
      color: Color(0xFF2563EB),
      presets: [
        _FenixPreset(
          label: 'Zona centro',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 51,
          motivo: 'Dispositivo de vialidad en zona centro',
          lugar: 'Zona Centro',
        ),
        _FenixPreset(
          label: 'Escuela',
          categoriaId: _FenixPreset.operativos,
          subcategoriaId: 86,
          motivo: 'Escuela segura',
        ),
        _FenixPreset(
          label: 'Crucero conflictivo',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 49,
          motivo: 'Apoyo a la vialidad en crucero conflictivo',
        ),
        _FenixPreset(
          label: 'Obra vial',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 53,
          motivo: 'Medidas de protección por obra vial',
        ),
        _FenixPreset(
          label: 'Paso peatonal',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 52,
          motivo: 'Apoyo en paso peatonal',
        ),
        _FenixPreset(
          label: 'SSP',
          categoriaId: _FenixPreset.operativos,
          subcategoriaId: 87,
          motivo: 'Conexión institucional',
          lugar: 'SSP',
        ),
        _FenixPreset(
          label: 'Otro',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 56,
          motivo: 'Otro dispositivo de seguridad vial',
        ),
      ],
    ),
    _FenixSection(
      title: 'Abanderamiento',
      icon: Icons.flag_outlined,
      color: Color(0xFFB45309),
      presets: [
        _FenixPreset(
          label: 'Obra pública',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 20,
          motivo: 'Abanderamiento por obra pública',
        ),
        _FenixPreset(
          label: 'Teleférico',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 20,
          motivo: 'Abanderamiento por trabajos de teleférico',
        ),
        _FenixPreset(
          label: 'Maquinaria pesada',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 20,
          motivo: 'Abanderamiento por maquinaria pesada',
        ),
        _FenixPreset(
          label: 'Cierre parcial',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 16,
          motivo: 'Abanderamiento por cierre parcial',
        ),
        _FenixPreset(
          label: 'Cierre total',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 16,
          motivo: 'Abanderamiento por cierre total',
        ),
        _FenixPreset(
          label: 'Evento especial',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 22,
          motivo: 'Abanderamiento por evento especial',
        ),
      ],
    ),
    _FenixSection(
      title: 'Monitoreo preventivo',
      icon: Icons.visibility_outlined,
      color: Color(0xFF15803D),
      presets: [
        _FenixPreset(
          label: 'Bancos',
          categoriaId: _FenixPreset.monitoreos,
          subcategoriaId: 39,
          motivo: 'Monitoreo preventivo en bancos',
        ),
        _FenixPreset(
          label: 'Centros comerciales',
          categoriaId: _FenixPreset.monitoreos,
          subcategoriaId: 38,
          motivo: 'Monitoreo preventivo en centros comerciales',
        ),
        _FenixPreset(
          label: 'Plazas públicas',
          categoriaId: _FenixPreset.monitoreos,
          subcategoriaId: 43,
          motivo: 'Monitoreo preventivo en plaza pública',
        ),
        _FenixPreset(
          label: 'Oficinas públicas',
          categoriaId: _FenixPreset.monitoreos,
          subcategoriaId: 41,
          motivo: 'Monitoreo preventivo en oficinas públicas',
        ),
        _FenixPreset(
          label: 'Manifestación',
          categoriaId: _FenixPreset.monitoreos,
          subcategoriaId: 42,
          motivo: 'Monitoreo preventivo por manifestación',
        ),
        _FenixPreset(
          label: 'Concentración',
          categoriaId: _FenixPreset.monitoreos,
          subcategoriaId: 42,
          motivo: 'Monitoreo preventivo por concentración de personas',
        ),
      ],
    ),
    _FenixSection(
      title: 'Proximidad social',
      icon: Icons.volunteer_activism_outlined,
      color: Color(0xFF0F766E),
      presets: [
        _FenixPreset(
          label: 'Prevención',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 68,
          motivo: 'Prevención social',
        ),
        _FenixPreset(
          label: 'Recorrido',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 69,
          motivo: 'Recorrido de proximidad social',
        ),
        _FenixPreset(
          label: 'Turistas',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 70,
          motivo: 'Apoyo a turistas',
        ),
        _FenixPreset(
          label: 'Adulto mayor',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 71,
          motivo: 'Apoyo a persona de la tercera edad',
        ),
        _FenixPreset(
          label: 'Persona perdida',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 72,
          motivo: 'Apoyo a persona perdida',
        ),
        _FenixPreset(
          label: 'Espacio público',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 73,
          motivo: 'Recuperación de espacios públicos',
        ),
        _FenixPreset(
          label: 'Persona en riesgo',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 68,
          motivo: 'Apoyo por persona en riesgo',
        ),
        _FenixPreset(
          label: 'Otra proximidad',
          categoriaId: _FenixPreset.proximidad,
          subcategoriaId: 74,
          motivo: 'Otra actividad de proximidad social',
        ),
      ],
    ),
    _FenixSection(
      title: 'Protección / evento oficial',
      icon: Icons.account_balance_outlined,
      color: Color(0xFF7C3AED),
      presets: [
        _FenixPreset(
          label: 'Gobernador',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 50,
          motivo: 'Paso libre de funcionarios',
        ),
        _FenixPreset(
          label: 'Secretario',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 50,
          motivo: 'Paso libre de funcionarios',
        ),
        _FenixPreset(
          label: 'Gira de trabajo',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 55,
          motivo: 'Servicio de escolta por gira de trabajo',
        ),
        _FenixPreset(
          label: 'Evento institucional',
          categoriaId: _FenixPreset.instituciones,
          subcategoriaId: 1,
          motivo: 'Apoyo a evento institucional',
        ),
        _FenixPreset(
          label: 'Dispositivo especial',
          categoriaId: _FenixPreset.operativos,
          subcategoriaId: 87,
          motivo: 'Dispositivo especial de conexión institucional',
        ),
      ],
    ),
    _FenixSection(
      title: 'Reportar novedad rápida',
      icon: Icons.report_problem_outlined,
      color: Color(0xFFDC2626),
      presets: [
        _FenixPreset(
          label: 'Choque',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 17,
          motivo: 'Novedad por choque',
        ),
        _FenixPreset(
          label: 'Atropellamiento',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 17,
          motivo: 'Novedad por atropellamiento',
        ),
        _FenixPreset(
          label: 'Vehículo averiado',
          categoriaId: _FenixPreset.auxilioVial,
          subcategoriaId: 44,
          motivo: 'Auxilio por vehículo averiado',
        ),
        _FenixPreset(
          label: 'Bloqueo',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 16,
          motivo: 'Novedad por bloqueo vial',
        ),
        _FenixPreset(
          label: 'Semáforo dañado',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 49,
          motivo: 'Apoyo a la vialidad por semáforo dañado',
        ),
        _FenixPreset(
          label: 'Obra peligrosa',
          categoriaId: _FenixPreset.abanderamientos,
          subcategoriaId: 20,
          motivo: 'Novedad por obra peligrosa',
        ),
        _FenixPreset(
          label: 'Otro',
          categoriaId: _FenixPreset.dispositivos,
          subcategoriaId: 56,
          motivo: 'Otra novedad vial',
        ),
      ],
    ),
  ];
}
