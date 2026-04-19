import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/croquis/croquis_catalog.dart';
import '../../../models/croquis_element.dart';
import '../../../services/croquis_service.dart';
import 'croquis_canvas_painter.dart';

class CroquisScreen extends StatefulWidget {
  const CroquisScreen({super.key});

  @override
  State<CroquisScreen> createState() => _CroquisScreenState();
}

class _CroquisScreenState extends State<CroquisScreen> {
  static const Size _canvasSize = Size(1200, 700);

  final TransformationController _transformationController =
      TransformationController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _textFocusNode = FocusNode();

  final List<CroquisElement> _elementos = <CroquisElement>[];
  final Map<String, ui.Image> _images = <String, ui.Image>{};
  final Set<String> _loadingImages = <String>{};

  bool _initialized = false;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _hechoId = 0;

  int? _activePointer;
  String? _activeMode;
  Offset? _dragOffset;
  Offset? _resizeStartMouse;
  CroquisElement? _resizeOriginal;
  CroquisElement? _editingTextElement;
  double? _rotateStartAngle;
  double? _rotateStartRotation;

  CroquisElement? get _selected {
    for (final el in _elementos) {
      if (el.seleccionado) return el;
    }
    return null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _hechoId = _readHechoId(ModalRoute.of(context)?.settings.arguments);
    unawaited(_load());
  }

