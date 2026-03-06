import 'package:flutter/material.dart';
import '../../../services/geo_service.dart';
import '../../../models/hecho_form_data.dart';

class UbicacionCard extends StatefulWidget {
  final HechoFormData data;
  final bool disabled;
  final VoidCallback onChanged;

  const UbicacionCard({
    super.key,
    required this.data,
    required this.disabled,
    required this.onChanged,
  });

  @override
  State<UbicacionCard> createState() => _UbicacionCardState();
}

class _UbicacionCardState extends State<UbicacionCard> {
  bool _loading = false;

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);

    final res = await GeoService.getCurrent();
    widget.data
      ..lat = res.lat
      ..lng = res.lng
      ..calidadGeo = res.calidadGeo
      ..notaGeo = res.notaGeo
      ..fuenteUbicacion = res.fuenteUbicacion;

    if (mounted) {
      setState(() => _loading = false);
      widget.onChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.data.hasCoords
                ? 'Ubicación lista: ${widget.data.lat}, ${widget.data.lng}'
                : 'No se pudo obtener ubicación',
          ),
        ),
      );
    }
  }

  void _clear() {
    widget.data
      ..lat = null
      ..lng = null
      ..calidadGeo = null
      ..notaGeo = null
      ..fuenteUbicacion = null;
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
