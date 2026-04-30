import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../models/constancia_manejo.dart';
import '../../services/auth_service.dart';
import '../../services/constancias_manejo_service.dart';
import '../../services/local_draft_service.dart';

class ConstanciaManejoScanScreen extends StatefulWidget {
  const ConstanciaManejoScanScreen({super.key});

  @override
  State<ConstanciaManejoScanScreen> createState() =>
      _ConstanciaManejoScanScreenState();
}

class _ConstanciaManejoScanScreenState
    extends State<ConstanciaManejoScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const <BarcodeFormat>[BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    autoZoom: true,
  );
  final _manualCtrl = TextEditingController();

  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRaw(String raw) async {
    if (_busy) return;

    final token = ConstanciasManejoService.parseQrToken(raw);
    if (token.isEmpty) {
      setState(() => _error = 'El QR no contiene una constancia valida.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      unawaited(_controller.stop());
      final constancia = await ConstanciasManejoService.buscarPorQr(token);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ConstanciaManejoDetailScreen(initialConstancia: constancia),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ConstanciasManejoService.cleanExceptionMessage(e);
      });
      try {
        await _controller.start();
      } catch (_) {}
    }
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_busy) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue?.trim() ?? '';
      if (raw.isEmpty) continue;
      unawaited(_handleRaw(raw));
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Escanear constancia'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Linterna',
            icon: const Icon(Icons.flashlight_on),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            tooltip: 'Cambiar camara',
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _handleDetect,
                    errorBuilder: (context, error) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No se pudo iniciar la camara.\n\n$error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                  Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white, width: 3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  if (_busy)
                    Container(
                      color: Colors.black.withValues(alpha: .45),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _manualCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL o token de constancia',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _busy ? null : _handleRaw,
                  ),
                  if ((_error ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _handleRaw(_manualCtrl.text),
                    icon: const Icon(Icons.search),
                    label: Text(_busy ? 'Buscando...' : 'Abrir constancia'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConstanciaManejoDetailScreen extends StatefulWidget {
  final ConstanciaManejo? initialConstancia;
  final int? constanciaId;
  final String? qrToken;

  const ConstanciaManejoDetailScreen({
    super.key,
    this.initialConstancia,
    this.constanciaId,
    this.qrToken,
  });

  @override
  State<ConstanciaManejoDetailScreen> createState() =>
      _ConstanciaManejoDetailScreenState();
}

class _ConstanciaManejoDetailScreenState
    extends State<ConstanciaManejoDetailScreen> {
  static const _tiposLicencia = <String, String>{
    'SERVICIO_PUBLICO': 'Servicio publico',
    'AUTOMOVILISTA': 'Automovilista',
    'CHOFER': 'Chofer',
    'MOTOCICLISTA': 'Motociclista',
    'PERMISO': 'Permiso',
  };

  final _nombreCtrl = TextEditingController();
  final _curpCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _totalCtrl = TextEditingController(text: '20');
  final _aciertosCtrl = TextEditingController(text: '0');
  final _erroresCtrl = TextEditingController(text: '0');
  final _calificacionCtrl = TextEditingController(text: '0');
  final _observacionesCtrl = TextEditingController();

  ConstanciaManejo? _constancia;
  bool _loadedArgs = false;
  bool _loading = true;
  bool _busy = false;
  bool _canEditModuloExamenes = false;
  String? _error;
  String? _tipoLicencia;
  String? _examMode;
  LocalDraftAutosave? _draft;
  int? _draftForId;
  int? _lastLoadId;
  String? _lastLoadQrToken;

  @override
  void initState() {
    super.initState();
    _totalCtrl.addListener(_syncWrittenScorePreview);
    _aciertosCtrl.addListener(_syncWrittenScorePreview);
    _erroresCtrl.addListener(_syncWrittenScorePreview);
    if (widget.initialConstancia != null) {
      _constancia = widget.initialConstancia;
      _loading = false;
      _syncForm(widget.initialConstancia!);
      _configureDraft(widget.initialConstancia!);
      unawaited(_loadActionAccess());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedArgs) return;
    _loadedArgs = true;

    if (_constancia != null) return;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is ConstanciaManejo) {
      setState(() {
        _constancia = args;
        _loading = false;
      });
      _syncForm(args);
      _configureDraft(args);
      unawaited(_loadActionAccess());
      return;
    }

    int? id = widget.constanciaId;
    String? qrToken = widget.qrToken;
    if (args is Map) {
      final rawId = args['constanciaId'] ?? args['id'];
      id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
      qrToken = (args['qrToken'] ?? args['token'])?.toString();
    }

    unawaited(_load(id: id, qrToken: qrToken));
  }

  @override
  void dispose() {
    _draft?.dispose();
    _totalCtrl.removeListener(_syncWrittenScorePreview);
    _aciertosCtrl.removeListener(_syncWrittenScorePreview);
    _erroresCtrl.removeListener(_syncWrittenScorePreview);
    _nombreCtrl.dispose();
    _curpCtrl.dispose();
    _telefonoCtrl.dispose();
    _totalCtrl.dispose();
    _aciertosCtrl.dispose();
    _erroresCtrl.dispose();
    _calificacionCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _draftValues() {
    return <String, dynamic>{
      'nombre_solicitante': _nombreCtrl.text,
      'curp': _curpCtrl.text,
      'telefono': _telefonoCtrl.text,
      'tipo_licencia': _tipoLicencia,
      'tipo_examen': _examMode,
      'total_preguntas': _totalCtrl.text,
      'aciertos': _aciertosCtrl.text,
      'errores': _erroresCtrl.text,
      'calificacion': _calificacionCtrl.text,
      'observaciones': _observacionesCtrl.text,
    };
  }

  void _configureDraft(ConstanciaManejo constancia) {
    if (_draftForId == constancia.id) return;

    _draft?.dispose();
    _draftForId = constancia.id;
    _draft =
        LocalDraftAutosave(
          draftId: 'constancias_manejo:impreso:${constancia.id}',
          collect: _draftValues,
        )..attachTextControllers({
          'nombre_solicitante': _nombreCtrl,
          'curp': _curpCtrl,
          'telefono': _telefonoCtrl,
          'total_preguntas': _totalCtrl,
          'aciertos': _aciertosCtrl,
          'errores': _erroresCtrl,
          'calificacion': _calificacionCtrl,
          'observaciones': _observacionesCtrl,
        });

    unawaited(_restoreDraft());
  }

  Future<void> _restoreDraft() async {
    final draft = _draft;
    if (draft == null) return;

    final restored = await draft.restore((data) {
      _nombreCtrl.text = (data['nombre_solicitante'] ?? '').toString();
      _curpCtrl.text = (data['curp'] ?? '').toString();
      _telefonoCtrl.text = (data['telefono'] ?? '').toString();
      _totalCtrl.text = (data['total_preguntas'] ?? '20').toString();
      _aciertosCtrl.text = (data['aciertos'] ?? '0').toString();
      _erroresCtrl.text = (data['errores'] ?? '0').toString();
      _calificacionCtrl.text = (data['calificacion'] ?? '0').toString();
      _observacionesCtrl.text = (data['observaciones'] ?? '').toString();
      final tipo = (data['tipo_licencia'] ?? '').toString();
      if (_tiposLicencia.containsKey(tipo)) {
        _tipoLicencia = tipo;
      }
      final mode = (data['tipo_examen'] ?? '').toString();
      if (mode == 'LINEA' || mode == 'IMPRESO') {
        _examMode = mode;
      }
      _syncWrittenScorePreview();
    });

    if (!mounted || !restored) return;
    setState(() {});
  }

  Future<void> _load({int? id, String? qrToken}) async {
    _lastLoadId = id;
    _lastLoadQrToken = qrToken;

    if (id == null && (qrToken ?? '').trim().isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Constancia invalida.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final constancia = id != null
          ? await ConstanciasManejoService.fetch(id)
          : await ConstanciasManejoService.buscarPorQr(qrToken!);
      if (!mounted) return;
      setState(() {
        _constancia = constancia;
        _loading = false;
      });
      _syncForm(constancia);
      _configureDraft(constancia);
      unawaited(_loadActionAccess());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ConstanciasManejoService.cleanExceptionMessage(e);
      });
    }
  }

  Future<void> _loadActionAccess() async {
    try {
      final allowed = await AuthService.canEditConstanciasManejo(refresh: true);
      if (!mounted) return;
      setState(() => _canEditModuloExamenes = allowed);
    } catch (_) {
      if (!mounted) return;
      setState(() => _canEditModuloExamenes = false);
    }
  }

  void _syncForm(ConstanciaManejo constancia) {
    _nombreCtrl.text = constancia.nombreSolicitante ?? '';
    _curpCtrl.text = constancia.curp ?? '';
    _telefonoCtrl.text = constancia.telefono ?? '';
    final tipo = constancia.tipoLicencia ?? '';
    if (_tiposLicencia.containsKey(tipo)) {
      _tipoLicencia = tipo;
    } else {
      _tipoLicencia = null;
    }

    final tipoExamen = (constancia.tipoExamen ?? '').trim().toUpperCase();
    if (tipoExamen == 'LINEA' || tipoExamen == 'IMPRESO') {
      _examMode = tipoExamen;
    } else if (constancia.tieneAccesoTemporal) {
      _examMode = 'LINEA';
    } else if (constancia.examen?.modalidad?.trim().toUpperCase() ==
        'IMPRESO') {
      _examMode = 'IMPRESO';
    }

    final examen = constancia.examen;
    _totalCtrl.text = (examen?.totalPreguntas ?? 20).toString();
    _aciertosCtrl.text = (examen?.aciertos ?? 0).toString();
    _erroresCtrl.text = (examen?.errores ?? 0).toString();
    _calificacionCtrl.text = _fmtNumber(examen?.calificacion ?? 0);
    _observacionesCtrl.text = examen?.observaciones ?? '';
    _syncWrittenScorePreview();
  }

  void _syncWrittenScorePreview() {
    final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
    final aciertos = int.tryParse(_aciertosCtrl.text.trim()) ?? -1;
    if (total <= 0 || aciertos < 0 || aciertos > total) return;

    final next = _fmtNumber(_calculateWrittenScore(total, aciertos));
    if (_calificacionCtrl.text != next) {
      _calificacionCtrl.text = next;
    }
  }

  Future<void> _refresh() async {
    final constancia = _constancia;
    if (constancia != null) {
      await _load(id: constancia.id);
      return;
    }
    await _load(id: _lastLoadId, qrToken: _lastLoadQrToken);
  }

  Future<void> _generateAccess() async {
    final constancia = _constancia;
    if (constancia == null || _busy) return;

    final nombre = _nombreCtrl.text.trim();
    final tipoLicencia = _tipoLicencia;

    if (nombre.isEmpty) {
      _showSnack('Captura el nombre del solicitante.');
      return;
    }
    if (tipoLicencia == null || tipoLicencia.trim().isEmpty) {
      _showSnack('Selecciona el tipo de licencia.');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await ConstanciasManejoService.generarAcceso(
        id: constancia.id,
        nombreSolicitante: nombre,
        curp: _curpCtrl.text,
        telefono: _telefonoCtrl.text,
        tipoLicencia: tipoLicencia,
      );
      if (!mounted) return;
      _syncForm(updated);
      setState(() {
        _constancia = updated;
        _examMode = 'LINEA';
      });
      _showSnack('Acceso temporal generado.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(ConstanciasManejoService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelAccess() async {
    final constancia = _constancia;
    if (constancia == null || _busy) return;

    setState(() => _busy = true);
    try {
      final updated = await ConstanciasManejoService.cancelarAcceso(
        constancia.id,
      );
      if (!mounted) return;
      setState(() => _constancia = updated);
      _showSnack('Acceso temporal cancelado.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(ConstanciasManejoService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveWrittenExam() async {
    final constancia = _constancia;
    if (constancia == null || _busy) return;

    final nombre = _nombreCtrl.text.trim();
    final total = int.tryParse(_totalCtrl.text.trim()) ?? 0;
    final aciertos = int.tryParse(_aciertosCtrl.text.trim()) ?? -1;
    final errores = int.tryParse(_erroresCtrl.text.trim()) ?? -1;

    if (nombre.isEmpty) {
      _showSnack('Captura el nombre del solicitante.');
      return;
    }
    if (total <= 0 || aciertos < 0 || errores < 0) {
      _showSnack('Revisa el total, aciertos y errores.');
      return;
    }
    if (aciertos + errores != total) {
      _showSnack('Aciertos y errores deben sumar el total.');
      return;
    }
    final calificacion = _calculateWrittenScore(total, aciertos);
    _calificacionCtrl.text = _fmtNumber(calificacion);
    final tipoLicencia = _tipoLicencia;
    if (tipoLicencia == null || tipoLicencia.trim().isEmpty) {
      _showSnack('Selecciona el tipo de licencia.');
      return;
    }

    setState(() => _busy = true);
    try {
      final updated = await ConstanciasManejoService.capturarImpreso(
        id: constancia.id,
        nombreSolicitante: nombre,
        curp: _curpCtrl.text,
        telefono: _telefonoCtrl.text,
        tipoLicencia: tipoLicencia,
        totalPreguntas: total,
        aciertos: aciertos,
        errores: errores,
        calificacion: calificacion,
        observaciones: _observacionesCtrl.text,
      );
      await _draft?.discard();
      if (!mounted) return;
      _syncForm(updated);
      setState(() {
        _constancia = updated;
        _examMode = 'IMPRESO';
      });
      _showSnack('Examen impreso capturado.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(ConstanciasManejoService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _activate() async {
    final constancia = _constancia;
    if (constancia == null || _busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Activar constancia'),
          content: Text('Se activara la constancia ${constancia.folio}.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.verified),
              label: const Text('Activar'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final updated = await ConstanciasManejoService.activar(constancia.id);
      if (!mounted) return;
      setState(() => _constancia = updated);
      _showSnack('Constancia activada.');
    } catch (e) {
      if (!mounted) return;
      _showSnack(ConstanciasManejoService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _copyExamUrl(ConstanciaManejo constancia) {
    final url = constancia.urlExamen?.trim() ?? '';
    if (url.isEmpty) return;
    Clipboard.setData(ClipboardData(text: url));
    _showSnack('Liga copiada.');
  }

  @override
  Widget build(BuildContext context) {
    final constancia = _constancia;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Constancia de manejo'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _loading || _busy ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 90),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorPanel(message: _error!, onRetry: _refresh)
              else if (constancia != null) ...[
                _HeaderPanel(constancia: constancia),
                const SizedBox(height: 14),
                _ApplicantDataPanel(
                  constancia: constancia,
                  busy: _busy,
                  canEdit: _canEditModuloExamenes,
                  nombreCtrl: _nombreCtrl,
                  curpCtrl: _curpCtrl,
                  telefonoCtrl: _telefonoCtrl,
                  tipoLicencia: _tipoLicencia,
                  tiposLicencia: _tiposLicencia,
                  onTipoChanged: (value) {
                    setState(() => _tipoLicencia = value);
                    _draft?.notifyChanged();
                  },
                ),
                const SizedBox(height: 14),
                _ExamModePanel(
                  selectedMode: _examMode,
                  enabled:
                      !_busy &&
                      _canEditModuloExamenes &&
                      constancia.estaInactiva,
                  onChanged: (mode) {
                    setState(() => _examMode = mode);
                    _draft?.notifyChanged();
                  },
                ),
                if (_examMode == 'LINEA') ...[
                  const SizedBox(height: 14),
                  _ExamAccessPanel(
                    constancia: constancia,
                    busy: _busy,
                    canEdit: _canEditModuloExamenes,
                    onGenerate: _generateAccess,
                    onCancel: _cancelAccess,
                    onCopy: () => _copyExamUrl(constancia),
                  ),
                ],
                if (_examMode == 'IMPRESO') ...[
                  const SizedBox(height: 14),
                  _WrittenExamPanel(
                    constancia: constancia,
                    busy: _busy,
                    canEdit: _canEditModuloExamenes,
                    totalCtrl: _totalCtrl,
                    aciertosCtrl: _aciertosCtrl,
                    erroresCtrl: _erroresCtrl,
                    calificacionCtrl: _calificacionCtrl,
                    observacionesCtrl: _observacionesCtrl,
                    onSave: _saveWrittenExam,
                  ),
                ],
                const SizedBox(height: 14),
                _ActivationPanel(
                  constancia: constancia,
                  busy: _busy,
                  canEdit: _canEditModuloExamenes,
                  onActivate: _activate,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderPanel extends StatelessWidget {
  final ConstanciaManejo constancia;

  const _HeaderPanel({required this.constancia});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(constancia.estatus);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.qr_code_2, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      constancia.folio,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      constancia.modulo ?? 'Modulo sin nombre',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .76),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: constancia.estatus, color: color),
            ],
          ),
          const SizedBox(height: 14),
          _InfoLine(
            icon: Icons.person,
            label: 'Solicitante',
            value: constancia.nombreSolicitante ?? 'Pendiente',
          ),
          _InfoLine(
            icon: Icons.badge,
            label: 'Licencia',
            value: constancia.tipoLicencia ?? 'Pendiente',
          ),
          _InfoLine(
            icon: Icons.fact_check,
            label: 'Examen',
            value: constancia.resultado ?? 'Sin examen',
          ),
          if ((constancia.fechaExpiracion ?? '').trim().isNotEmpty)
            _InfoLine(
              icon: Icons.event_available,
              label: 'Vigencia',
              value: _fmtDateTime(constancia.fechaExpiracion),
            ),
        ],
      ),
    );
  }
}

class _ApplicantDataPanel extends StatelessWidget {
  final ConstanciaManejo constancia;
  final bool busy;
  final bool canEdit;
  final TextEditingController nombreCtrl;
  final TextEditingController curpCtrl;
  final TextEditingController telefonoCtrl;
  final String? tipoLicencia;
  final Map<String, String> tiposLicencia;
  final ValueChanged<String?> onTipoChanged;

  const _ApplicantDataPanel({
    required this.constancia,
    required this.busy,
    required this.canEdit,
    required this.nombreCtrl,
    required this.curpCtrl,
    required this.telefonoCtrl,
    required this.tipoLicencia,
    required this.tiposLicencia,
    required this.onTipoChanged,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = !busy && canEdit && constancia.estaInactiva;

    return _Panel(
      icon: Icons.assignment_ind,
      title: 'Datos del solicitante',
      child: Column(
        children: [
          TextField(
            controller: nombreCtrl,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre del solicitante',
              prefixIcon: Icon(Icons.person),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: curpCtrl,
                  enabled: enabled,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'CURP',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: telefonoCtrl,
                  enabled: enabled,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: tipoLicencia,
            hint: const Text('Seleccione'),
            decoration: const InputDecoration(
              labelText: 'Tipo de licencia',
              prefixIcon: Icon(Icons.badge),
              border: OutlineInputBorder(),
            ),
            items: tiposLicencia.entries
                .map(
                  (entry) => DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                )
                .toList(),
            onChanged: enabled ? onTipoChanged : null,
          ),
        ],
      ),
    );
  }
}

class _ExamModePanel extends StatelessWidget {
  final String? selectedMode;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _ExamModePanel({
    required this.selectedMode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.fact_check,
      title: 'Modalidad',
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              selected: selectedMode == 'LINEA',
              avatar: const Icon(Icons.qr_code_2),
              label: const Text('En linea'),
              onSelected: enabled
                  ? (selected) {
                      if (selected) onChanged('LINEA');
                    }
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ChoiceChip(
              selected: selectedMode == 'IMPRESO',
              avatar: const Icon(Icons.edit_note),
              label: const Text('Escrito'),
              onSelected: enabled
                  ? (selected) {
                      if (selected) onChanged('IMPRESO');
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExamAccessPanel extends StatelessWidget {
  final ConstanciaManejo constancia;
  final bool busy;
  final bool canEdit;
  final VoidCallback onGenerate;
  final VoidCallback onCancel;
  final VoidCallback onCopy;

  const _ExamAccessPanel({
    required this.constancia,
    required this.busy,
    required this.canEdit,
    required this.onGenerate,
    required this.onCancel,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final hasAccess = constancia.tieneAccesoTemporal;
    return _Panel(
      icon: Icons.qr_code_scanner,
      title: 'Examen en linea',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasAccess) ...[
            Center(
              child: FutureBuilder<Uint8List>(
                future: ConstanciasManejoService.fetchAccessQrImage(constancia),
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const SizedBox(
                      height: 230,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: snap.hasData
                        ? Image.memory(
                            snap.data!,
                            key: ValueKey(
                              '${constancia.id}:${constancia.accesoExamenExpira}',
                            ),
                            width: 240,
                            height: 240,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 240,
                            height: 240,
                            alignment: Alignment.center,
                            color: Colors.grey.shade100,
                            child: const Text(
                              'No se pudo cargar el QR.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SelectableText(
              constancia.urlExamen ?? '',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if ((constancia.accesoExamenExpira ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Expira: ${_fmtDateTime(constancia.accesoExamenExpira)}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed:
                        busy || !canEdit || !constancia.puedeGenerarAcceso
                        ? null
                        : onGenerate,
                    icon: const Icon(Icons.refresh),
                    label: Text(busy ? 'Generando...' : 'Regenerar QR'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : onCopy,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copiar liga'),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: busy || !canEdit ? null : onCancel,
                    icon: const Icon(Icons.link_off),
                    label: const Text('Cancelar QR'),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              constancia.examenAprobado
                  ? 'El examen en linea esta aprobado. Ya puedes activar la constancia.'
                  : constancia.estaInactiva
                  ? 'Genera un acceso temporal para que la persona responda desde su telefono.'
                  : 'La constancia ya no permite generar acceso temporal.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (!constancia.examenAprobado) ...[
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: busy || !canEdit || !constancia.puedeGenerarAcceso
                    ? null
                    : onGenerate,
                icon: const Icon(Icons.qr_code_2),
                label: Text(busy ? 'Generando...' : 'Generar QR temporal'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WrittenExamPanel extends StatelessWidget {
  final ConstanciaManejo constancia;
  final bool busy;
  final bool canEdit;
  final TextEditingController totalCtrl;
  final TextEditingController aciertosCtrl;
  final TextEditingController erroresCtrl;
  final TextEditingController calificacionCtrl;
  final TextEditingController observacionesCtrl;
  final VoidCallback onSave;

  const _WrittenExamPanel({
    required this.constancia,
    required this.busy,
    required this.canEdit,
    required this.totalCtrl,
    required this.aciertosCtrl,
    required this.erroresCtrl,
    required this.calificacionCtrl,
    required this.observacionesCtrl,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: Icons.edit_note,
      title: 'Examen escrito',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: totalCtrl,
                  enabled: !busy && canEdit && constancia.puedeCapturarImpreso,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: aciertosCtrl,
                  enabled: !busy && canEdit && constancia.puedeCapturarImpreso,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Aciertos',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: erroresCtrl,
                  enabled: !busy && canEdit && constancia.puedeCapturarImpreso,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Errores',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: calificacionCtrl,
            enabled: false,
            decoration: const InputDecoration(
              labelText: 'Calificacion automatica',
              prefixIcon: Icon(Icons.grade),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: observacionesCtrl,
            enabled: !busy && canEdit && constancia.puedeCapturarImpreso,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Observaciones',
              prefixIcon: Icon(Icons.notes),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: busy || !canEdit || !constancia.puedeCapturarImpreso
                  ? null
                  : onSave,
              icon: const Icon(Icons.save),
              label: Text(busy ? 'Guardando...' : 'Guardar examen escrito'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivationPanel extends StatelessWidget {
  final ConstanciaManejo constancia;
  final bool busy;
  final bool canEdit;
  final VoidCallback onActivate;

  const _ActivationPanel({
    required this.constancia,
    required this.busy,
    required this.canEdit,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final canActivate = constancia.puedeActivar;
    return _Panel(
      icon: Icons.verified,
      title: 'Activacion',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            canActivate
                ? 'El examen esta aprobado. Ya puedes activar la constancia.'
                : _activationBlockedText(constancia),
            style: TextStyle(color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: busy || !canEdit || !canActivate ? null : onActivate,
            icon: const Icon(Icons.verified_user),
            label: Text(busy ? 'Procesando...' : 'Activar constancia'),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Panel({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.replaceAll('_', ' '),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 70),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

String _activationBlockedText(ConstanciaManejo constancia) {
  if (constancia.estaActiva) {
    return 'Esta constancia ya esta activa.';
  }
  if (!constancia.estaInactiva) {
    return 'La constancia no esta disponible para activacion.';
  }
  if (!constancia.examenAprobado) {
    return 'Primero debe existir un examen aprobado.';
  }
  return 'Faltan datos del solicitante o del tipo de examen.';
}

double _calculateWrittenScore(int total, int aciertos) {
  if (total <= 0) return 0;
  return double.parse(((aciertos / total) * 100).toStringAsFixed(2));
}

Color _statusColor(String status) {
  switch (status.trim().toUpperCase()) {
    case 'ACTIVA':
      return const Color(0xFF22C55E);
    case 'IMPRESA_INACTIVA':
      return const Color(0xFFF59E0B);
    case 'CANCELADA':
      return const Color(0xFFEF4444);
    case 'EXPIRADA':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFF38BDF8);
  }
}

String _fmtDateTime(String? raw) {
  final value = raw?.trim() ?? '';
  if (value.isEmpty) return 'Pendiente';
  try {
    final dt = DateTime.parse(value).toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year} ${two(dt.hour)}:${two(dt.minute)}';
  } catch (_) {
    return value;
  }
}

String _fmtNumber(double value) {
  if (value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(2);
}
