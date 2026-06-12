import 'package:flutter/material.dart';
import '../../../services/geo_service.dart';
import '../../../models/hecho_form_data.dart';

class UbicacionCard extends StatefulWidget {
  final HechoFormData data;
  final bool disabled;
  final VoidCallback onChanged;
  final Future<String?> Function()? onLocationCaptured;

  const UbicacionCard({
    super.key,
    required this.data,
    required this.disabled,
    required this.onChanged,
    this.onLocationCaptured,
  });

  @override
  State<UbicacionCard> createState() => _UbicacionCardState();
}

class _UbicacionCardState extends State<UbicacionCard> {
  final _latCtrl = TextEditingController();
  final _lngCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _syncControllersFromData();
  }

  @override
  void didUpdateWidget(covariant UbicacionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.data, widget.data)) {
      _syncControllersFromData();
    }
  }

  @override
  void dispose() {
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  void _syncControllersFromData() {
    _setText(_latCtrl, _coordText(widget.data.lat));
    _setText(_lngCtrl, _coordText(widget.data.lng));
  }

  void _setText(TextEditingController controller, String value) {
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  String _coordText(double? value) {
    if (value == null) return '';
    return value.toStringAsFixed(7);
  }

  double? _parseCoord(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }

  void _applyManualCoords() {
    final latText = _latCtrl.text.trim();
    final lngText = _lngCtrl.text.trim();

    widget.data.ubicacionEditada = true;

    if (latText.isEmpty && lngText.isEmpty) {
      widget.data
        ..lat = null
        ..lng = null
        ..calidadGeo = null
        ..notaGeo = null
        ..fuenteUbicacion = null
        ..ubicacionFormateada = null
        ..placeId = null;
      widget.onChanged();
      return;
    }

    final lat = _parseCoord(latText);
    final lng = _parseCoord(lngText);
    if (lat == null || lng == null) {
      widget.onChanged();
      return;
    }

    widget.data
      ..lat = lat
      ..lng = lng
      ..calidadGeo = null
      ..notaGeo = null
      ..fuenteUbicacion = 'MANUAL_APP'
      ..ubicacionFormateada = null
      ..placeId = null;
    widget.onChanged();
  }

  String? _coordValidator(String? value, {required bool isLat}) {
    final text = (value ?? '').trim();
    final other = (isLat ? _lngCtrl.text : _latCtrl.text).trim();

    if (text.isEmpty && other.isEmpty) return null;
    if (text.isEmpty || other.isEmpty) return 'Captura lat y lng';

    final parsed = _parseCoord(text);
    if (parsed == null) return isLat ? 'Latitud inválida' : 'Longitud inválida';

    if (isLat && (parsed < -90 || parsed > 90)) return 'Latitud inválida';
    if (!isLat && (parsed < -180 || parsed > 180)) return 'Longitud inválida';

    return null;
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final res = await GeoService.getCurrent();
      widget.data
        ..lat = res.lat
        ..lng = res.lng
        ..ubicacionEditada = true
        ..calidadGeo = res.calidadGeo
        ..notaGeo = res.notaGeo
        ..fuenteUbicacion = res.fuenteUbicacion;
      _syncControllersFromData();

      if (!mounted) return;
      widget.onChanged();

      String? autoFillMessage;
      if (widget.data.hasCoords && widget.onLocationCaptured != null) {
        try {
          autoFillMessage = await widget.onLocationCaptured!();
        } catch (_) {
          autoFillMessage =
              'Ubicación lista, pero no se pudo autocompletar la dirección.';
        }
      }

      if (!mounted) return;

      final autoFillDetail = (autoFillMessage ?? '').trim();
      final detalle = autoFillDetail.isNotEmpty
          ? '$autoFillDetail ${res.captureSummary}'
          : widget.data.hasCoords
          ? res.captureSummary
          : (res.notaGeo?.trim().isNotEmpty ?? false)
          ? res.notaGeo!
          : 'No se pudo obtener ubicación';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(detalle)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al obtener ubicación: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clear() {
    widget.data
      ..lat = null
      ..lng = null
      ..ubicacionEditada = true
      ..calidadGeo = null
      ..notaGeo = null
      ..fuenteUbicacion = null
      ..ubicacionFormateada = null
      ..placeId = null;
    _latCtrl.clear();
    _lngCtrl.clear();
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final has = widget.data.hasCoords;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ubicación (GPS)',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              has
                  ? 'Lat: ${widget.data.lat}\nLng: ${widget.data.lng}\nCalidad: ${widget.data.calidadGeo ?? '-'}'
                  : 'Sin ubicación (revisa GPS/permisos)',
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latCtrl,
                    enabled: !widget.disabled && !_loading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Latitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _coordValidator(value, isLat: true),
                    onChanged: (_) => _applyManualCoords(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _lngCtrl,
                    enabled: !widget.disabled && !_loading,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) => _coordValidator(value, isLat: false),
                    onChanged: (_) => _applyManualCoords(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (widget.disabled || _loading) ? null : _refresh,
                    icon: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location),
                    label: const Text('Obtener ubicación'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (widget.disabled || !has) ? null : _clear,
                    icon: const Icon(Icons.clear),
                    label: const Text('Quitar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
