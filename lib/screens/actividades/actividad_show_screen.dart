import 'package:flutter/material.dart';

import '../../models/actividad.dart';
import '../../services/actividad_share_service.dart';
import '../../services/actividades_service.dart';
import '../../widgets/safe_network_image.dart';
import 'widgets/actividad_vehiculo_modal.dart';

class ActividadShowScreen extends StatefulWidget {
  const ActividadShowScreen({super.key});

  @override
  State<ActividadShowScreen> createState() => _ActividadShowScreenState();
}

class _ActividadShowScreenState extends State<ActividadShowScreen>
    with WidgetsBindingObserver {
  bool _loading = true;
  bool _sharing = false;
  String? _error;
  Actividad? _actividad;
  bool _bootstrapped = false;

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final v = args['actividad_id'] ?? args['id'];
      if (v is int) return v;
      return int.tryParse(v?.toString() ?? '');
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_bootstrapped) return;
    _bootstrapped = true;
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      await ActividadShareService.onAppResumed();
    }
  }

  Future<void> _load() async {
    final id = _idFromArgs();
    if (id == null) {
      setState(() {
        _loading = false;
        _error = 'Falta actividad_id';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final a = await ActividadesService.fetchShow(id);
      if (!mounted) return;
      setState(() {
        _actividad = a;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudo cargar.\n$e';
        _loading = false;
      });
    }
  }

  Future<void> _shareWhatsapp() async {
    final a = _actividad;
    if (a == null || _sharing) return;

    setState(() => _sharing = true);
    try {
      await ActividadShareService.compartirEnWhatsapp(actividadId: a.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo compartir.\n$e')));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  String _displayDate(String? value) =>
      (value ?? '').trim().isEmpty ? '—' : value!.trim();

  String _displayText(String? value) {
    final text = (value ?? '').trim();
    return text.isEmpty ? '—' : text;
  }

  Widget _photoCarousel(Actividad a) {
    final photos = a.allPhotoPaths;
    if (photos.isEmpty) {
      return const Text('Sin foto.');
    }

    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final url = ActividadesService.toPublicUrl(photos[index]);
          return ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: SafeNetworkImage(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 260,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Text('No se pudo cargar la imagen.'),
                  ),
                ),
                loadingBuilder: (context, progress) {
                  return Container(
                    width: 260,
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionText(String title, String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: Colors.blue.shade900,
            ),
          ),
          const SizedBox(height: 6),
          Text(text),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = _actividad;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Detalle de actividad'),
        actions: [
          IconButton(
            tooltip: 'Compartir por WhatsApp',
            onPressed: _sharing ? null : _shareWhatsapp,
            icon: _sharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.share),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(child: Text(_error!)),
                )
              else if (a == null)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: Text('Sin datos.')),
                )
              else ...[
                _card(
                  title: 'Resumen',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('ID', '#${a.id}'),
                      _kv('Categoria', a.categoria?.nombre ?? '—'),
                      _kv('Subcategoria', a.subcategoria?.nombre ?? '—'),
                      _kv('Capturo', a.nombre),
                      _kv('Fecha', _displayDate(a.fecha)),
                      _kv('Hora', _displayDate(a.hora)),
                      _kv('Unidad', a.unidad?.nombre ?? '—'),
                      _kv('Delegacion', a.delegacion?.nombre ?? '—'),
                      _kv('Destacamento', a.destacamento?.nombre ?? '—'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Ubicacion',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv('Lugar', _displayText(a.lugar)),
                      _kv('Municipio', _displayText(a.municipio)),
                      _kv('Carretera', _displayText(a.carretera)),
                      _kv('Tramo', _displayText(a.tramo)),
                      _kv('Kilometro', _displayText(a.kilometro)),
                      _kv('Latitud', a.lat?.toString() ?? '—'),
                      _kv('Longitud', a.lng?.toString() ?? '—'),
                      _kv('Coordenadas', _displayText(a.coordenadasTexto)),
                      _kv('Fuente ubicacion', _displayText(a.fuenteUbicacion)),
                      _kv('Nota geo', _displayText(a.notaGeo)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Contenido',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _sectionText('Asunto', a.motivo),
                      _sectionText('Narrativa', a.narrativa),
                      _sectionText('Acciones realizadas', a.accionesRealizadas),
                      _sectionText('Observaciones', a.observaciones),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Totales',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _kv(
                        'Personas alcanzadas',
                        a.personasAlcanzadas.toString(),
                      ),
                      _kv(
                        'Personas participantes',
                        a.personasParticipantes.toString(),
                      ),
                      _kv('Personas detenidas', a.personasDetenidas.toString()),
                      _sectionText(
                        'Elementos participantes',
                        a.elementosParticipantesTexto,
                      ),
                      _sectionText(
                        'Patrullas participantes',
                        a.patrullasParticipantesTexto,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _card(
                  title: 'Vehiculos relacionados',
                  child: a.vehiculos.isEmpty
                      ? const Text('No hay vehiculos vinculados.')
                      : Column(
                          children: a.vehiculos
                              .map(
                                (vehiculo) =>
                                    ActividadVehiculoCard(vehiculo: vehiculo),
                              )
                              .toList(),
                        ),
                ),
                const SizedBox(height: 12),
                _card(title: 'Fotos', child: _photoCarousel(a)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 8),
            color: Colors.black.withValues(alpha: .06),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$k:',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}
