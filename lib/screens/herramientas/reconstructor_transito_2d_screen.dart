import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/reconstructor_transito_project.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';
import 'reconstructor_transito_painter.dart';

enum _EditorTool { select, path, pan }

class ReconstructorTransito2dScreen extends StatefulWidget {
  const ReconstructorTransito2dScreen({super.key});

  @override
  State<ReconstructorTransito2dScreen> createState() =>
      _ReconstructorTransito2dScreenState();
}

class _ReconstructorTransito2dScreenState
    extends State<ReconstructorTransito2dScreen>
    with SingleTickerProviderStateMixin {
  static const _storageKey = 'sistemaEstadistico.reconstructorTransito.v1';

  final _transformation = TransformationController();
  final _nameController = TextEditingController();
  final _hypothesisController = TextEditingController();
  late final AnimationController _playback;

  ReconstructorProject _project = ReconstructorProject.demo();
  final List<String> _history = <String>[];
  _EditorTool _tool = _EditorTool.select;
  String? _selectedKind;
  String? _selectedId;
  String? _pendingEvent;
  String? _dragMode;
  int? _curveHandle;
  double _currentTime = 0;
  double _playbackRate = 1;
  bool _loading = true;
  bool _saved = true;
  bool _exporting = false;
  Timer? _saveTimer;

  ReconstructorActor? get _selectedActor => _selectedKind == 'actor'
      ? _project.actors.where((item) => item.id == _selectedId).firstOrNull
      : null;
  ReconstructorRoad? get _selectedRoad => _selectedKind == 'road'
      ? _project.roads.where((item) => item.id == _selectedId).firstOrNull
      : null;
  ReconstructorEvent? get _selectedEvent => _selectedKind == 'event'
      ? _project.events.where((item) => item.id == _selectedId).firstOrNull
      : null;

  @override
  void initState() {
    super.initState();
    _playback = AnimationController(vsync: this)
      ..addListener(() {
        if (!mounted) return;
        setState(() {
          _currentTime = _playback.value * _project.metadata.duration;
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) setState(() {});
      });
    unawaited(_loadDraft());
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _playback.dispose();
    _transformation.dispose();
    _nameController.dispose();
    _hypothesisController.dispose();
    super.dispose();
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.trim().isNotEmpty) {
        _project = ReconstructorProject.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {
      _project = ReconstructorProject.demo();
    }
    _syncMetadataInputs();
    if (mounted) setState(() => _loading = false);
  }

  void _syncMetadataInputs() {
    _nameController.text = _project.metadata.name;
    _hypothesisController.text = _project.metadata.hypothesis;
  }

  void _updateMetadata() {
    _project.metadata.name = _nameController.text.trim().isEmpty
        ? 'Hecho de tránsito sin título'
        : _nameController.text.trim();
    _project.metadata.hypothesis = _hypothesisController.text.trim().isEmpty
        ? 'Hipótesis A'
        : _hypothesisController.text.trim();
    _markDirty();
  }

  Future<void> _saveDraft({bool notify = false}) async {
    _updateMetadataWithoutScheduling();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_project.toJson()));
    if (!mounted) return;
    setState(() => _saved = true);
    if (notify) _message('Borrador guardado en este dispositivo.');
  }

  void _updateMetadataWithoutScheduling() {
    _project.metadata.name = _nameController.text.trim().isEmpty
        ? 'Hecho de tránsito sin título'
        : _nameController.text.trim();
    _project.metadata.hypothesis = _hypothesisController.text.trim().isEmpty
        ? 'Hipótesis A'
        : _hypothesisController.text.trim();
  }

  void _markDirty() {
    if (mounted) setState(() => _saved = false);
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 900), _saveDraft);
  }

  void _pushHistory() {
    _history.add(jsonEncode(_project.toJson()));
    if (_history.length > 35) _history.removeAt(0);
  }

  void _undo() {
    if (_history.isEmpty) return;
    _pause();
    setState(() {
      _project = ReconstructorProject.fromJson(
        Map<String, dynamic>.from(jsonDecode(_history.removeLast()) as Map),
      );
      _selectedKind = null;
      _selectedId = null;
      _currentTime = _currentTime.clamp(0, _project.metadata.duration);
      _syncMetadataInputs();
    });
    _markDirty();
  }

  void _setTool(_EditorTool tool) {
    _pause();
    setState(() {
      _tool = tool;
      _pendingEvent = null;
    });
  }

  void _setCurrentTime(double value) {
    _pause();
    setState(() {
      _currentTime = value.clamp(0, _project.metadata.duration);
      _playback.value = _currentTime / _project.metadata.duration;
    });
  }

  void _play() {
    if (_playback.isAnimating) {
      _pause();
      return;
    }
    if (_currentTime >= _project.metadata.duration - .01) {
      _currentTime = 0;
      _playback.value = 0;
    } else {
      _playback.value = _currentTime / _project.metadata.duration;
    }
    final remaining = _project.metadata.duration - _currentTime;
    _playback.animateTo(
      1,
      duration: Duration(
        milliseconds: (remaining * 1000 / _playbackRate).round(),
      ),
      curve: Curves.linear,
    );
    setState(() {});
  }

  void _pause() {
    if (_playback.isAnimating) _playback.stop();
    if (mounted) setState(() {});
  }

  void _addActor(String type) {
    _pushHistory();
    final count = _project.actors.where((item) => item.type == type).length + 1;
    final actor = ReconstructorActor(
      id: reconstructorId('actor'),
      type: type,
      name: '${actorLabel(type)} $count',
      color: actorDefaultColor(type),
      keyframes: <ReconstructorKeyframe>[
        ReconstructorKeyframe(time: _currentTime, x: 600, y: 350),
      ],
    );
    setState(() {
      _project.actors.add(actor);
      _selectedKind = 'actor';
      _selectedId = actor.id;
      _tool = _EditorTool.select;
    });
    _markDirty();
  }

  void _addRoad(String type) {
    _pushHistory();
    final road = ReconstructorRoad(
      id: reconstructorId('road'),
      type: type,
      name: type == 'curve' ? 'Calle curva' : 'Calle recta',
      x: 600,
      y: 350,
      lengthMeters: type == 'curve' ? 32 : 42,
    );
    setState(() {
      _project.roads.add(road);
      _selectedKind = 'road';
      _selectedId = road.id;
      _tool = _EditorTool.select;
    });
    _markDirty();
  }

  void _addCrossing() {
    _pushHistory();
    final first = ReconstructorRoad(
      id: reconstructorId('road'),
      name: 'Avenida principal',
      x: 600,
      y: 350,
      lengthMeters: 55,
      leftEdge: 'sidewalk',
      rightEdge: 'sidewalk',
    );
    final second = ReconstructorRoad(
      id: reconstructorId('road'),
      name: 'Calle transversal',
      x: 600,
      y: 350,
      lengthMeters: 38,
      rotation: 90,
    );
    setState(() {
      _project.roads.addAll(<ReconstructorRoad>[first, second]);
      _selectedKind = 'road';
      _selectedId = second.id;
    });
    _markDirty();
  }

  void _selectPendingEvent(String code) {
    _pause();
    setState(() {
      _tool = _EditorTool.select;
      _pendingEvent = code;
    });
    _message('Toca la escena para colocar ${eventLabels[code]}.');
  }

  void _addEventAt(String code, Offset point) {
    _pushHistory();
    final event = ReconstructorEvent(
      id: reconstructorId('event'),
      code: code,
      x: point.dx,
      y: point.dy,
      time: _currentTime,
      description: eventLabels[code]!,
    );
    setState(() {
      _project.events.add(event);
      _selectedKind = 'event';
      _selectedId = event.id;
      _pendingEvent = null;
    });
    _markDirty();
  }

  void _addKeyframeAt(Offset point) {
    final actor = _selectedActor;
    if (actor == null) {
      _message('Selecciona un participante antes de trazar su ruta.');
      return;
    }
    _pushHistory();
    actor.upsert(_currentTime, point.dx, point.dy);
    setState(() {});
    _markDirty();
  }

  void _deleteSelection() {
    if (_selectedId == null) return;
    _pushHistory();
    setState(() {
      if (_selectedKind == 'actor') {
        _project.actors.removeWhere((item) => item.id == _selectedId);
      } else if (_selectedKind == 'road') {
        _project.roads.removeWhere((item) => item.id == _selectedId);
      } else if (_selectedKind == 'event') {
        _project.events.removeWhere((item) => item.id == _selectedId);
      }
      _selectedKind = null;
      _selectedId = null;
    });
    _markDirty();
  }

  void _canvasTap(Offset point) {
    if (_pendingEvent != null) {
      _addEventAt(_pendingEvent!, point);
      return;
    }
    if (_tool == _EditorTool.path) {
      _addKeyframeAt(point);
      return;
    }
    final hit = _hitTest(point);
    setState(() {
      _selectedKind = hit?.$1;
      _selectedId = hit?.$2;
    });
  }

  void _dragStart(Offset point) {
    if (_tool != _EditorTool.select || _pendingEvent != null) return;
    final selectedRoad = _selectedRoad;
    if (selectedRoad?.type == 'curve') {
      final handle = _curveHandleHit(selectedRoad!, point);
      if (handle != null) {
        _pushHistory();
        _dragMode = 'curve';
        _curveHandle = handle;
        return;
      }
    }
    final hit = _hitTest(point);
    if (hit == null) return;
    _pushHistory();
    _selectedKind = hit.$1;
    _selectedId = hit.$2;
    _dragMode = 'move';
    setState(() {});
  }

  void _dragUpdate(Offset point) {
    if (_dragMode == null) return;
    if (_dragMode == 'curve') {
      final road = _selectedRoad;
      if (road == null || _curveHandle == null) return;
      final local =
          _roadLocalPoint(road, point) / _project.metadata.pixelsPerMeter;
      switch (_curveHandle!) {
        case 0:
          road.curve.startX = local.dx;
          road.curve.startY = local.dy;
        case 1:
          road.curve.control1X = local.dx;
          road.curve.control1Y = local.dy;
        case 2:
          road.curve.control2X = local.dx;
          road.curve.control2Y = local.dy;
        case 3:
          road.curve.endX = local.dx;
          road.curve.endY = local.dy;
      }
      setState(() {});
      return;
    }
    if (_selectedKind == 'actor') {
      final actor = _selectedActor;
      if (actor == null) return;
      final position = actor.positionAt(_currentTime);
      actor.upsert(
        _currentTime,
        point.dx,
        point.dy,
        rotation: position?.rotation,
      );
    } else if (_selectedKind == 'road') {
      final road = _selectedRoad;
      if (road == null) return;
      road.x = point.dx;
      road.y = point.dy;
    } else if (_selectedKind == 'event') {
      final event = _selectedEvent;
      if (event == null) return;
      event.x = point.dx;
      event.y = point.dy;
    }
    setState(() {});
  }

  void _dragEnd() {
    if (_dragMode == null) return;
    _dragMode = null;
    _curveHandle = null;
    _markDirty();
  }

  (String, String)? _hitTest(Offset point) {
    for (final event in _project.events.reversed) {
      if ((Offset(event.x, event.y) - point).distance <= 24) {
        return ('event', event.id);
      }
    }
    for (final actor in _project.actors.reversed) {
      final position = actor.positionAt(_currentTime);
      if (position != null &&
          (Offset(position.x, position.y) - point).distance <= 52) {
        return ('actor', actor.id);
      }
    }
    for (final road in _project.roads.reversed) {
      final local = _roadLocalPoint(road, point);
      final halfWidth =
          road.lanes *
          road.laneWidthMeters *
          _project.metadata.pixelsPerMeter /
          2;
      if (road.type == 'straight') {
        final halfLength =
            road.lengthMeters * _project.metadata.pixelsPerMeter / 2;
        if (local.dx.abs() <= halfLength && local.dy.abs() <= halfWidth + 12) {
          return ('road', road.id);
        }
      } else {
        final painter = ReconstructorTransitoPainter(
          project: _project,
          currentTime: _currentTime,
        );
        for (var index = 0; index <= 50; index++) {
          if ((painter.curvePoint(road, index / 50) - local).distance <=
              halfWidth + 14) {
            return ('road', road.id);
          }
        }
      }
    }
    return null;
  }

  Offset _roadLocalPoint(ReconstructorRoad road, Offset point) {
    final translated = point - Offset(road.x, road.y);
    final radians = -road.rotation * math.pi / 180;
    return Offset(
      translated.dx * math.cos(radians) - translated.dy * math.sin(radians),
      translated.dx * math.sin(radians) + translated.dy * math.cos(radians),
    );
  }

  int? _curveHandleHit(ReconstructorRoad road, Offset point) {
    final local = _roadLocalPoint(road, point);
    final scale = _project.metadata.pixelsPerMeter;
    final handles = <Offset>[
      Offset(road.curve.startX * scale, road.curve.startY * scale),
      Offset(road.curve.control1X * scale, road.curve.control1Y * scale),
      Offset(road.curve.control2X * scale, road.curve.control2Y * scale),
      Offset(road.curve.endX * scale, road.curve.endY * scale),
    ];
    for (var index = 0; index < handles.length; index++) {
      if ((handles[index] - local).distance <= 18) return index;
    }
    return null;
  }

  Future<void> _newProject() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo proyecto'),
        content: const Text(
          'Se limpiará la escena actual. Exporta el JSON antes si quieres conservar otra copia.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Crear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    _pushHistory();
    setState(() {
      _project = ReconstructorProject();
      _currentTime = 0;
      _selectedKind = null;
      _selectedId = null;
      _syncMetadataInputs();
    });
    await _saveDraft();
  }

  Future<void> _exportJson() async {
    _updateMetadataWithoutScheduling();
    final bytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(_project.toJson()),
    );
    final baseName = _safeFilename(_project.metadata.name);
    String? savedPath;
    try {
      savedPath = await FileSaver.instance.saveFile(
        name: baseName,
        bytes: bytes,
        ext: 'json',
        mimeType: MimeType.json,
      );
    } catch (_) {}
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$baseName.json');
    await file.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    _message(
      savedPath?.isNotEmpty == true
          ? 'Proyecto JSON guardado.'
          : 'Proyecto listo para compartir.',
    );
    await Share.shareXFiles(<XFile>[
      XFile(file.path, mimeType: 'application/json'),
    ]);
  }

  Future<void> _importJson() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final selected = result.files.single;
      final bytes =
          selected.bytes ??
          (selected.path == null
              ? null
              : await File(selected.path!).readAsBytes());
      if (bytes == null) {
        throw const FormatException('No se pudo leer el archivo.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const FormatException(
          'El archivo no contiene un proyecto válido.',
        );
      }
      final imported = ReconstructorProject.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      _pushHistory();
      setState(() {
        _project = imported;
        _currentTime = 0;
        _selectedKind = null;
        _selectedId = null;
        _syncMetadataInputs();
      });
      await _saveDraft();
      _message('Proyecto importado correctamente.');
    } catch (error) {
      _message('No se pudo importar: $error');
    }
  }

  Future<void> _exportPng() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Offset.zero & ReconstructorTransitoPainter.canvasSize,
      );
      ReconstructorTransitoPainter(
        project: _project,
        currentTime: _currentTime,
        showSelection: false,
      ).paint(canvas, ReconstructorTransitoPainter.canvasSize);
      final picture = recorder.endRecording();
      final image = await picture.toImage(1200, 700);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (data == null) throw Exception('No fue posible generar la imagen.');
      final bytes = data.buffer.asUint8List();
      final baseName =
          '${_safeFilename(_project.metadata.name)}_${(_currentTime * 10).round()}';
      try {
        await FileSaver.instance.saveFile(
          name: baseName,
          bytes: bytes,
          ext: 'png',
          mimeType: MimeType.png,
        );
      } catch (_) {}
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$baseName.png');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await Share.shareXFiles(<XFile>[XFile(file.path, mimeType: 'image/png')]);
    } catch (error) {
      _message('No se pudo exportar la escena: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportAnimationGif() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    _message('Generando la animación; puede tardar unos segundos.');
    try {
      final duration = _project.metadata.duration;
      final frameCount = math.min(90, math.max(12, (duration * 6).round()));
      final frameDelay = math.max(
        2,
        (duration * 100 / (frameCount - 1)).round(),
      );
      final encoder = img.GifEncoder(
        repeat: 0,
        samplingFactor: 20,
        numColors: 128,
      );

      for (var index = 0; index < frameCount; index++) {
        final time = duration * index / (frameCount - 1);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder, Offset.zero & const Size(600, 350))
          ..scale(.5);
        ReconstructorTransitoPainter(
          project: _project,
          currentTime: time,
          showSelection: false,
        ).paint(canvas, ReconstructorTransitoPainter.canvasSize);
        final picture = recorder.endRecording();
        final rendered = await picture.toImage(600, 350);
        final byteData = await rendered.toByteData(
          format: ui.ImageByteFormat.png,
        );
        rendered.dispose();
        picture.dispose();
        if (byteData == null) {
          throw Exception('No fue posible dibujar el fotograma ${index + 1}.');
        }
        final frame = img.decodePng(byteData.buffer.asUint8List());
        if (frame == null) {
          throw Exception(
            'No fue posible codificar el fotograma ${index + 1}.',
          );
        }
        encoder.addFrame(frame, duration: frameDelay);
        if (index % 8 == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      final bytes = encoder.finish();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('La animación quedó vacía.');
      }
      final baseName = '${_safeFilename(_project.metadata.name)}_animacion';
      try {
        await FileSaver.instance.saveFile(
          name: baseName,
          bytes: bytes,
          ext: 'gif',
          mimeType: MimeType.gif,
        );
      } catch (_) {}
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$baseName.gif');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      _message('Animación completa exportada.');
      await Share.shareXFiles(<XFile>[XFile(file.path, mimeType: 'image/gif')]);
    } catch (error) {
      _message('No se pudo exportar la animación: $error');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String _safeFilename(String value) {
    final clean = value.trim().replaceAll(
      RegExp(r'[^a-zA-Z0-9áéíóúÁÉÍÓÚñÑ_-]+'),
      '_',
    );
    return clean.isEmpty ? 'reconstruccion_transito' : clean;
  }

  void _fitScene() {
    _transformation.value = Matrix4.identity();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _logout() async {
    try {
      await TrackingService.stop();
    } catch (_) {}
    await AuthService.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: _logout),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Reconstructor de tránsito 2D'),
            Text(
              'Reconstrucción ilustrativa',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            tooltip: 'Acciones del proyecto',
            onSelected: (value) {
              if (value == 'new') unawaited(_newProject());
              if (value == 'save') unawaited(_saveDraft(notify: true));
              if (value == 'json') unawaited(_exportJson());
              if (value == 'import') unawaited(_importJson());
              if (value == 'png') unawaited(_exportPng());
              if (value == 'animation') unawaited(_exportAnimationGif());
            },
            itemBuilder: (_) => const <PopupMenuEntry<String>>[
              PopupMenuItem(
                value: 'new',
                child: ListTile(
                  leading: Icon(Icons.note_add_outlined),
                  title: Text('Nuevo proyecto'),
                ),
              ),
              PopupMenuItem(
                value: 'save',
                child: ListTile(
                  leading: Icon(Icons.save_outlined),
                  title: Text('Guardar borrador'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'json',
                child: ListTile(
                  leading: Icon(Icons.data_object),
                  title: Text('Exportar JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_open_outlined),
                  title: Text('Importar JSON'),
                ),
              ),
              PopupMenuItem(
                value: 'png',
                child: ListTile(
                  leading: Icon(Icons.image_outlined),
                  title: Text('Compartir escena PNG'),
                ),
              ),
              PopupMenuItem(
                value: 'animation',
                child: ListTile(
                  leading: Icon(Icons.movie_creation_outlined),
                  title: Text('Exportar animación GIF'),
                ),
              ),
            ],
          ),
          const AccountMenuAction(),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1050;
                return Column(
                  children: <Widget>[
                    _buildNotice(),
                    _buildProjectBar(wide),
                    Expanded(
                      child: wide
                          ? Row(
                              children: <Widget>[
                                SizedBox(width: 245, child: _buildLibrary()),
                                Expanded(child: _buildStage()),
                                SizedBox(width: 300, child: _buildInspector()),
                              ],
                            )
                          : _buildCompactWorkspace(),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildNotice() => Container(
    width: double.infinity,
    color: const Color(0xFFFFF7DB),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    child: Row(
      children: <Widget>[
        const Icon(Icons.science_outlined, size: 18, color: Color(0xFF9A6700)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text(
            'Primera versión: tiempos, velocidades y recorridos son una hipótesis visual; no constituyen un cálculo pericial.',
            style: TextStyle(fontSize: 12),
          ),
        ),
        Text(
          _saved ? 'Guardado local' : 'Cambios pendientes',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _saved ? Colors.green.shade700 : Colors.orange.shade800,
          ),
        ),
      ],
    ),
  );

  Widget _buildProjectBar(bool wide) => Container(
    padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
    color: const Color(0xFF14293B),
    child: wide
        ? Row(children: _projectFields())
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: 760, child: Row(children: _projectFields())),
          ),
  );

  List<Widget> _projectFields() => <Widget>[
    Expanded(
      flex: 3,
      child: _darkField(
        'Nombre del proyecto',
        _nameController,
        _updateMetadata,
      ),
    ),
    const SizedBox(width: 10),
    Expanded(
      flex: 2,
      child: _darkField('Hipótesis', _hypothesisController, _updateMetadata),
    ),
    const SizedBox(width: 10),
    SizedBox(
      width: 105,
      child: _numberMenu(
        'Duración',
        '${_project.metadata.duration.toStringAsFixed(0)} s',
        <double>[5, 10, 15, 20, 30, 60],
        (value) {
          _pushHistory();
          setState(() {
            _project.metadata.duration = value;
            _currentTime = _currentTime.clamp(0, value);
          });
          _markDirty();
        },
      ),
    ),
    const SizedBox(width: 10),
    SizedBox(
      width: 110,
      child: _numberMenu(
        'Escala',
        '${_project.metadata.pixelsPerMeter.toStringAsFixed(0)} px/m',
        <double>[10, 15, 20, 25, 30],
        (value) {
          _pushHistory();
          setState(() => _project.metadata.pixelsPerMeter = value);
          _markDirty();
        },
      ),
    ),
  ];

  Widget _darkField(
    String label,
    TextEditingController controller,
    VoidCallback changed,
  ) => TextField(
    controller: controller,
    onChanged: (_) => changed(),
    style: const TextStyle(color: Colors.white, fontSize: 13),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFAEC4D6), fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF203B51),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
  );

  Widget _numberMenu(
    String label,
    String value,
    List<double> values,
    ValueChanged<double> changed,
  ) => InputDecorator(
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFAEC4D6), fontSize: 12),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFF203B51),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<double>(
        isDense: true,
        isExpanded: true,
        value:
            values.contains(
              label == 'Duración'
                  ? _project.metadata.duration
                  : _project.metadata.pixelsPerMeter,
            )
            ? (label == 'Duración'
                  ? _project.metadata.duration
                  : _project.metadata.pixelsPerMeter)
            : values.first,
        dropdownColor: const Color(0xFF203B51),
        style: const TextStyle(color: Colors.white, fontSize: 12),
        items: values
            .map(
              (item) => DropdownMenuItem(
                value: item,
                child: Text(
                  label == 'Duración'
                      ? '${item.toInt()} s'
                      : '${item.toInt()} px/m',
                ),
              ),
            )
            .toList(),
        onChanged: (item) {
          if (item != null) changed(item);
        },
      ),
    ),
  );

  Widget _buildCompactWorkspace() => Stack(
    children: <Widget>[
      Positioned.fill(child: _buildStage()),
      Positioned(
        left: 10,
        bottom: 118,
        child: FloatingActionButton.small(
          heroTag: 'rt_library',
          tooltip: 'Objetos y escena',
          onPressed: () => _showSheet('Objetos y escena', _buildLibrary()),
          child: const Icon(Icons.add_box_outlined),
        ),
      ),
      Positioned(
        right: 10,
        bottom: 118,
        child: FloatingActionButton.small(
          heroTag: 'rt_inspector',
          tooltip: 'Propiedades',
          onPressed: () => _showSheet('Propiedades', _buildInspector()),
          child: const Icon(Icons.tune),
        ),
      ),
    ],
  );

  Future<void> _showSheet(String title, Widget child) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * .72,
          child: Column(
            children: <Widget>[
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Divider(height: 1),
              Expanded(child: child),
            ],
          ),
        ),
      );

  Widget _buildLibrary() => Material(
    color: Colors.white,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        const _PanelTitle(
          step: '1',
          title: 'Objetos',
          subtitle: 'Agrega participantes',
        ),
        const SizedBox(height: 14),
        const _SectionTitle('Participantes'),
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: <Widget>[
            for (final item in const <(String, IconData)>[
              ('automovil', Icons.directions_car),
              ('motocicleta', Icons.two_wheeler),
              ('camioneta', Icons.local_shipping_outlined),
              ('camion', Icons.local_shipping),
              ('bicicleta', Icons.pedal_bike),
              ('peaton', Icons.directions_walk),
            ])
              _libraryButton(
                actorLabel(item.$1),
                item.$2,
                () => _addActor(item.$1),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Puntos técnicos'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: eventLabels.entries
              .map(
                (entry) => Tooltip(
                  message: entry.value,
                  child: OutlinedButton(
                    onPressed: () => _selectPendingEvent(entry.key),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(61, 42),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: Text(
                      entry.key,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Escena'),
        _wideAction(
          Icons.add_road,
          'Añadir calle recta',
          () => _addRoad('straight'),
        ),
        _wideAction(
          Icons.gesture,
          'Añadir calle curva',
          () => _addRoad('curve'),
        ),
        _wideAction(Icons.add, 'Crear cruce editable', _addCrossing),
        _wideAction(Icons.layers_clear_outlined, 'Quitar todas las calles', () {
          _pushHistory();
          setState(() {
            _project.roads.clear();
            if (_selectedKind == 'road') {
              _selectedKind = null;
              _selectedId = null;
            }
          });
          _markDirty();
        }),
        const SizedBox(height: 18),
        const _SectionTitle('Capas visibles'),
        for (final item in const <(String, String)>[
          ('road', 'Geometría vial'),
          ('actors', 'Participantes'),
          ('paths', 'Trayectorias'),
          ('events', 'Puntos técnicos'),
          ('grid', 'Cuadrícula y escala'),
        ])
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            value: _project.layers[item.$1] != false,
            title: Text(item.$2, style: const TextStyle(fontSize: 13)),
            onChanged: (value) {
              setState(() => _project.layers[item.$1] = value ?? true);
              _markDirty();
            },
          ),
      ],
    ),
  );

  Widget _libraryButton(String label, IconData icon, VoidCallback tap) =>
      SizedBox(
        width: 104,
        height: 70,
        child: OutlinedButton(
          onPressed: tap,
          style: OutlinedButton.styleFrom(padding: const EdgeInsets.all(6)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon),
              const SizedBox(height: 3),
              Text(
                label,
                style: const TextStyle(fontSize: 11),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );

  Widget _wideAction(IconData icon, String label, VoidCallback tap) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: OutlinedButton.icon(
      onPressed: tap,
      icon: Icon(icon, size: 18),
      label: Align(alignment: Alignment.centerLeft, child: Text(label)),
      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(40)),
    ),
  );

  Widget _buildStage() => Column(
    children: <Widget>[
      _buildStageToolbar(),
      Expanded(
        child: Container(
          color: const Color(0xFF182735),
          child: InteractiveViewer(
            transformationController: _transformation,
            panEnabled: _tool == _EditorTool.pan,
            scaleEnabled: true,
            minScale: .25,
            maxScale: 4,
            boundaryMargin: const EdgeInsets.all(500),
            constrained: false,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _canvasTap(details.localPosition),
              onPanStart: _tool == _EditorTool.pan
                  ? null
                  : (details) => _dragStart(details.localPosition),
              onPanUpdate: _tool == _EditorTool.pan
                  ? null
                  : (details) => _dragUpdate(details.localPosition),
              onPanEnd: _tool == _EditorTool.pan ? null : (_) => _dragEnd(),
              child: SizedBox.fromSize(
                size: ReconstructorTransitoPainter.canvasSize,
                child: CustomPaint(
                  painter: ReconstructorTransitoPainter(
                    project: _project,
                    currentTime: _currentTime,
                    selectedKind: _selectedKind,
                    selectedId: _selectedId,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      _buildTimeline(),
    ],
  );

  Widget _buildStageToolbar() => Material(
    color: const Color(0xFFEEF3F7),
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: Row(
        children: <Widget>[
          _toolButton(
            _EditorTool.select,
            Icons.near_me_outlined,
            'Seleccionar',
          ),
          _toolButton(_EditorTool.path, Icons.route, 'Trazar ruta'),
          _toolButton(_EditorTool.pan, Icons.pan_tool_outlined, 'Mover vista'),
          const SizedBox(width: 12),
          if (_pendingEvent != null)
            Chip(
              avatar: const Icon(Icons.place_outlined, size: 17),
              label: Text('Coloca $_pendingEvent'),
              onDeleted: () => setState(() => _pendingEvent = null),
            )
          else
            Text(
              _modeHelp(),
              style: const TextStyle(fontSize: 11, color: Color(0xFF526777)),
            ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Deshacer',
            onPressed: _history.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo, size: 20),
          ),
          IconButton(
            tooltip: 'Eliminar selección',
            onPressed: _selectedId == null ? null : _deleteSelection,
            icon: const Icon(Icons.delete_outline, size: 20),
          ),
          IconButton(
            tooltip: 'Ajustar escena',
            onPressed: _fitScene,
            icon: const Icon(Icons.fit_screen, size: 20),
          ),
        ],
      ),
    ),
  );

  Widget _toolButton(_EditorTool tool, IconData icon, String label) => Padding(
    padding: const EdgeInsets.only(right: 5),
    child: ChoiceChip(
      selected: _tool == tool,
      showCheckmark: false,
      avatar: Icon(icon, size: 17),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onSelected: (_) => _setTool(tool),
    ),
  );

  String _modeHelp() => switch (_tool) {
    _EditorTool.select => 'Toca y arrastra objetos para editarlos.',
    _EditorTool.path =>
      'Toca la escena para agregar un fotograma al participante.',
    _EditorTool.pan =>
      'Arrastra para desplazar la vista; pellizca para acercar.',
  };

  Widget _buildTimeline() => Material(
    elevation: 6,
    color: Colors.white,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: _playbackControls()),
                    ),
                    Row(children: _timelineSlider()),
                  ],
                )
              : Row(
                  children: <Widget>[
                    ..._playbackControls(),
                    ..._timelineSlider(),
                  ],
                ),
        );
      },
    ),
  );

  List<Widget> _playbackControls() => <Widget>[
    IconButton(
      onPressed: () => _setCurrentTime(0),
      icon: const Icon(Icons.skip_previous),
      tooltip: 'Inicio',
    ),
    IconButton(
      onPressed: () => _setCurrentTime(_currentTime - 1 / 30),
      icon: const Icon(Icons.fast_rewind),
      tooltip: 'Cuadro anterior',
    ),
    FilledButton.tonalIcon(
      onPressed: _play,
      icon: Icon(_playback.isAnimating ? Icons.pause : Icons.play_arrow),
      label: Text(_playback.isAnimating ? 'Pausa' : 'Reproducir'),
    ),
    IconButton(
      onPressed: () => _setCurrentTime(_currentTime + 1 / 30),
      icon: const Icon(Icons.fast_forward),
      tooltip: 'Cuadro siguiente',
    ),
    DropdownButton<double>(
      value: _playbackRate,
      items: const <DropdownMenuItem<double>>[
        DropdownMenuItem(value: .25, child: Text('0.25×')),
        DropdownMenuItem(value: .5, child: Text('0.5×')),
        DropdownMenuItem(value: 1, child: Text('1×')),
        DropdownMenuItem(value: 2, child: Text('2×')),
      ],
      onChanged: (value) {
        if (value != null) setState(() => _playbackRate = value);
      },
    ),
  ];

  List<Widget> _timelineSlider() => <Widget>[
    Text(
      _clock(_currentTime),
      style: const TextStyle(
        fontFeatures: <ui.FontFeature>[ui.FontFeature.tabularFigures()],
        fontWeight: FontWeight.w700,
      ),
    ),
    Expanded(
      child: Slider(
        min: 0,
        max: _project.metadata.duration,
        value: _currentTime.clamp(0, _project.metadata.duration),
        onChanged: _setCurrentTime,
      ),
    ),
    Text(
      _clock(_project.metadata.duration),
      style: const TextStyle(fontSize: 12),
    ),
  ];

  String _clock(double seconds) {
    final minutes = seconds ~/ 60;
    final remainder = seconds - minutes * 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainder.toStringAsFixed(1).padLeft(4, '0')}';
  }

  Widget _buildInspector() => Material(
    color: Colors.white,
    child: ListView(
      padding: const EdgeInsets.all(12),
      children: <Widget>[
        const _PanelTitle(
          step: '2',
          title: 'Propiedades',
          subtitle: 'Edita la selección',
        ),
        const SizedBox(height: 14),
        if (_selectedActor != null) _actorInspector(_selectedActor!),
        if (_selectedRoad != null) _roadInspector(_selectedRoad!),
        if (_selectedEvent != null) _eventInspector(_selectedEvent!),
        if (_selectedId == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: <Widget>[
                Icon(
                  Icons.touch_app_outlined,
                  size: 42,
                  color: Color(0xFF7890A4),
                ),
                SizedBox(height: 8),
                Text(
                  'Sin selección',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Toca un participante, calle o punto técnico.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        const Divider(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            const _SectionTitle('Participantes'),
            Chip(label: Text('${_project.actors.length}')),
          ],
        ),
        for (final actor in _project.actors)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: Color(actor.color),
              child: Icon(
                _actorIcon(actor.type),
                size: 15,
                color: Colors.white,
              ),
            ),
            title: Text(
              actor.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${actor.keyframes.length} fotogramas · ${actor.speedKmh.toStringAsFixed(0)} km/h',
            ),
            selected: _selectedId == actor.id,
            onTap: () => setState(() {
              _selectedKind = 'actor';
              _selectedId = actor.id;
            }),
          ),
        const Divider(height: 28),
        _summaryRow(
          'Distancia seleccionada',
          _selectedActor == null
              ? '—'
              : '${_actorDistance(_selectedActor!).toStringAsFixed(1)} m',
        ),
        _summaryRow(
          'Fotogramas',
          '${_project.actors.fold<int>(0, (sum, item) => sum + item.keyframes.length)}',
        ),
        _summaryRow('Puntos técnicos', '${_project.events.length}'),
      ],
    ),
  );

  Widget _actorInspector(ReconstructorActor actor) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: Color(actor.color),
          child: Icon(_actorIcon(actor.type), color: Colors.white),
        ),
        title: Text(
          actor.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Participante seleccionado'),
      ),
      _editText('Nombre', actor.name, (value) {
        actor.name = value.trim().isEmpty
            ? actorLabel(actor.type)
            : value.trim();
        _markDirty();
      }),
      const SizedBox(height: 9),
      _editNumber('Velocidad inicial (km/h)', actor.speedKmh, 0, 300, (value) {
        actor.speedKmh = value;
        _markDirty();
      }),
      const SizedBox(height: 9),
      _editNumber(
        'Orientación actual (°)',
        actor.positionAt(_currentTime)?.rotation ?? 0,
        -180,
        180,
        (value) {
          final position = actor.positionAt(_currentTime);
          if (position == null) return;
          _pushHistory();
          actor.upsert(
            _currentTime,
            position.x,
            position.y,
            rotation: value,
            manualRotation: true,
          );
          setState(() {});
          _markDirty();
        },
      ),
      const SizedBox(height: 9),
      FilledButton.tonalIcon(
        onPressed: () => _setTool(_EditorTool.path),
        icon: const Icon(Icons.route),
        label: const Text('Trazar trayectoria'),
      ),
      TextButton.icon(
        onPressed: () {
          final position =
              actor.positionAt(_currentTime) ??
              ReconstructorKeyframe(time: _currentTime, x: 600, y: 350);
          _pushHistory();
          actor.upsert(
            _currentTime,
            position.x,
            position.y,
            rotation: position.rotation,
          );
          setState(() {});
          _markDirty();
        },
        icon: const Icon(Icons.add),
        label: const Text('Fotograma en tiempo actual'),
      ),
      const _SectionTitle('Fotogramas clave'),
      for (final frame in actor.keyframes)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.key, size: 18),
          title: Text('${frame.time.toStringAsFixed(2)} s'),
          subtitle: Text(
            'x ${frame.x.toStringAsFixed(0)} · y ${frame.y.toStringAsFixed(0)} · ${frame.rotation.toStringAsFixed(0)}°',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: actor.keyframes.length <= 1
                ? null
                : () {
                    _pushHistory();
                    setState(() => actor.keyframes.remove(frame));
                    _markDirty();
                  },
          ),
          onTap: () => _setCurrentTime(frame.time),
        ),
    ],
  );

  Widget _roadInspector(ReconstructorRoad road) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(child: Icon(Icons.add_road)),
        title: Text(
          road.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(road.type == 'curve' ? 'Calle curva' : 'Calle recta'),
      ),
      _editText('Nombre', road.name, (value) {
        road.name = value.trim().isEmpty ? 'Calle' : value.trim();
        _markDirty();
      }),
      const SizedBox(height: 9),
      _dropdown(
        'Superficie',
        road.surface,
        const <String, String>{
          'asphalt': 'Asfalto',
          'concrete': 'Concreto hidráulico',
          'pavers': 'Adoquín',
          'cobblestone': 'Empedrado',
          'dirt': 'Terracería',
          'gravel': 'Grava',
          'natural': 'Brecha / suelo natural',
        },
        (value) {
          setState(() => road.surface = value);
          _markDirty();
        },
      ),
      const SizedBox(height: 9),
      Row(
        children: <Widget>[
          const Expanded(
            child: Text(
              'Carriles',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            onPressed: road.lanes <= (road.direction == 'two_way' ? 2 : 1)
                ? null
                : () {
                    _pushHistory();
                    setState(
                      () => road.lanes -= road.direction == 'two_way' ? 2 : 1,
                    );
                    _markDirty();
                  },
            icon: const Icon(Icons.remove_circle_outline),
          ),
          Text(
            '${road.lanes}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            onPressed: road.lanes >= 12
                ? null
                : () {
                    _pushHistory();
                    setState(
                      () => road.lanes += road.direction == 'two_way' ? 2 : 1,
                    );
                    _markDirty();
                  },
            icon: const Icon(Icons.add_circle_outline),
          ),
        ],
      ),
      _dropdown(
        'Circulación',
        road.direction,
        const <String, String>{
          'one_way': 'Un solo sentido',
          'two_way': 'Doble sentido',
        },
        (value) {
          setState(() {
            road.direction = value;
            if (value == 'two_way' && road.lanes.isOdd) road.lanes++;
          });
          _markDirty();
        },
      ),
      if (road.direction == 'two_way') ...<Widget>[
        const SizedBox(height: 9),
        _dropdown(
          'División central',
          road.centerLine,
          const <String, String>{
            'solid': 'Amarilla continua',
            'dashed': 'Amarilla discontinua',
            'double_solid': 'Doble amarilla',
          },
          (value) {
            setState(() => road.centerLine = value);
            _markDirty();
          },
        ),
      ],
      const SizedBox(height: 9),
      if (road.type == 'straight') ...<Widget>[
        _editNumber('Longitud (m)', road.lengthMeters, 3, 200, (value) {
          road.lengthMeters = value;
          _markDirty();
        }),
        const SizedBox(height: 9),
      ],
      _editNumber('Ancho de carril (m)', road.laneWidthMeters, 2, 8, (value) {
        road.laneWidthMeters = value;
        _markDirty();
      }),
      const SizedBox(height: 9),
      _editNumber('Orientación (°)', road.rotation, -180, 180, (value) {
        road.rotation = value;
        setState(() {});
        _markDirty();
      }),
      const SizedBox(height: 9),
      _dropdown(
        'Costado izquierdo',
        road.leftEdge,
        const <String, String>{
          'none': 'Sin elemento',
          'sidewalk': 'Banqueta',
          'median': 'Camellón',
        },
        (value) {
          setState(() => road.leftEdge = value);
          _markDirty();
        },
      ),
      const SizedBox(height: 9),
      _dropdown(
        'Costado derecho',
        road.rightEdge,
        const <String, String>{
          'none': 'Sin elemento',
          'sidewalk': 'Banqueta',
          'median': 'Camellón',
        },
        (value) {
          setState(() => road.rightEdge = value);
          _markDirty();
        },
      ),
      if (road.type == 'curve') ...<Widget>[
        const SizedBox(height: 10),
        const Text(
          'Arrastra los cuatro nodos: extremos morados y controles verdes.',
          style: TextStyle(fontSize: 12, color: Color(0xFF526777)),
        ),
        TextButton.icon(
          onPressed: () {
            _pushHistory();
            setState(() => road.curve = ReconstructorCurve());
            _markDirty();
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restablecer curva'),
        ),
      ],
    ],
  );

  Widget _eventInspector(ReconstructorEvent event) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Text(
            event.code,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(
          eventLabels[event.code]!,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: const Text('Punto técnico seleccionado'),
      ),
      _editNumber('Momento (s)', event.time, 0, _project.metadata.duration, (
        value,
      ) {
        event.time = value;
        _setCurrentTime(value);
        _markDirty();
      }),
      const SizedBox(height: 9),
      _editText('Descripción', event.description, (value) {
        event.description = value.trim();
        _markDirty();
      }, maxLines: 3),
    ],
  );

  Widget _editText(
    String label,
    String initial,
    ValueChanged<String> changed, {
    int maxLines = 1,
  }) {
    return TextFormField(
      key: ValueKey('$label-$_selectedId-$initial'),
      initialValue: initial,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onChanged: (value) {
        changed(value);
        setState(() {});
      },
    );
  }

  Widget _editNumber(
    String label,
    double initial,
    double min,
    double max,
    ValueChanged<double> changed,
  ) {
    return TextFormField(
      key: ValueKey('$label-$_selectedId-${initial.toStringAsFixed(2)}'),
      initialValue: initial.toStringAsFixed(
        initial == initial.roundToDouble() ? 0 : 1,
      ),
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      onFieldSubmitted: (value) {
        final parsed = double.tryParse(value.replaceAll(',', '.'));
        if (parsed == null) return;
        _pushHistory();
        changed(parsed.clamp(min, max));
        setState(() {});
      },
    );
  }

  Widget _dropdown(
    String label,
    String value,
    Map<String, String> options,
    ValueChanged<String> changed,
  ) => DropdownButtonFormField<String>(
    value: options.containsKey(value) ? value : options.keys.first,
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
    items: options.entries
        .map(
          (entry) => DropdownMenuItem(
            value: entry.key,
            child: Text(entry.value, overflow: TextOverflow.ellipsis),
          ),
        )
        .toList(),
    onChanged: (item) {
      if (item == null) return;
      _pushHistory();
      changed(item);
    },
  );

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(label, style: const TextStyle(fontSize: 12)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    ),
  );

  double _actorDistance(ReconstructorActor actor) {
    var pixels = 0.0;
    final frames = [...actor.keyframes]
      ..sort((a, b) => a.time.compareTo(b.time));
    for (var index = 0; index < frames.length - 1; index++) {
      pixels +=
          (Offset(frames[index].x, frames[index].y) -
                  Offset(frames[index + 1].x, frames[index + 1].y))
              .distance;
    }
    return pixels / _project.metadata.pixelsPerMeter;
  }

  IconData _actorIcon(String type) => switch (type) {
    'motocicleta' => Icons.two_wheeler,
    'bicicleta' => Icons.pedal_bike,
    'peaton' => Icons.directions_walk,
    'camion' || 'camioneta' => Icons.local_shipping,
    _ => Icons.directions_car,
  };
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle({
    required this.step,
    required this.title,
    required this.subtitle,
  });
  final String step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Row(
    children: <Widget>[
      CircleAvatar(
        radius: 14,
        child: Text(
          step,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF66798A)),
            ),
          ],
        ),
      ),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.value);
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      value.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
        color: Color(0xFF526777),
      ),
    ),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
