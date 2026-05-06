import 'dart:async';

import 'package:flutter/material.dart';

import '../../../models/hecho_form_data.dart';
import '../../../models/puesta_disposicion_item.dart';
import '../../../services/auth_service.dart';
import '../../../services/puestas_disposicion_service.dart';

class PuestaDisposicionSelector extends StatefulWidget {
  final HechoFormData data;
  final bool disabled;
  final ValueChanged<PuestaDisposicionItem?> onSelected;
  final Future<void> Function()? onCreatePuesta;

  const PuestaDisposicionSelector({
    super.key,
    required this.data,
    required this.disabled,
    required this.onSelected,
    this.onCreatePuesta,
  });

  @override
  State<PuestaDisposicionSelector> createState() =>
      _PuestaDisposicionSelectorState();
}

class _PuestaDisposicionSelectorState extends State<PuestaDisposicionSelector> {
  final _service = PuestasDisposicionService();

  bool _loading = false;
  List<PuestaDisposicionItem> _items = const [];
  PuestaDisposicionItem? _selected;
  late bool _lastIsTurnado;
  int? _lastPuestaId;
  int? _delegacionScopeId;
  bool _missingDelegacionScope = false;

  bool get _isTurnado =>
      (widget.data.situacion ?? '').trim().toUpperCase() == 'TURNADO';

  @override
  void initState() {
    super.initState();
    _lastIsTurnado = _isTurnado;
    _lastPuestaId = widget.data.puestaDisposicionId;
    if (_isTurnado && widget.data.puestaDisposicionId != null) {
      unawaited(_load());
    }
  }

