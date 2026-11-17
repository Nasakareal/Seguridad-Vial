import 'package:flutter/material.dart';

import '../../../services/archivo_siniestros_service.dart';
import 'archivo_areas_screen.dart';
import 'archivo_anaqueles_screen.dart';
import 'archivo_bloques_screen.dart';
import 'archivo_mapa_screen.dart';
import 'archivo_libros_screen.dart';
import 'archivo_escaner_qr_screen.dart';
import 'archivo_libro_detalle_screen.dart';
import 'widgets/archivo_ui.dart';

class ArchivoHomeScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  const ArchivoHomeScreen({super.key, required this.service});

  @override
  State<ArchivoHomeScreen> createState() => _ArchivoHomeScreenState();
}

class _ArchivoHomeScreenState extends State<ArchivoHomeScreen> {
  int? _areas;
  int? _anaqueles;
  int? _bloques;
  int? _libros;
  Object? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final areas = await widget.service.getAreas(perPage: 1);
      final anaqueles = await widget.service.getAnaqueles(perPage: 1);
      final bloques = await widget.service.getBloques(perPage: 1);
      final libros = await widget.service.getLibros(perPage: 1);
      if (!mounted) return;
      setState(() {
        _areas = areas.total;
        _anaqueles = anaqueles.total;
        _bloques = bloques.total;
        _libros = libros.total;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
      .then((_) { if (mounted) _load(); });

  Future<void> _scan() async {
    final result = await Navigator.push<ArchivoQrResult>(
      context,
      MaterialPageRoute(builder: (_) => const ArchivoEscanerQrScreen()),
    );
    if (result == null || !mounted) return;
    try {
      if (result.tipo == 'libro') {
        final libro = await widget.service.libroPorQr(result.uuid);
        if (!mounted) return;
        _go(ArchivoLibroDetalleScreen(service: widget.service, libroId: libro.id));
      } else {
        final bloque = await widget.service.bloquePorQr(result.uuid);
        if (!mounted) return;
        await showDialog<void>(context: context, builder: (_) => AlertDialog(
          title: Text('Bloque ${bloque.codigo}'),
          content: Text('Anaquel: ${bloque.anaquelCodigo}\nOcupados: ${bloque.ocupados}\nReservados: ${bloque.reservados}\nDisponibles: ${bloque.disponibles}'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
        ));
      }
    } catch (error) {
      if (mounted) archivoToast(context, error.toString(), error: true);
    }
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Archivo de Siniestros',
    subtitle: 'Control físico y digital del archivo',
    actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh))],
    child: RefreshIndicator(onRefresh: _load, child: ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) ArchivoError(error: _error!, retry: _load),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: ArchivoKpi(icon: Icons.menu_book_outlined, label: 'Libros registrados', value: '${_libros ?? '—'}')),
          const SizedBox(width: 10),
          Expanded(child: ArchivoKpi(icon: Icons.warehouse_outlined, label: 'Anaqueles', value: '${_anaqueles ?? '—'}', color: Colors.indigo)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: ArchivoKpi(icon: Icons.grid_view, label: 'Bloques', value: '${_bloques ?? '—'}', color: Colors.orange)),
          const SizedBox(width: 10),
          Expanded(child: ArchivoKpi(icon: Icons.meeting_room_outlined, label: 'Áreas', value: '${_areas ?? '—'}', color: Colors.blue)),
        ]),
        const SizedBox(height: 16),
        _tile(Icons.search, 'Buscar libros', 'Consulta por folio, año, código o título',
            () => _go(ArchivoLibrosScreen(service: widget.service))),
        _tile(Icons.map_outlined, 'Mapa interactivo', 'Anaqueles, bloques y ubicación física',
            () => _go(ArchivoMapaScreen(service: widget.service))),
        _tile(Icons.qr_code_scanner, 'Escanear QR', 'Identificar libros y bloques', _scan),
        const SizedBox(height: 9),
        const Padding(padding: EdgeInsets.only(left: 5, bottom: 8),
          child: Text('ADMINISTRACIÓN', style: TextStyle(color: archivoMuted, fontWeight: FontWeight.w800, letterSpacing: 1))),
        _tile(Icons.meeting_room_outlined, 'Áreas', 'Sala histórica y mesa de liberaciones',
            () => _go(ArchivoAreasScreen(service: widget.service))),
        _tile(Icons.warehouse_outlined, 'Anaqueles', 'Cuadrículas y dimensiones',
            () => _go(ArchivoAnaquelesScreen(service: widget.service))),
        _tile(Icons.grid_on, 'Bloques', 'Capacidad y ocupación de pilas',
            () => _go(ArchivoBloquesScreen(service: widget.service))),
      ],
    )),
  );

  Widget _tile(IconData icon, String title, String subtitle, VoidCallback tap) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(backgroundColor: archivoTeal.withValues(alpha: .10), foregroundColor: archivoTeal, child: Icon(icon)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: tap,
    ),
  );
}
