import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../services/auth_service.dart';
import '../../services/dictamenes_service.dart';

class DictamenShowScreen extends StatefulWidget {
  const DictamenShowScreen({super.key});

  @override
  State<DictamenShowScreen> createState() => _DictamenShowScreenState();
}

class _DictamenShowScreenState extends State<DictamenShowScreen> {
  final _svc = DictamenesService();

  bool _loading = true;
  bool _busy = false;
  bool _openingPdf = false;
  String? _error;

  Map<String, dynamic>? _dictamen;

  int _dictamenIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['dictamenId'] != null) {
      return int.tryParse(args['dictamenId'].toString()) ?? 0;
    }
    if (args is Map && args['id'] != null) {
      return int.tryParse(args['id'].toString()) ?? 0;
    }
    return 0;
  }

  String _safe(dynamic v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? '—' : s;
  }

  int _toInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = _dictamenIdFromArgs(context);
      if (id <= 0) {
        setState(() {
          _loading = false;
          _error = 'No se recibió dictamenId.';
        });
        return;
      }
      await _load(id);
    });
  }

  Future<void> _load(int id) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await _svc.show(id);
      setState(() {
        _dictamen = res['data'] is Map
            ? Map<String, dynamic>.from(res['data'])
            : null;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _runBusy(Future<void> Function() fn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await fn();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ===== PDF picker (ya lo tenías) =====
  final _picker = ImagePicker();
  File? _newPdf;
  String? _newPdfName;

  Future<void> _pickPdf() async {
    try {
      final x = await _picker.pickMedia();
      if (x == null) return;

      final path = x.path;
      if (!path.toLowerCase().endsWith('.pdf')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecciona un archivo .pdf')),
        );
        return;
      }

      setState(() {
        _newPdf = File(path);
        _newPdfName = path.split(Platform.pathSeparator).last;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar el archivo: $e')),
      );
    }
  }

  void _clearPicked() {
    setState(() {
      _newPdf = null;
      _newPdfName = null;
    });
  }

  Future<void> _saveEdits() async {
    final d = _dictamen;
    if (d == null) return;

    final id = _toInt(d['id']);
    if (id <= 0) return;

    await _runBusy(() async {
      try {
        final numero = _toInt(d['numero_dictamen']);
        final anio = _toInt(d['anio']);
        final nombrePolicia = _safe(d['nombre_policia']);
        final nombreMp = _safe(d['nombre_mp']);
        final area = _safe(d['area']);

        if (numero <= 0) throw Exception('Número de dictamen inválido.');
        if (anio <= 0) throw Exception('Año inválido.');
        if (nombrePolicia == '—' || nombrePolicia.trim().isEmpty) {
          throw Exception('Nombre del policía es obligatorio.');
        }
        if (nombreMp == '—' || nombreMp.trim().isEmpty) {
          throw Exception('Nombre del MP es obligatorio.');
        }
        if (area == '—' || area.trim().isEmpty) {
          throw Exception('Área es obligatoria.');
        }

        final res = await _svc.update(
          dictamenId: id,
          numeroDictamen: numero,
          anio: anio,
          nombrePolicia: nombrePolicia,
          nombreMp: nombreMp,
          area: area,
          archivoPdf: _newPdf,
        );

        final updated = (res['data'] is Map)
            ? Map<String, dynamic>.from(res['data'])
            : null;

        if (!mounted) return;

        setState(() {
          _dictamen = updated ?? _dictamen;
          _clearPicked();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Guardado correctamente.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    });
  }

  Future<void> _editTextField({
    required String label,
    required String key,
    required String initial,
    int maxLen = 100,
    bool multiline = false,
    TextInputType keyboardType = TextInputType.text,
  }) async {
    if (_dictamen == null) return;

    final controller = TextEditingController(text: initial);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: multiline ? 4 : 1,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: 'Escribe $label',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final v = controller.text.trim();
    if (v.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label es obligatorio')));
      return;
    }
    if (v.length > maxLen) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label máximo $maxLen caracteres')),
      );
      return;
    }

    setState(() {
      _dictamen![key] = v;
    });
  }

  Future<void> _editIntField({
    required String label,
    required String key,
    required int initial,
    int min = 1,
    int max = 999999999,
  }) async {
    if (_dictamen == null) return;

    final controller = TextEditingController(text: initial.toString());

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Editar $label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    final v = int.tryParse(controller.text.trim()) ?? 0;
    if (v < min || v > max) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$label inválido')));
      return;
    }

    setState(() {
      _dictamen![key] = v;
    });
  }

  // URL pública del PDF (tu backend guarda "dictamenes/xxx.pdf" en disk public)
  String _toPublicUrl(String pathOrUrl) {
    final pth = (pathOrUrl).toString().trim();
    if (pth.isEmpty) return '';

    final lower = pth.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) return pth;

    final base = AuthService.baseUrl; // https://seguridadvial-mich.com/api
    final root = base.replaceFirst(
      RegExp(r'/api/?$'),
      '',
    ); // https://seguridadvial-mich.com

    if (pth.startsWith('/storage/')) return '$root$pth';
    if (pth.startsWith('storage/')) return '$root/$pth';
    return '$root/storage/$pth';
  }

  Future<void> _downloadAndOpenPdf({
    required String url,
    required String suggestedName,
  }) async {
    if (_openingPdf) return;

    setState(() => _openingPdf = true);

    try {
      // Nombre final (por si suggestedName viene como "dictamenes/archivo.pdf")
      final cleanName = p.basename(
        suggestedName.trim().isEmpty ? 'dictamen.pdf' : suggestedName,
      );

      // Descarga (si tu storage es público, esto basta; si a veces pide token, se lo mandamos)
      final token = await AuthService.getToken();

      final res = await http.get(
        Uri.parse(url),
        headers: {
          // Si no lo necesitas, no estorba; si alguna vez te regresa 401/403, esto lo salva.
          'Authorization': 'Bearer $token',
          'Accept': 'application/pdf',
        },
      );

      if (res.statusCode < 200 || res.statusCode >= 300) {
        String msg = 'No se pudo descargar el PDF (${res.statusCode}).';
        try {
          final j = json.decode(res.body);
          if (j is Map && j['message'] != null) msg = j['message'].toString();
        } catch (_) {}
        throw Exception(msg);
      }

      // Guardar en cache/temporales
      final dir = await getTemporaryDirectory();
      final filePath = p.join(dir.path, cleanName);

      final f = File(filePath);
      await f.writeAsBytes(res.bodyBytes, flush: true);

      // Abrir con app del sistema
      final result = await OpenFilex.open(filePath);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir el PDF: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al abrir PDF: $e')));
    } finally {
      if (mounted) setState(() => _openingPdf = false);
    }
  }

  Widget _infoTile({
    required String label,
    required String value,
    VoidCallback? onDoubleTap,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onDoubleTap: onDoubleTap,
        onTap: onTap,
        child: ListTile(
          title: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text(value),
          trailing: trailing,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _dictamen;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dictamen'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: (_loading || _busy || _openingPdf)
                ? null
                : () async {
                    final id = _dictamenIdFromArgs(context);
                    if (id > 0) await _load(id);
                  },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : (_error != null)
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, size: 40),
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: () {
                          final id = _dictamenIdFromArgs(context);
                          if (id > 0) _load(id);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              )
            : (d == null)
            ? const Center(child: Text('No se encontró el dictamen.'))
            : RefreshIndicator(
                onRefresh: () async {
                  final id = _toInt(d['id']);
                  if (id > 0) await _load(id);
                },
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Tip: doble tap para editar. Luego presiona "Guardar cambios".',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (_busy || _openingPdf) const SizedBox(width: 10),
                          if (_busy || _openingPdf)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    _infoTile(label: 'ID', value: _safe(d['id'])),

                    _infoTile(
                      label: 'Número',
                      value: _safe(d['numero_dictamen']),
                      onDoubleTap: (_busy || _openingPdf)
                          ? null
                          : () => _editIntField(
                              label: 'Número',
                              key: 'numero_dictamen',
                              initial: _toInt(d['numero_dictamen']),
                              min: 1,
                            ),
                      trailing: (_busy || _openingPdf)
                          ? null
                          : const Icon(Icons.edit, size: 18),
                    ),

                    _infoTile(
                      label: 'Año',
                      value: _safe(d['anio']),
                      onDoubleTap: (_busy || _openingPdf)
                          ? null
                          : () => _editIntField(
                              label: 'Año',
                              key: 'anio',
                              initial: _toInt(d['anio']),
                              min: 2000,
                              max: 2100,
                            ),
                      trailing: (_busy || _openingPdf)
                          ? null
                          : const Icon(Icons.edit, size: 18),
                    ),

                    _infoTile(
                      label: 'Nombre del policía',
                      value: _safe(d['nombre_policia']),
                      onDoubleTap: (_busy || _openingPdf)
                          ? null
                          : () => _editTextField(
                              label: 'Nombre del policía',
                              key: 'nombre_policia',
                              initial: _safe(d['nombre_policia']) == '—'
                                  ? ''
                                  : _safe(d['nombre_policia']),
                              maxLen: 100,
                            ),
                      trailing: (_busy || _openingPdf)
                          ? null
                          : const Icon(Icons.edit, size: 18),
                    ),

                    _infoTile(
                      label: 'Nombre del MP',
                      value: _safe(d['nombre_mp']),
                      onDoubleTap: (_busy || _openingPdf)
                          ? null
                          : () => _editTextField(
                              label: 'Nombre del MP',
                              key: 'nombre_mp',
                              initial: _safe(d['nombre_mp']) == '—'
                                  ? ''
                                  : _safe(d['nombre_mp']),
                              maxLen: 100,
                            ),
                      trailing: (_busy || _openingPdf)
                          ? null
                          : const Icon(Icons.edit, size: 18),
                    ),

                    _infoTile(
                      label: 'Área',
                      value: _safe(d['area']),
                      onDoubleTap: (_busy || _openingPdf)
                          ? null
                          : () => _editTextField(
                              label: 'Área',
                              key: 'area',
                              initial: _safe(d['area']) == '—'
                                  ? ''
                                  : _safe(d['area']),
                              maxLen: 100,
                            ),
                      trailing: (_busy || _openingPdf)
                          ? null
                          : const Icon(Icons.edit, size: 18),
                    ),

                    const SizedBox(height: 12),

                    // ===== PDF =====
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Builder(
                        builder: (_) {
                          final raw = (d['archivo_dictamen'] ?? '')
                              .toString()
                              .trim();
                          final url = raw.isEmpty ? '' : _toPublicUrl(raw);
                          final hasServerPdf = url.isNotEmpty;

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Archivo PDF',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 10),

                              Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: (!hasServerPdf || _openingPdf || _busy)
                                      ? null
                                      : () => _downloadAndOpenPdf(
                                          url: url,
                                          suggestedName: raw,
                                        ),
                                  child: ListTile(
                                    leading: const Icon(Icons.picture_as_pdf),
                                    title: Text(
                                      hasServerPdf
                                          ? p.basename(raw)
                                          : 'Sin archivo en servidor',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: hasServerPdf
                                        ? Text(
                                            url,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade700,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          )
                                        : null,
                                    trailing: hasServerPdf
                                        ? (_openingPdf
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                      ),
                                                )
                                              : const Icon(Icons.open_in_new))
                                        : null,
                                  ),
                                ),
                              ),

                              if (hasServerPdf) ...[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  height: 46,
                                  child: OutlinedButton.icon(
                                    onPressed: (_openingPdf || _busy)
                                        ? null
                                        : () => _downloadAndOpenPdf(
                                            url: url,
                                            suggestedName: raw,
                                          ),
                                    icon: const Icon(Icons.download),
                                    label: Text(
                                      _openingPdf
                                          ? 'Abriendo...'
                                          : 'Descargar y abrir',
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              // Picker nuevo pdf
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _newPdf == null
                                          ? Icons.attach_file
                                          : Icons.check_circle,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _newPdfName == null
                                            ? 'Sin nuevo PDF seleccionado'
                                            : _newPdfName!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    if (_newPdf == null)
                                      OutlinedButton.icon(
                                        onPressed: (_busy || _openingPdf)
                                            ? null
                                            : _pickPdf,
                                        icon: const Icon(Icons.attach_file),
                                        label: const Text('Elegir'),
                                      )
                                    else
                                      IconButton(
                                        tooltip: 'Quitar',
                                        onPressed: (_busy || _openingPdf)
                                            ? null
                                            : _clearPicked,
                                        icon: const Icon(Icons.close),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: (_busy || _openingPdf) ? null : _saveEdits,
                        icon: (_busy || _openingPdf)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(
                          (_busy || _openingPdf)
                              ? 'Procesando...'
                              : 'Guardar cambios',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
