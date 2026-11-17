import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../models/archivo_siniestros/archivo_models.dart';
import '../../../services/archivo_siniestros_service.dart';
import 'archivo_bloques_screen.dart';
import 'widgets/archivo_ui.dart';

class ArchivoMapaScreen extends StatefulWidget {
  final ArchivoSiniestrosService service;
  const ArchivoMapaScreen({super.key, required this.service});
  @override
  State<ArchivoMapaScreen> createState() => _ArchivoMapaScreenState();
}

class _ArchivoMapaScreenState extends State<ArchivoMapaScreen> {
  List<ArchivoMapaArea> _areas = [];
  int? _selectedArea;
  bool _loading = true;
  Object? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.service.getMapa();
      if (mounted) setState(() {
        _areas = result;
        if (_areas.isNotEmpty && !_areas.any((a) => a.area.id == _selectedArea)) {
          _selectedArea = _areas.first.area.id;
        }
      });
    } catch (error) { if (mounted) setState(() => _error = error); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  ArchivoMapaArea? get _area {
    for (final area in _areas) {
      if (area.area.id == _selectedArea) return area;
    }
    return null;
  }

  Future<void> _verAnaquel(ArchivoAnaquel anaquel) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(child: FractionallySizedBox(
        heightFactor: .7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(children: [
              Expanded(child: Text('Anaquel ${anaquel.codigo}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Text(
            '${anaquel.filas} filas × ${anaquel.columnas} columnas · toca un bloque para ver sus libros',
            style: const TextStyle(color: archivoMuted),
          )),
          const SizedBox(height: 8),
          Expanded(child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: anaquel.columnas.clamp(1, 4).toInt(),
              crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.3,
            ),
            itemCount: anaquel.filas * anaquel.columnas,
            itemBuilder: (context, i) {
              final fila = (i ~/ anaquel.columnas) + 1;
              final columna = (i % anaquel.columnas) + 1;
              ArchivoBloque? bloque;
              for (final b in anaquel.bloques) {
                if (b.fila == fila && b.columna == columna) { bloque = b; break; }
              }
              final b = bloque;
              final color = b == null ? Colors.grey : b.disponibles <= 0 ? Colors.orange : archivoTeal;
              return InkWell(
                onTap: b == null ? null : () => _verBloque(b),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(color: color.withValues(alpha: .13), borderRadius: BorderRadius.circular(12), border: Border.all(color: color)),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(b?.codigo ?? 'Sin bloque', style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 3),
                    Text(b == null ? 'Fila $fila · Col. $columna' : '${b.ocupados}/${b.capacidad} libros', style: const TextStyle(fontSize: 12)),
                    if (b != null) Text('${b.reservados} reservados', style: const TextStyle(fontSize: 10)),
                  ]),
                ),
              );
            },
          )),
          Padding(padding: const EdgeInsets.all(12), child: OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ArchivoBloquesScreen(
                service: widget.service, initialAnaquelId: anaquel.id,
              ))).then((_) { if (mounted) _load(); });
            }, icon: const Icon(Icons.grid_view), label: const Text('Administrar bloques'),
          )),
        ]),
      )),
    );
  }

  Future<void> _verBloque(ArchivoBloque bloque) async {
    try {
      final b = await widget.service.getBloque(bloque.id);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (_) => AlertDialog(
        title: Text('Bloque ${b.codigo}'),
        content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capacidad: ${b.capacidad}\nOcupados: ${b.ocupados}\nReservados: ${b.reservados}\nDisponibles: ${b.disponibles}'),
            const Divider(),
            const Text('Libros en la pila', style: TextStyle(fontWeight: FontWeight.w800)),
            if (b.libros.isEmpty) const Text('Sin libros colocados'),
            for (final libro in b.libros) ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: Text(archivoText(libro['codigo'])),
              subtitle: Text('Posición ${archivoText(libro['posicion_actual'])}'),
            ),
            if (b.reservas.isNotEmpty) const Text('Pendientes de colocar', style: TextStyle(fontWeight: FontWeight.w800)),
            for (final reserva in b.reservas) ListTile(
              dense: true, contentPadding: EdgeInsets.zero,
              title: Text(archivoText(reserva['codigo'])),
              subtitle: Text('Posición reservada ${archivoText(reserva['posicion_destino'])}'),
            ),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ));
    } catch (error) { if (mounted) archivoToast(context, error.toString(), error: true); }
  }

  @override
  Widget build(BuildContext context) => ArchivoLayout(
    title: 'Mapa del archivo', subtitle: 'Ubicación física de anaqueles y bloques',
    actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
    child: _loading && _areas.isEmpty ? const ArchivoLoading()
      : _error != null && _areas.isEmpty ? ArchivoError(error: _error!, retry: _load)
      : _areas.isEmpty ? const ArchivoVacio('Todavía no hay áreas configuradas.')
      : Column(children: [
        Padding(padding: const EdgeInsets.all(14), child: DropdownButtonFormField<int>(
          value: _selectedArea,
          isExpanded: true,
          decoration: archivoInput('Área del archivo'),
          items: _areas.map((a) => DropdownMenuItem(value: a.area.id, child: Text(a.area.nombre))).toList(),
          onChanged: (id) => setState(() => _selectedArea = id),
        )),
        Expanded(child: _buildPlano(_area!)),
      ]),
  );

  Widget _buildPlano(ArchivoMapaArea area) {
    final roomWidth = (area.area.ancho ?? 600).clamp(100, 10000).toDouble();
    final roomHeight = (area.area.alto ?? 400).clamp(100, 10000).toDouble();
    final hasDoor = area.area.codigo.toUpperCase() == 'HISTORICO';
    final outside = area.anaqueles.where((a) =>
      a.x == null || a.y == null || a.ancho == null || a.alto == null
    ).toList();
    return Column(children: [
      Expanded(child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: InteractiveViewer(
          constrained: false,
          boundaryMargin: const EdgeInsets.all(180),
          minScale: .35,
          maxScale: 5,
          child: SizedBox(
            width: roomWidth,
            height: roomHeight,
            child: Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _ArchivoGridPainter())),
              Positioned.fill(child: IgnorePointer(child: Container(decoration: BoxDecoration(border: Border.all(color: archivoInk, width: 3))))),
              if (hasDoor) Positioned(left: 4, bottom: 6, child: Container(
                padding: const EdgeInsets.all(6),
                color: const Color(0xFFFFF7E6),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.door_front_door_outlined, size: 18, color: Colors.orange),
                  SizedBox(width: 3), Text('Puerta (referencia)', style: TextStyle(fontSize: 11)),
                ]),
              )),
              for (final a in area.anaqueles)
                if (a.x != null && a.y != null && a.ancho != null && a.alto != null)
                  Positioned(
                    left: a.x!.clamp(0, roomWidth - 1).toDouble(),
                    top: a.y!.clamp(0, roomHeight - 1).toDouble(),
                    width: math.max(30, a.ancho!),
                    height: math.max(24, a.alto!),
                    child: Transform.rotate(
                      angle: a.rotacion * math.pi / 180,
                      child: Material(
                        color: archivoTeal,
                        borderRadius: BorderRadius.circular(5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(5),
                          onTap: () => _verAnaquel(a),
                          child: Center(child: Text(a.codigo, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
                        ),
                      ),
                    ),
                  ),
            ]),
          ),
        ),
      )),
      if (outside.isNotEmpty) Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: Wrap(spacing: 6, runSpacing: 6, children: [
          const Text('Sin posición en mapa:', style: TextStyle(color: archivoMuted)),
          for (final a in outside) ActionChip(label: Text(a.codigo), onPressed: () => _verAnaquel(a)),
        ]),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(14, 4, 14, 12),
        child: Text('Pellizca para acercar y arrastra para recorrer. El dibujo usa las coordenadas del backend.',
          style: TextStyle(color: archivoMuted, fontSize: 12))),
    ]);
  }
}

class _ArchivoGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
