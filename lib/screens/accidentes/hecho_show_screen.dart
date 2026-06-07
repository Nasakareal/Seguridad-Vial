import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';
import '../../services/hecho_access_service.dart';
import '../../services/hecho_share_service.dart';
import '../../services/pdf_document_service.dart';
import '../../services/reportes_service.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import '../../app/routes.dart';

import 'hecho_show/hecho_show_helpers.dart';
import 'widgets/hecho_card.dart';

class HechoShowScreen extends StatefulWidget {
  const HechoShowScreen({super.key});

  @override
  State<HechoShowScreen> createState() => _HechoShowScreenState();
}

class _HechoShowScreenState extends State<HechoShowScreen>
    with WidgetsBindingObserver {
  Map<String, dynamic>? _hecho;
  bool _cargando = true;
  String? _error;

  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;
  bool _initialized = false;
  int _hechoId = 0;
  bool _sharingWhatsapp = false;
  bool _downloadingReporte = false;
  final Set<String> _busyPdfActions = <String>{};
  HechoEditAccess _editAccess = HechoEditAccess.none;

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await TrackingService.isRunning();
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _hechoId = HechoShowHelpers.hechoIdFromArgs(context);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      try {
        await AppVersionService.enforceUpdateIfNeeded(context);
        if (!mounted) return;
      } catch (_) {}

      await _bootstrapTrackingStatusOnly();
      if (!mounted) return;

      await _loadEditAccess(refresh: true);
      if (!mounted) return;

      if (_hechoId > 0) {
        await _cargarHecho(_hechoId);
      } else if (mounted) {
        setState(() => _cargando = false);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await TrackingService.isRunning();
      await _loadEditAccess(refresh: true);
      if (!mounted) return;
      setState(() => _trackingOn = running);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _cargarHecho(int id) async {
    if (!mounted) return;
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final token = await AuthService.getToken();
      final headers = <String, String>{'Accept': 'application/json'};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final uri = Uri.parse('${AuthService.baseUrl}/hechos/$id');
      final res = await http.get(uri, headers: headers);

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode}: ${res.body}');
      }

      final raw = jsonDecode(res.body);
      Map<String, dynamic> hecho;

      if (raw is Map<String, dynamic> && raw['data'] is Map) {
        hecho = Map<String, dynamic>.from(raw['data']);
      } else if (raw is Map<String, dynamic> && raw['hecho'] is Map) {
        hecho = Map<String, dynamic>.from(raw['hecho']);
      } else if (raw is Map<String, dynamic>) {
        hecho = raw;
      } else {
        hecho = {};
      }

      if (!mounted) return;
      setState(() {
        _hecho = hecho;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hecho = null;
        _error = 'No se pudo cargar el hecho: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _loadEditAccess({bool refresh = false}) async {
    final editAccess = await HechoAccessService.loadEditAccess(
      refresh: refresh,
    );

    if (!mounted) return;
    setState(() => _editAccess = editAccess);
  }

  bool _puedeEditarHecho(Map<String, dynamic> hecho) =>
      _editAccess.canEditHecho(hecho);

  Future<void> _goEdit(int hechoId) async {
    if (hechoId <= 0) return;
    if (_hecho != null && !_puedeEditarHecho(_hecho!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para editar este hecho.'),
        ),
      );
      return;
    }

    await Navigator.pushNamed(
      context,
      AppRoutes.accidentesEdit,
      arguments: hechoId,
    );

    if (!mounted) return;
    await _bootstrapTrackingStatusOnly();
    await _cargarHecho(hechoId);
  }

  Future<void> _compartirWhatsapp(int hechoId) async {
    if (_sharingWhatsapp || hechoId <= 0) return;

    setState(() => _sharingWhatsapp = true);

    try {
      await HechoShareService.compartirEnWhatsapp(hechoId: hechoId);
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo compartir el hecho.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _sharingWhatsapp = false);
    }
  }

  Future<void> _descargarReporte(int hechoId) async {
    if (_downloadingReporte || hechoId <= 0) return;

    setState(() => _downloadingReporte = true);

    try {
      await ReporteHechoService.descargarYCompartirHecho(hechoId: hechoId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe guardado y listo para compartir'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo descargar el reporte.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) setState(() => _downloadingReporte = false);
    }
  }

  bool _isPdfActionBusy(_PdfDocument doc, String action) {
    return _busyPdfActions.contains('$action:${doc.key}');
  }

  Future<void> _runPdfAction({
    required _PdfDocument doc,
    required String action,
    required Future<void> Function() task,
  }) async {
    final key = '$action:${doc.key}';
    if (_busyPdfActions.contains(key)) return;

    setState(() => _busyPdfActions.add(key));

    try {
      await task();
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo procesar el PDF.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busyPdfActions.remove(key));
      }
    }
  }

  Future<void> _verPdf(_PdfDocument doc) {
    return _runPdfAction(
      doc: doc,
      action: 'open',
      task: () =>
          PdfDocumentService.openFromUrl(url: doc.url, fileName: doc.fileName),
    );
  }

  Future<void> _descargarYCompartirPdf(_PdfDocument doc) {
    return _runPdfAction(
      doc: doc,
      action: 'share',
      task: () async {
        await PdfDocumentService.saveAndShareFromUrl(
          url: doc.url,
          fileName: doc.fileName,
          shareText: doc.shareText,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF guardado y listo para compartir')),
        );
      },
    );
  }

  List<_PdfDocument> _pdfDocumentsFromHecho(
    Map<String, dynamic> h,
    int hechoId,
  ) {
    final documents = <_PdfDocument>[];
    final seen = <String>{};

    void addDocument(_PdfDocument doc) {
      final cleanUrl = doc.url.trim();
      if (cleanUrl.isEmpty || !seen.add('${doc.key}|$cleanUrl')) return;
      documents.add(doc);
    }

    final dictamenId = _toInt(h['dictamen_id']);
    final dictamenArchivo = _cleanText(h['dictamen_archivo']);
    final dictamenArchivoUrl = _cleanText(h['dictamen_archivo_url']);
    final dictamenUrl = dictamenArchivo.isEmpty
        ? ''
        : (dictamenId > 0
              ? '${AuthService.baseUrl}/dictamenes/$dictamenId/archivo'
              : _absoluteDocumentUrl(
                  dictamenArchivoUrl.isNotEmpty
                      ? dictamenArchivoUrl
                      : dictamenArchivo,
                ));
    if (dictamenUrl.isNotEmpty) {
      addDocument(
        _PdfDocument(
          key: 'dictamen:${dictamenId > 0 ? dictamenId : hechoId}',
          title: 'Informe técnico',
          subtitle: dictamenId > 0
              ? 'Dictamen #$dictamenId'
              : 'Dictamen vinculado',
          url: _absoluteDocumentUrl(dictamenUrl),
          fileName: 'informe_tecnico_hecho_$hechoId.pdf',
          shareText: 'Informe técnico del hecho #$hechoId',
        ),
      );
    }

    for (final puesta in _puestasFromHecho(h)) {
      final id = _toInt(puesta['id'] ?? puesta['puesta_disposicion_id']);
      final url = _puestaPdfUrl(puesta);
      if (url.isEmpty) continue;

      final numero = _cleanText(puesta['numero_puesta']);
      final anio = _cleanText(puesta['anio']);
      final folio = [
        if (numero.isNotEmpty) numero,
        if (anio.isNotEmpty) anio,
      ].join('/');

      addDocument(
        _PdfDocument(
          key: 'puesta:${id > 0 ? id : documents.length}',
          title: 'Puesta a disposición',
          subtitle: folio.isNotEmpty ? 'Puesta $folio' : 'PDF vinculado',
          url: url,
          fileName: id > 0
              ? 'puesta_disposicion_$id.pdf'
              : 'puesta_disposicion_hecho_$hechoId.pdf',
          shareText: folio.isNotEmpty
              ? 'Puesta a disposición $folio del hecho #$hechoId'
              : 'Puesta a disposición del hecho #$hechoId',
        ),
      );
    }

    return documents;
  }

  List<Map<String, dynamic>> _puestasFromHecho(Map<String, dynamic> h) {
    final out = <Map<String, dynamic>>[];

    void addMap(dynamic value) {
      if (value is Map) out.add(Map<String, dynamic>.from(value));
    }

    void addList(dynamic value) {
      if (value is! List) return;
      for (final item in value) {
        addMap(item);
      }
    }

    addList(h['puestas_disposicion']);
    addList(h['puestas']);
    addMap(h['puesta_disposicion']);
    addMap(h['puestaDisposicion']);

    if (out.isEmpty) {
      final id = _toInt(h['puesta_disposicion_id']);
      final archivo = _cleanText(
        h['archivo_puesta'] ?? h['archivo_puesta_url'],
      );
      if (id > 0 || archivo.isNotEmpty) {
        out.add(<String, dynamic>{'id': id, 'archivo_puesta': archivo});
      }
    }

    final seen = <int>{};
    return out.where((puesta) {
      final id = _toInt(puesta['id'] ?? puesta['puesta_disposicion_id']);
      if (id <= 0) return true;
      return seen.add(id);
    }).toList();
  }

  String _puestaPdfUrl(Map<String, dynamic> puesta) {
    final id = _toInt(puesta['id'] ?? puesta['puesta_disposicion_id']);
    final direct = _cleanText(
      puesta['archivo_puesta_url'] ??
          puesta['archivo_url'] ??
          puesta['pdf_url'] ??
          puesta['url'],
    );
    final archivo = _cleanText(puesta['archivo_puesta'] ?? puesta['archivo']);
    if (id > 0 && (archivo.isNotEmpty || direct.isNotEmpty)) {
      return '${AuthService.baseUrl}/puestas-disposicion/$id/archivo';
    }

    if (direct.isNotEmpty) return _absoluteDocumentUrl(direct);
    return archivo.isEmpty ? '' : _absoluteDocumentUrl(archivo);
  }

  String _absoluteDocumentUrl(String raw) {
    final clean = raw.trim();
    if (clean.isEmpty) return '';

    final lower = clean.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      return clean;
    }

    if (clean.startsWith('/api/')) {
      final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      return '$root$clean';
    }

    if (clean.startsWith('api/')) {
      final root = AuthService.baseUrl.replaceFirst(RegExp(r'/api/?$'), '');
      return '$root/$clean';
    }

    return HechoShowHelpers.toPublicUrl(clean);
  }

  String _cleanText(dynamic value) {
    final text = (value ?? '').toString().trim();
    if (text == '—' || text == '-') return '';
    return text;
  }

  int _toInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? 0;
  }

  Widget _pdfDocumentsCard(List<_PdfDocument> documents) {
    if (documents.isEmpty) return const SizedBox.shrink();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined),
                SizedBox(width: 8),
                Text(
                  'Documentos PDF',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < documents.length; i++) ...[
              _pdfDocumentRow(documents[i]),
              if (i < documents.length - 1)
                Divider(height: 18, color: Colors.grey.shade200),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pdfDocumentRow(_PdfDocument doc) {
    final opening = _isPdfActionBusy(doc, 'open');
    final sharing = _isPdfActionBusy(doc, 'share');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(doc.title, style: const TextStyle(fontWeight: FontWeight.w900)),
        if (doc.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(doc.subtitle, style: TextStyle(color: Colors.grey.shade700)),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: opening || sharing ? null : () => _verPdf(doc),
              icon: opening
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.visibility_outlined),
              label: const Text('Ver PDF'),
            ),
            ElevatedButton.icon(
              onPressed: opening || sharing
                  ? null
                  : () => _descargarYCompartirPdf(doc),
              icon: sharing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              label: const Text('Descargar y compartir'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _section({
    required String title,
    required IconData icon,
    required List<_KV> items,
    bool initiallyExpanded = true,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((e) => _KVCard(label: e.k, value: e.v, full: e.full))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(int hechoId) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/accidentes/vehiculos',
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.directions_car),
                    label: const Text('Vehículos'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.lesionados,
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.personal_injury),
                    label: const Text('Lesionados'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        AppRoutes.accidentesCroquis,
                        arguments: {'hechoId': hechoId},
                      );
                    },
                    icon: const Icon(Icons.draw),
                    label: const Text('Croquis'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _downloadingReporte
                        ? null
                        : () => _descargarReporte(hechoId),
                    icon: _downloadingReporte
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file),
                    label: const Text('Descargo'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoId;

    final h = _hecho ?? {};
    final puedeEditar = _hecho != null && _puedeEditarHecho(_hecho!);

    final folio = HechoShowHelpers.safeText(h['folio_c5i']);
    final fecha = HechoShowHelpers.safeText(h['fecha']);
    final hora = HechoShowHelpers.safeText(h['hora']);

    final situacion = (() {
      final s = (h['situacion'] ?? '').toString().trim();
      return s.isEmpty ? '—' : HechoShowHelpers.normalizeSituacion(s);
    })();

    final perito = HechoShowHelpers.safeText(h['perito']);

    final ubicacion = (() {
      final muni = HechoShowHelpers.safeText(h['municipio']);
      final calle = HechoShowHelpers.safeText(h['calle']);
      if (muni == '—' && calle == '—') return '—';
      if (muni == '—') return calle;
      if (calle == '—') return muni;
      return '$muni · $calle';
    })();

    final fotoHecho = HechoShowHelpers.fotoLugarUrl(_hecho);
    final fotoSituacion = HechoShowHelpers.fotoSituacionUrl(_hecho);
    final fotosVehiculos = HechoShowHelpers.fotosVehiculosFromHecho(_hecho);

    final fotoConvenio = (() {
      final raw =
          (h['foto_convenio_url'] ??
                  h['convenio_url'] ??
                  h['descargo_url'] ??
                  h['foto_convenio'] ??
                  h['convenio'] ??
                  h['descargo'] ??
                  '')
              .toString()
              .trim();
      return raw.isEmpty ? '' : HechoShowHelpers.toPublicUrl(raw);
    })();

    final pdfDocuments = _pdfDocumentsFromHecho(h, hechoId);

    final identificacion = <_KV>[
      _KV('ID', HechoShowHelpers.safeText(h['id'])),
      _KV('Folio C5i', folio),
      _KV('Perito', perito),
      _KV('Unidad', HechoShowHelpers.safeText(h['unidad'])),
      _KV('Situación', situacion),
      _KV(
        'Tipo de hecho',
        HechoShowHelpers.safeText(h['tipo_hecho']),
        full: true,
      ),
    ];

    final tiempoLugar = <_KV>[
      _KV('Fecha', fecha),
      _KV('Hora', hora),
      _KV(
        'Sector',
        (() {
          final s = (h['sector'] ?? '').toString().trim();
          return s.isEmpty ? '—' : HechoShowHelpers.normalizeSector(s);
        })(),
      ),
      _KV('Municipio', HechoShowHelpers.safeText(h['municipio'])),
      _KV('Calle', HechoShowHelpers.safeText(h['calle']), full: true),
      _KV('Colonia', HechoShowHelpers.safeText(h['colonia']), full: true),
      _KV(
        'Entre calles',
        HechoShowHelpers.safeText(h['entre_calles']),
        full: true,
      ),
    ];

    final clasificacion = <_KV>[
      _KV('Superficie de vía', HechoShowHelpers.safeText(h['superficie_via'])),
      _KV('Tiempo', HechoShowHelpers.safeText(h['tiempo'])),
      _KV('Clima', HechoShowHelpers.safeText(h['clima'])),
      _KV('Condiciones', HechoShowHelpers.safeText(h['condiciones'])),
      _KV(
        'Control de tránsito',
        HechoShowHelpers.safeText(h['control_transito']),
        full: true,
      ),
      _KV(
        'Checaron antecedentes',
        HechoShowHelpers.safeBool01(h['checaron_antecedentes']),
      ),
      _KV('Causas', HechoShowHelpers.safeText(h['causas']), full: true),
      _KV(
        'Responsable',
        HechoShowHelpers.safeText(h['responsable']),
        full: true,
      ),
      _KV(
        'Colisión/camino',
        HechoShowHelpers.safeText(h['colision_camino']),
        full: true,
      ),
    ];

    final danos = <_KV>[
      _KV(
        'Daños patrimoniales',
        HechoShowHelpers.safeBool01(h['danos_patrimoniales']),
      ),
      _KV(
        'Propiedades afectadas',
        HechoShowHelpers.safeText(h['propiedades_afectadas']),
        full: true,
      ),
      _KV(
        'Monto daños',
        HechoShowHelpers.safeText(h['monto_danos_patrimoniales']),
      ),
    ];

    final mp = <_KV>[
      _KV('Oficio MP', HechoShowHelpers.safeText(h['oficio_mp']), full: true),
      _KV('Vehículos MP', HechoShowHelpers.safeText(h['vehiculos_mp'])),
      _KV('Personas MP', HechoShowHelpers.safeText(h['personas_mp'])),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: Text('Hecho #$hechoId'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/home');
            }
          },
        ),
        actions: [
          if (puedeEditar)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit),
              onPressed: () => _goEdit(hechoId),
            ),
          IconButton(
            tooltip: 'Buscar',
            icon: const Icon(Icons.search),
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.hechosBuscar),
          ),
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _bootstrapTrackingStatusOnly();
              if (hechoId > 0) await _cargarHecho(hechoId);
            },
          ),
          const AccountMenuAction(),
        ],
      ),
      drawer: AppDrawer(trackingOn: _trackingOn),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            if (hechoId > 0) await _cargarHecho(hechoId);
          },
          child: _cargando
              ? ListView(
                  children: const [
                    SizedBox(height: 140),
                    Center(child: CircularProgressIndicator()),
                  ],
                )
              : _error != null
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: hechoId > 0
                          ? () => _cargarHecho(hechoId)
                          : null,
                      child: const Text('Reintentar'),
                    ),
                  ],
                )
              : (_hecho == null || _hecho!.isEmpty)
              ? const Center(child: Text('No se pudo cargar el hecho.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  children: [
                    if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
                    if (_trackingOn) const SizedBox(height: 12),

                    HechoCard(
                      hecho: _hecho!,
                      folio: folio,
                      fecha: fecha,
                      hora: hora,
                      situacion: situacion,
                      perito: perito,
                      ubicacion: ubicacion,
                      fotoHecho: fotoHecho,
                      fotoSituacion: fotoSituacion,
                      fotosVehiculos: fotosVehiculos,
                      fotoConvenio: fotoConvenio,
                      isDownloading: false,
                      isSending: _sharingWhatsapp,
                      onTapShow: () {},
                      onTapEdit: puedeEditar ? () => _goEdit(hechoId) : null,
                      onDownload: null,
                      onEnviarWhatsapp: hechoId > 0
                          ? () => _compartirWhatsapp(hechoId)
                          : null,
                    ),

                    if (pdfDocuments.isNotEmpty) ...[
                      _pdfDocumentsCard(pdfDocuments),
                      const SizedBox(height: 12),
                    ],

                    if (puedeEditar) ...[
                      _quickActions(hechoId),
                      const SizedBox(height: 12),
                    ],

                    _section(
                      title: 'Identificación',
                      icon: Icons.badge,
                      items: identificacion,
                      initiallyExpanded: true,
                    ),
                    _section(
                      title: 'Tiempo y lugar',
                      icon: Icons.place,
                      items: tiempoLugar,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Clasificación',
                      icon: Icons.category,
                      items: clasificacion,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Daños',
                      icon: Icons.warning_amber,
                      items: danos,
                      initiallyExpanded: false,
                    ),
                    _section(
                      title: 'Ministerio Público',
                      icon: Icons.gavel,
                      items: mp,
                      initiallyExpanded: false,
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
        ),
      ),
    );
  }
}

class _PdfDocument {
  final String key;
  final String title;
  final String subtitle;
  final String url;
  final String fileName;
  final String shareText;

  const _PdfDocument({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.url,
    required this.fileName,
    required this.shareText,
  });
}

class _KV {
  final String k;
  final String v;
  final bool full;
  const _KV(this.k, this.v, {this.full = false});
}

class _KVCard extends StatelessWidget {
  final String label;
  final String value;
  final bool full;

  const _KVCard({required this.label, required this.value, this.full = false});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final double target = full ? (w - 32) : ((w - 32 - 10) / 2);

    return SizedBox(
      width: target,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: value == '—' ? Colors.grey.shade700 : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