  @override
  void dispose() {
    _textController.dispose();
    _textFocusNode.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_hechoId <= 0) {
      setState(() {
        _loading = false;
        _error = 'No llegó el hechoId para abrir el croquis.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final payload = await CroquisService.fetch(_hechoId);
      _elementos
        ..clear()
        ..addAll(payload.elementos);
      _ensureDefaultElements();
      _ensureImagesForElements();

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No se pudo cargar el croquis: $e';
      });
    }
  }

  int _readHechoId(Object? args) {
    if (args is int) return args;
    if (args is String) return int.tryParse(args) ?? 0;
    if (args is Map) {
      final raw = args['hechoId'] ?? args['id'];
      return int.tryParse((raw ?? '').toString()) ?? 0;
    }
    return 0;
  }

  void _ensureDefaultElements() {
    final hasCardinal = _elementos.any((el) {
      final key = (el.clave ?? '').trim();
      return el.tipo == 'icono' &&
          (key == 'cardinal_points' || key == 'cardinal-points');
    });

    if (hasCardinal) return;

    _elementos.add(
      CroquisModels.icono(
        x: _canvasSize.width - 60,
        y: 60,
        clave: CroquisCatalog.cardinalPoints.key,
        src: CroquisCatalog.cardinalPoints.src,
        ancho: 72,
        alto: 72,
      ),
    );
  }

  void _ensureImagesForElements() {
    for (final el in _elementos) {
      final src = (el.src ?? '').trim();
      if (src.isNotEmpty) _loadImage(src);
    }
  }

  void _loadImage(String src) {
    if (_images.containsKey(src) || _loadingImages.contains(src)) return;
    _loadingImages.add(src);

    final provider = NetworkImage(src);
    final stream = provider.resolve(const ImageConfiguration());
    late final ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        stream.removeListener(listener);
        _loadingImages.remove(src);
        _images[src] = info.image;
        if (mounted) setState(() {});
      },
      onError: (_, __) {
        stream.removeListener(listener);
        _loadingImages.remove(src);
      },
    );
    stream.addListener(listener);
  }

  void _clearSelection() {
    for (final el in _elementos) {
      el.seleccionado = false;
    }
  }

  void _select(CroquisElement? element) {
    _clearSelection();
    if (element != null) element.seleccionado = true;
    setState(() {});
  }

  void _addElement(CroquisElement element) {
    _clearSelection();
    element.seleccionado = true;
    _elementos.add(element);
    final src = (element.src ?? '').trim();
    if (src.isNotEmpty) _loadImage(src);
    setState(() {});
  }

  Future<void> _save() async {
    if (_saving || _hechoId <= 0) return;

    setState(() => _saving = true);
    try {
      await _waitForPreviewImages();
      final previewDataUrl = await _buildPreviewDataUrl();

      await CroquisService.save(
        hechoId: _hechoId,
        elementos: _elementos,
        previewDataUrl: previewDataUrl,
      );
      debugPrint('Croquis guardado correctamente.');
    } catch (e) {
      debugPrint('No se pudo guardar el croquis: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _waitForPreviewImages() async {
    _ensureImagesForElements();

    final deadline = DateTime.now().add(const Duration(seconds: 3));
    while (_loadingImages.isNotEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }

  Future<String> _buildPreviewDataUrl() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & _canvasSize);
    final exportElements = _elementos.map((el) {
      final copy = el.copy();
      copy.seleccionado = false;
      return copy;
    }).toList();

    CroquisCanvasPainter(
      elementos: exportElements,
      images: _images,
      showSelection: false,
    ).paint(canvas, _canvasSize);

    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        _canvasSize.width.round(),
        _canvasSize.height.round(),
      );
      try {
        final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        if (byteData == null) return '';

        return 'data:image/png;base64,${base64Encode(byteData.buffer.asUint8List())}';
      } finally {
        image.dispose();
      }
    } finally {
      picture.dispose();
    }
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpiar croquis'),
        content: const Text('Se quitarán todos los elementos del lienzo.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    _elementos.clear();
    _ensureDefaultElements();
    _ensureImagesForElements();
    setState(() {});
  }

  Future<void> _confirmDeleteRemote() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar croquis'),
        content: const Text(
          'Se eliminará el croquis guardado para este hecho.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await CroquisService.delete(_hechoId);
      _elementos.clear();
      _ensureDefaultElements();
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('No se pudo eliminar el croquis: $e');
    }
  }

  void _deleteSelected() {
    final selected = _selected;
    if (selected == null) return;
    _elementos.removeWhere((el) => el.id == selected.id);
    setState(() {});
  }

  Future<void> _showRoadMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: <Widget>[
            const Text(
              'Vialidades',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
            ),
            const SizedBox(height: 8),
            _roadTile('Calle recta', Icons.horizontal_rule, () {
              _addElement(CroquisModels.calle(x: 220, y: 180));
            }),
            _roadTile('Curva', Icons.roundabout_left, () {
              _addElement(CroquisModels.curva(x: 260, y: 220));
            }),
            _roadTile('Cruce', Icons.add_road, () {
              _addElement(CroquisModels.cruce(x: 260, y: 220));
            }),
            _roadTile('Entronque en T', Icons.alt_route, () {
              _addElement(CroquisModels.entronque(x: 260, y: 220));
            }),
            _roadTile('Glorieta', Icons.radio_button_unchecked, () {
              _addElement(CroquisModels.glorieta(x: 360, y: 260));
            }),
          ],
        ),
      ),
    );
  }

  Widget _roadTile(String title, IconData icon, VoidCallback add) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        add();
      },
    );
  }

  Future<void> _showVehiclePicker() async {
    await _showCatalogPicker(
      title: 'Vehículos',
      categories: CroquisCatalog.vehicleCategories,
      onPick: (category, item) {
        final size = _defaultVehicleSize(item);
        _addElement(
          CroquisModels.vehiculo(
            x: 180,
            y: 180,
            categoria: category.key,
            subtipo: item.subtipo ?? item.key,
            src: item.src,
            ancho: size.width,
            alto: size.height,
          ),
        );
      },
    );
  }

  Future<void> _showIconPicker() async {
    await _showCatalogPicker(
      title: 'Iconos',
      categories: CroquisCatalog.iconCategories,
      onPick: (_, item) {
        _addElement(
          CroquisModels.icono(x: 200, y: 200, clave: item.key, src: item.src),
        );
      },
    );
  }

  Future<void> _showCatalogPicker({
    required String title,
    required List<CroquisCatalogCategory> categories,
    required void Function(
      CroquisCatalogCategory category,
      CroquisCatalogItem item,
    )
    onPick,
  }) async {
    final selected = await showModalBottomSheet<_CatalogSelection>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: DefaultTabController(
            length: categories.length,
            child: SizedBox(
              height: MediaQuery.of(context).size.height * .74,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  TabBar(
                    isScrollable: true,
                    tabs: <Widget>[
                      for (final category in categories)
                        Tab(text: category.label),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: <Widget>[
                        for (final category in categories)
                          GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                  maxCrossAxisExtent: 150,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemCount: category.items.length,
                            itemBuilder: (_, index) {
                              final item = category.items[index];
                              return _CatalogButton(
                                item: item,
                                onTap: () {
                                  Navigator.pop(
                                    context,
                                    _CatalogSelection(category, item),
                                  );
                                },
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (!mounted || selected == null) return;
    onPick(selected.category, selected.item);
  }

  Size _defaultVehicleSize(CroquisCatalogItem item) {
    const maxSize = 90.0;
    final naturalWidth = math.max(1.0, item.anchoOriginal ?? maxSize);
    final naturalHeight = math.max(1.0, item.altoOriginal ?? maxSize);

    if (naturalWidth >= naturalHeight) {
      return Size(
        maxSize,
        math.max(20, maxSize * (naturalHeight / naturalWidth)),
      );
    }

    return Size(
      math.max(20, maxSize * (naturalWidth / naturalHeight)),
      maxSize,
    );
  }

  void _openTextPanel({String initial = 'Texto', CroquisElement? editing}) {
    _editingTextElement = editing;
    _textController.text = editing?.contenido ?? initial;
    _textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _textController.text.length,
    );
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _textFocusNode.requestFocus();
    });
  }

  void _cancelTextPanel() {
    _editingTextElement = null;
    _textController.clear();
    _textFocusNode.unfocus();
    setState(() {});
  }

  void _applyTextPanel() {
    final clean = _textController.text.trim();
    if (clean.isEmpty) return;
    final editing = _editingTextElement;

    if (editing != null) {
      editing.contenido = clean;
      _updateTextMetrics(editing);
      _editingTextElement = null;
      _textController.clear();
      _textFocusNode.unfocus();
      setState(() {});
      return;
    }

    _textController.clear();
    _textFocusNode.unfocus();
    _addElement(CroquisModels.texto(contenido: clean));
  }

  void _updateTextMetrics(CroquisElement element) {
    final text = (element.contenido ?? 'Texto').trim();
    element.ancho = (text.length * (element.fontSize ?? 20) * .62)
        .clamp(40, 420)
        .toDouble();
    element.alto = math.max(24, (element.fontSize ?? 20) + 8);
  }

  void _beginInteraction(Offset pos) {
    for (var i = _elementos.length - 1; i >= 0; i -= 1) {
      final el = _elementos[i];
      final handle = _handleHit(el, pos);
      if (handle != null) {
        _select(el);
        _activeMode = handle;

        if (handle == 'rotate') {
          _rotateStartAngle = math.atan2(pos.dy - el.y, pos.dx - el.x);
          _rotateStartRotation = el.rotacion;
        } else if (handle == 'resize') {
          _resizeStartMouse = pos;
          _resizeOriginal = el.copy();
        }
        return;
      }
    }

    final found = _hitTest(pos);
    if (found == null) {
      _select(null);
      _activeMode = null;
      return;
    }

    _select(found);
    _activeMode = 'drag';
    _dragOffset = Offset(pos.dx - found.x, pos.dy - found.y);
  }

  void _updateInteraction(Offset pos) {
    final selected = _selected;
    if (selected == null) return;

    if (_activeMode == 'drag') {
      final offset = _dragOffset ?? Offset.zero;
      selected.x = pos.dx - offset.dx;
      selected.y = pos.dy - offset.dy;
      setState(() {});
      return;
    }

    if (_activeMode == 'rotate') {
      final angle = math.atan2(pos.dy - selected.y, pos.dx - selected.x);
      final startAngle = _rotateStartAngle ?? angle;
      final startRotation = _rotateStartRotation ?? selected.rotacion;
      var deltaAngle = ((angle - startAngle) * 180) / math.pi;

      if (deltaAngle > 180) deltaAngle -= 360;
      if (deltaAngle < -180) deltaAngle += 360;

      selected.rotacion = (startRotation + deltaAngle).roundToDouble();
      setState(() {});
      return;
    }

    if (_activeMode == 'resize') {
      _resizeSelected(selected, pos);
      setState(() {});
      return;
    }

    if (_activeMode == 'curve' && selected.tipo == 'curva') {
      final local = _toLocal(selected, pos);
      var angle = math.atan2(math.max(0, local.dy), math.max(0, local.dx));
      angle = (angle * 180) / math.pi;
      selected.angulo = angle.clamp(30, 180).toDouble();
      setState(() {});
    }
  }

  void _endInteraction() {
    _activePointer = null;
    _activeMode = null;
    _dragOffset = null;
    _resizeStartMouse = null;
    _resizeOriginal = null;
    _rotateStartAngle = null;
    _rotateStartRotation = null;
  }

  void _onPointerDownEdit(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _beginInteraction(event.localPosition);

    if (_activeMode == null) {
      _activePointer = null;
    }
  }

  void _onPointerMoveEdit(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    _updateInteraction(event.localPosition);
  }

  void _onPointerUpEdit(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _endInteraction();
  }

  void _onPointerCancelEdit(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _endInteraction();
  }

  void _resizeSelected(CroquisElement selected, Offset pos) {
    final startMouse = _resizeStartMouse;
    final original = _resizeOriginal;
    if (startMouse == null || original == null) return;

    final dx = pos.dx - startMouse.dx;
    final dy = pos.dy - startMouse.dy;
    final delta = math.max(dx, dy);
    final startLocal = _toLocal(original, startMouse);
    final currentLocal = _toLocal(original, pos);
    final localDx = currentLocal.dx - startLocal.dx;
    final localDy = currentLocal.dy - startLocal.dy;

    if (selected.tipo == 'carro') {
      selected.ancho = math.max(25, (original.ancho ?? 60) + localDx);
      selected.alto = math.max(15, (original.alto ?? 30) + localDy);
    } else if (selected.tipo == 'vehiculo') {
      selected.ancho = math.max(20, (original.ancho ?? 90) + localDx);
      selected.alto = math.max(20, (original.alto ?? 50) + localDy);
    } else if (selected.tipo == 'icono') {
      final aspect = (original.alto ?? 36) / math.max(1, original.ancho ?? 36);
      selected.ancho = math.max(20, (original.ancho ?? 36) + delta);
      selected.alto = math.max(20, selected.ancho! * aspect);
    } else if (selected.tipo == 'calle') {
      selected.largo = math.max(80, (original.largo ?? 260) + localDx);
      _setTotalRoadWidth(
        selected,
        CroquisGeometry.totalRoadWidth(original) + localDy,
      );
    } else if (selected.tipo == 'curva') {
      selected.radioInterno = math.max(
        15,
        (original.radioInterno ?? 45) + localDx,
      );
      _setTotalRoadWidth(
        selected,
        CroquisGeometry.totalRoadWidth(original) + localDy,
      );
    } else if (selected.tipo == 'cruce') {
      selected.largoHorizontal = math.max(
        100,
        CroquisGeometry.crossHorizontalLength(original) + localDx,
      );
      selected.largoVertical = math.max(
        100,
        CroquisGeometry.crossVerticalLength(original) + localDy,
      );
      selected.largo = math.max(
        selected.largoHorizontal!,
        selected.largoVertical!,
      );
    } else if (selected.tipo == 'entronque') {
      selected.largoBase = math.max(100, (original.largoBase ?? 220) + localDx);
      selected.largoBrazo = math.max(
        60,
        (original.largoBrazo ?? 140) + localDy,
      );
    } else if (selected.tipo == 'glorieta') {
      selected.radioIsla = math.max(
        15,
        (original.radioIsla ?? 40) + (delta * .4),
      );
    }
  }

  void _setTotalRoadWidth(CroquisElement el, double totalWidth) {
    final carriles = math.max(1, el.carriles ?? 1);
    final minWidth = carriles * 10;
    el.anchoCarril = math.max(minWidth.toDouble(), totalWidth) / carriles;
  }

  Offset _toLocal(CroquisElement el, Offset point) {
    final dx = point.dx - el.x;
    final dy = point.dy - el.y;
    final angle = (-(el.rotacion) * math.pi) / 180;
    return Offset(
      dx * math.cos(angle) - dy * math.sin(angle),
      dx * math.sin(angle) + dy * math.cos(angle),
    );
  }

  String? _handleHit(CroquisElement el, Offset pos) {
    final local = _toLocal(el, pos);
    final handles = CroquisGeometry.getHandles(el);
    if ((local - handles.rotate).distance <= 34) return 'rotate';
    if ((local - handles.resize).distance <= 34) return 'resize';

    final curve = handles.curve;
    if (curve != null && (local - curve).distance <= 32) return 'curve';
    return null;
  }

  CroquisElement? _hitTest(Offset pos) {
    for (var i = _elementos.length - 1; i >= 0; i -= 1) {
      if (_isInsideElement(_elementos[i], pos)) return _elementos[i];
    }
    return null;
  }

  bool _isInsideElement(CroquisElement el, Offset pos) {
    final local = _toLocal(el, pos);
    const touchSlop = 24.0;

    if (<String>['carro', 'vehiculo', 'icono', 'texto'].contains(el.tipo)) {
      final bounds = CroquisGeometry.getBounds(el);
      return local.dx.abs() <= (bounds.w / 2) + touchSlop &&
          local.dy.abs() <= (bounds.h / 2) + touchSlop;
    }

    if (el.tipo == 'calle') {
      final h = CroquisGeometry.totalRoadWidth(el);
      return local.dx.abs() <= ((el.largo ?? 260) / 2) + touchSlop &&
          local.dy.abs() <= (h / 2) + touchSlop;
    }

    if (el.tipo == 'curva') {
      final outer =
          (el.radioInterno ?? 45) + CroquisGeometry.totalRoadWidth(el);
      final dist = local.distance;
      final angle = math.atan2(local.dy, local.dx);
      final limit = ((el.angulo ?? 90) * math.pi) / 180;
      return local.dx >= 0 &&
          local.dy >= 0 &&
          angle >= 0 &&
          angle <= limit &&
          dist >= ((el.radioInterno ?? 45) - touchSlop) &&
          dist <= outer + touchSlop;
    }

    if (el.tipo == 'cruce') {
      final roadW = CroquisGeometry.totalRoadWidth(el);
      final insideH =
          local.dx.abs() <=
              (CroquisGeometry.crossHorizontalLength(el) / 2) + touchSlop &&
          local.dy.abs() <= (roadW / 2) + touchSlop;
      final insideV =
          local.dx.abs() <= (roadW / 2) + touchSlop &&
          local.dy.abs() <=
              (CroquisGeometry.crossVerticalLength(el) / 2) + touchSlop;
      return insideH || insideV;
    }

    if (el.tipo == 'entronque') {
      final roadW = CroquisGeometry.totalRoadWidth(el);
      final base =
          local.dx.abs() <= ((el.largoBase ?? 220) / 2) + touchSlop &&
          local.dy.abs() <= (roadW / 2) + touchSlop;
      final arm =
          local.dx.abs() <= (roadW / 2) + touchSlop &&
          local.dy >= -(el.largoBrazo ?? 140) - touchSlop &&
          local.dy <= touchSlop;
      return base || arm;
    }

    if (el.tipo == 'glorieta') {
      final outer = (el.radioIsla ?? 40) + CroquisGeometry.totalRoadWidth(el);
      final dist = local.distance;
      return dist >= ((el.radioIsla ?? 40) - touchSlop) &&
          dist <= outer + touchSlop;
    }

    return false;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final selected = _selected;
    if (selected == null) return;

    final delta = event.scrollDelta.dy > 0 ? -1.0 : 1.0;
    final keyboard = HardwareKeyboard.instance;

    if (keyboard.isShiftPressed) {
      selected.rotacion += delta * 5;
      setState(() {});
      return;
    }

    if (keyboard.isControlPressed || keyboard.isMetaPressed) {
      _changeSelectedLanes(delta.round());
      return;
    }

    if (keyboard.isAltPressed && selected.tipo == 'curva') {
      selected.angulo = ((selected.angulo ?? 90) + (delta * 5))
          .clamp(30, 180)
          .toDouble();
      setState(() {});
      return;
    }

    _resizeByWheel(selected, delta);
    setState(() {});
  }

  void _resizeByWheel(CroquisElement el, double delta) {
    if (el.tipo == 'carro') {
      el.ancho = math.max(25, (el.ancho ?? 60) + (delta * 5));
      el.alto = math.max(15, (el.alto ?? 30) + (delta * 3));
    } else if (el.tipo == 'vehiculo' || el.tipo == 'icono') {
      final aspect = (el.alto ?? 40) / math.max(1, el.ancho ?? 40);
      el.ancho = math.max(20, (el.ancho ?? 40) + (delta * 5));
      el.alto = math.max(20, el.ancho! * aspect);
    } else if (el.tipo == 'calle') {
      el.largo = math.max(80, (el.largo ?? 260) + (delta * 12));
      _setTotalRoadWidth(el, CroquisGeometry.totalRoadWidth(el) + (delta * 4));
    } else if (el.tipo == 'curva') {
      el.radioInterno = math.max(15, (el.radioInterno ?? 45) + (delta * 8));
      _setTotalRoadWidth(el, CroquisGeometry.totalRoadWidth(el) + (delta * 4));
    } else if (el.tipo == 'cruce') {
      el.largoHorizontal = math.max(
        100,
        CroquisGeometry.crossHorizontalLength(el) + (delta * 12),
      );
      el.largoVertical = math.max(
        100,
        CroquisGeometry.crossVerticalLength(el) + (delta * 12),
      );
      el.largo = math.max(el.largoHorizontal!, el.largoVertical!);
    } else if (el.tipo == 'entronque') {
      el.largoBase = math.max(100, (el.largoBase ?? 220) + (delta * 12));
      el.largoBrazo = math.max(60, (el.largoBrazo ?? 140) + (delta * 10));
    } else if (el.tipo == 'glorieta') {
      el.radioIsla = math.max(15, (el.radioIsla ?? 40) + (delta * 6));
    }
  }

  void _nudgeSelected(double dx, double dy) {
    final selected = _selected;
    if (selected == null) return;
    selected.x += dx;
    selected.y += dy;
    setState(() {});
  }

  void _changeSelectedLanes(int delta) {
    final selected = _selected;
    if (selected == null || selected.carriles == null) return;
    selected.carriles = math.max(1, selected.carriles! + delta);
    setState(() {});
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (_textFocusNode.hasFocus) return KeyEventResult.ignored;
    final selected = _selected;
    if (selected == null) return KeyEventResult.ignored;

    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.backspace) {
      _deleteSelected();
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      selected.x -= 5;
    } else if (key == LogicalKeyboardKey.arrowRight) {
      selected.x += 5;
    } else if (key == LogicalKeyboardKey.arrowUp) {
      selected.y -= 5;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      selected.y += 5;
    } else if (key == LogicalKeyboardKey.keyR) {
      selected.rotacion += 5;
    } else if (key == LogicalKeyboardKey.equal ||
        key == LogicalKeyboardKey.add) {
      _changeSelectedLanes(1);
      return KeyEventResult.handled;
    } else if (key == LogicalKeyboardKey.minus ||
        key == LogicalKeyboardKey.numpadSubtract) {
      _changeSelectedLanes(-1);
      return KeyEventResult.handled;
    } else if (selected.tipo == 'curva' && key == LogicalKeyboardKey.keyQ) {
      selected.angulo = math.max(30, (selected.angulo ?? 90) - 5);
    } else if (selected.tipo == 'curva' && key == LogicalKeyboardKey.keyE) {
      selected.angulo = math.min(180, (selected.angulo ?? 90) + 5);
    } else {
      return KeyEventResult.ignored;
    }

    setState(() {});
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          title: Text('Croquis (Hecho #$_hechoId)'),
          actions: <Widget>[
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _saving ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'Eliminar guardado',
              onPressed: _saving ? null : _confirmDeleteRemote,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        _toolbar(),
        if (_textFocusNode.hasFocus || _textController.text.isNotEmpty)
          _textEditorPanel(),
        Expanded(child: _canvas()),
        _selectedControls(),
      ],
    );
  }

  Widget _toolbar() {
    return Material(
      color: Colors.white,
      elevation: 1,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: <Widget>[
            _ToolButton(
              icon: Icons.directions_car,
              label: 'Vehículos',
              onPressed: _showVehiclePicker,
            ),
            _ToolButton(
              icon: Icons.add_road,
              label: 'Vialidades',
              onPressed: _showRoadMenu,
            ),
            _ToolButton(
              icon: Icons.remove,
              label: '- Carril',
              onPressed: () => _changeSelectedLanes(-1),
            ),
            _ToolButton(
              icon: Icons.add,
              label: '+ Carril',
              onPressed: () => _changeSelectedLanes(1),
            ),
            _ToolButton(
              icon: Icons.place,
              label: 'Iconos',
              onPressed: _showIconPicker,
            ),
            _ToolButton(
              icon: Icons.text_fields,
              label: 'Texto',
              onPressed: () => _openTextPanel(initial: 'Texto'),
            ),
            _ToolButton(
              icon: Icons.cleaning_services,
              label: 'Limpiar',
              onPressed: _confirmClear,
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _textEditorPanel() {
    final editing = _editingTextElement != null;
    return Material(
      color: const Color(0xFFF8FAFC),
      elevation: 2,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _textFocusNode,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _applyTextPanel(),
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: editing ? 'Editar texto' : 'Agregar texto',
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _applyTextPanel,
                child: Text(editing ? 'Actualizar' : 'Agregar'),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Cancelar texto',
                onPressed: _cancelTextPanel,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _canvas() {
    return Container(
      color: const Color(0xFFE5EAF2),
      child: InteractiveViewer(
        transformationController: _transformationController,
        constrained: false,
        panEnabled: _activeMode == null,
        scaleEnabled: _activeMode == null,
        minScale: .35,
        maxScale: 3,
        boundaryMargin: const EdgeInsets.all(500),
        child: SizedBox(
          width: _canvasSize.width,
          height: _canvasSize.height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: _onPointerDownEdit,
            onPointerMove: _onPointerMoveEdit,
            onPointerUp: _onPointerUpEdit,
            onPointerCancel: _onPointerCancelEdit,
            onPointerSignal: _onPointerSignal,
            child: CustomPaint(
              size: _canvasSize,
              painter: CroquisCanvasPainter(
                elementos: _elementos,
                images: _images,
                showSelection: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _selectedControls() {
    final selected = _selected;
    if (selected == null) {
      return const _HelpBar(
        text:
            'Toca una pieza para seleccionarla. Rojo: girar. Naranja: cambiar tamaño. Morado: abrir/cerrar curva.',
      );
    }

    final canLanes = selected.carriles != null;
    final isCurve = selected.tipo == 'curva';
    final isText = selected.tipo == 'texto';

    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Row(
            children: <Widget>[
              Chip(
                label: Text(
                  selected.tipo.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _SmallAction(
                icon: Icons.rotate_left,
                label: '-15°',
                onPressed: () {
                  selected.rotacion -= 15;
                  setState(() {});
                },
              ),
              _SmallAction(
                icon: Icons.rotate_right,
                label: '+15°',
                onPressed: () {
                  selected.rotacion += 15;
                  setState(() {});
                },
              ),
              _SmallAction(
                icon: Icons.zoom_out_map,
                label: 'Tamaño -',
                onPressed: () {
                  _resizeByWheel(selected, -1);
                  setState(() {});
                },
              ),
              _SmallAction(
                icon: Icons.open_in_full,
                label: 'Tamaño +',
                onPressed: () {
                  _resizeByWheel(selected, 1);
                  setState(() {});
                },
              ),
              _SmallAction(
                icon: Icons.keyboard_arrow_left,
                label: 'Izq',
                onPressed: () => _nudgeSelected(-10, 0),
              ),
              _SmallAction(
                icon: Icons.keyboard_arrow_up,
                label: 'Arriba',
                onPressed: () => _nudgeSelected(0, -10),
              ),
              _SmallAction(
                icon: Icons.keyboard_arrow_down,
                label: 'Abajo',
                onPressed: () => _nudgeSelected(0, 10),
              ),
              _SmallAction(
                icon: Icons.keyboard_arrow_right,
                label: 'Der',
                onPressed: () => _nudgeSelected(10, 0),
              ),
              if (canLanes)
                _SmallAction(
                  icon: Icons.remove,
                  label: 'Carril',
                  onPressed: () => _changeSelectedLanes(-1),
                ),
              if (canLanes)
                _SmallAction(
                  icon: Icons.add,
                  label: 'Carril',
                  onPressed: () => _changeSelectedLanes(1),
                ),
              if (isCurve)
                _SmallAction(
                  icon: Icons.keyboard_arrow_left,
                  label: 'Cerrar',
                  onPressed: () {
                    selected.angulo = math.max(30, (selected.angulo ?? 90) - 5);
                    setState(() {});
                  },
                ),
              if (isCurve)
                _SmallAction(
                  icon: Icons.keyboard_arrow_right,
                  label: 'Abrir',
                  onPressed: () {
                    selected.angulo = math.min(
                      180,
                      (selected.angulo ?? 90) + 5,
                    );
                    setState(() {});
                  },
                ),
              if (isText)
                _SmallAction(
                  icon: Icons.edit,
                  label: 'Texto',
                  onPressed: () => _openTextPanel(editing: selected),
                ),
              _SmallAction(
                icon: Icons.delete,
                label: 'Borrar',
                color: Colors.red,
                onPressed: _deleteSelected,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}

class _CatalogSelection {
  const _CatalogSelection(this.category, this.item);

  final CroquisCatalogCategory category;
  final CroquisCatalogItem item;
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: color),
        label: Text(label, style: TextStyle(color: color)),
      ),
    );
  }
}

class _HelpBar extends StatelessWidget {
  const _HelpBar({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _CatalogButton extends StatelessWidget {
  const _CatalogButton({required this.item, required this.onTap});

  final CroquisCatalogItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Expanded(
              child: Image.network(
                item.src,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image_not_supported),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