  @override
  void didUpdateWidget(covariant PuestaDisposicionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    final wasTurnado = _lastIsTurnado;
    final previousPuestaId = _lastPuestaId;
    final currentPuestaId = widget.data.puestaDisposicionId;
    _lastIsTurnado = _isTurnado;
    _lastPuestaId = currentPuestaId;

    if (!_isTurnado) {
      _items = const [];
      _selected = null;
      widget.data.puestaDisposicionId = null;
      _lastPuestaId = null;
      widget.onSelected(null);
      return;
    }

    final selectedChanged = previousPuestaId != currentPuestaId;
    if ((!wasTurnado || selectedChanged) && !_loading) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final rawItems = await _service.index(anio: DateTime.now().year);
      final mapped = rawItems
          .map(PuestaDisposicionItem.fromMap)
          .where((item) => item.id > 0)
          .toList();

      final delegacionId = await _resolveDelegacionId();
      final items = _filterOwnDelegacion(mapped, delegacionId);
      final selectedId = widget.data.puestaDisposicionId;
      var filteredItems = items;
      if (delegacionId != null &&
          selectedId != null &&
          !filteredItems.any((item) => item.id == selectedId)) {
        final selected = await _fetchSelected(selectedId);
        if (selected != null &&
            _belongsToCurrentDelegacion(selected, delegacionId)) {
          filteredItems = <PuestaDisposicionItem>[selected, ...filteredItems];
        }
      }

      PuestaDisposicionItem? selected;
      if (selectedId != null) {
        final matches = filteredItems
            .where((item) => item.id == selectedId)
            .toList();
        selected = matches.isEmpty ? null : matches.first;
      }

      if (!mounted) return;
      setState(() {
        _delegacionScopeId = delegacionId;
        _missingDelegacionScope = delegacionId == null;
        _items = filteredItems;
        _selected = selected;
        if (selected == null && selectedId != null) {
          widget.data.puestaDisposicionId = null;
          _lastPuestaId = null;
        }
      });
      widget.onSelected(_selected);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = const [];
        _selected = null;
      });
      widget.onSelected(null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar puestas: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<PuestaDisposicionItem> _filterOwnDelegacion(
    List<PuestaDisposicionItem> items,
    int? delegacionId,
  ) {
    if (delegacionId == null) return const <PuestaDisposicionItem>[];

    final currentHechoId = widget.data.hechoId;
    final selectedId = widget.data.puestaDisposicionId;

    return items.where((item) {
      if (!_belongsToCurrentDelegacion(item, delegacionId)) return false;

      final linkedHechoId = item.hechoId;
      if (linkedHechoId != null &&
          linkedHechoId > 0 &&
          linkedHechoId != currentHechoId &&
          item.id != selectedId) {
        return false;
      }

      return true;
    }).toList();
  }

  bool _belongsToCurrentDelegacion(
    PuestaDisposicionItem item,
    int delegacionId,
  ) {
    if (item.delegacionId != delegacionId) return false;

    final unidadId = item.unidadId;
    if (unidadId != null && unidadId != AuthService.unidadDelegacionesId) {
      return false;
    }

    return true;
  }

  Future<int?> _resolveDelegacionId() async {
    final stored = await AuthService.getDelegacionId();
    if (stored != null && stored > 0) return stored;

    await AuthService.refreshCurrentUserAccess();
    final refreshed = await AuthService.getDelegacionId();
    if (refreshed != null && refreshed > 0) return refreshed;

    final payload = await AuthService.getCurrentUserPayload(refresh: false);
    return _readDelegacionId(payload);
  }

  int? _readDelegacionId(Map<String, dynamic>? payload) {
    if (payload == null) return null;

    final direct = _asPositiveInt(payload['delegacion_id']);
    if (direct != null) return direct;

    final nested = payload['delegacion'];
    if (nested is Map) {
      return _asPositiveInt(nested['id'] ?? nested['value']);
    }

    return null;
  }

  int? _asPositiveInt(dynamic value) {
    if (value == null) return null;
    if (value is int && value > 0) return value;
    if (value is num && value > 0) return value.toInt();
    final parsed = int.tryParse(value.toString());
    return parsed != null && parsed > 0 ? parsed : null;
  }

  Future<PuestaDisposicionItem?> _fetchSelected(int id) async {
    try {
      final raw = await _service.show(id);
      final source = raw['data'] is Map
          ? Map<String, dynamic>.from(raw['data'] as Map)
          : raw;
      final item = PuestaDisposicionItem.fromMap(source);
      return item.id > 0 ? item : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _createPuesta() async {
    final callback = widget.onCreatePuesta;
    if (callback == null) return;
    await callback();
    if (!mounted) return;
    await _load();
  }

  void _select(int? id) {
    final selected = id == null
        ? null
        : _items.firstWhere((item) => item.id == id);

    setState(() {
      widget.data.puestaDisposicionId = id;
      _lastPuestaId = id;
      _selected = selected;
    });
    widget.onSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTurnado) return const SizedBox.shrink();

    final itemIds = _items.map((item) => item.id).toSet();
    final value = itemIds.contains(widget.data.puestaDisposicionId)
        ? widget.data.puestaDisposicionId
        : null;

    return Column(
      children: [
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Puesta a disposicion',
                  border: OutlineInputBorder(),
                ),
                value: value,
                items: _items
                    .map(
                      (item) => DropdownMenuItem<int>(
                        value: item.id,
                        child: Text(
                          item.label,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (widget.disabled || _loading) ? null : _select,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: OutlinedButton(
                onPressed: (widget.disabled || _loading) ? null : _load,
                child: _loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
            if (widget.onCreatePuesta != null) ...[
              const SizedBox(width: 10),
              SizedBox(
                height: 56,
                child: OutlinedButton(
                  onPressed: widget.disabled ? null : _createPuesta,
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _helperText(),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }

  String _helperText() {
    if (_loading) return 'Cargando puestas de tu delegacion...';

    if (_missingDelegacionScope) {
      return 'No pude identificar tu delegacion; recarga sesion para evitar mostrar puestas ajenas.';
    }

    final selected = _selected;
    if (selected != null) {
      final detail = selected.detail;
      return detail.isEmpty ? 'Puesta vinculada al hecho.' : detail;
    }

    if (_items.isEmpty) {
      final scope = _delegacionScopeId == null ? '' : ' para tu delegacion';
      return 'No hay puestas disponibles$scope. Registra una nueva puesta vinculada al hecho.';
    }

    return 'Selecciona la puesta de tu delegacion para vincular IPH y uso de fuerza.';
  }
}
