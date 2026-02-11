import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/auth_service.dart';

class LesionadosScreen extends StatefulWidget {
  const LesionadosScreen({super.key});

  @override
  State<LesionadosScreen> createState() => _LesionadosScreenState();
}

class _LesionadosScreenState extends State<LesionadosScreen> {
  bool _cargando = true;
  String? _error;

  List<Map<String, dynamic>> _lesionados = <Map<String, dynamic>>[];

  // Usa tu base real (mejor que esté en AuthService, pero lo dejo como lo traías)
  static const String _baseUrl = 'https://seguridadvial-mich.com/api';

  final TextEditingController _qCtrl = TextEditingController();
  String? _estado; // UI solamente por ahora

  int _hechoIdFromArgs(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['hechoId'] != null) {
      return int.tryParse(args['hechoId'].toString()) ?? 0;
    }
    return 0;
  }

  @override
  void initState() {
    super.initState();
    // Ojo: aquí NO podemos leer ModalRoute todavía seguro.
    // Cargamos en el primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Uri _buildUri(int hechoId) {
    // ✅ Tu API real: GET /api/hechos/{hecho}/lesionados
    return Uri.parse('$_baseUrl/hechos/$hechoId/lesionados');
  }

  Future<void> _cargar() async {
    final hechoId = _hechoIdFromArgs(context);

    if (hechoId <= 0) {
      setState(() {
        _cargando = false;
        _error = 'No llegó hechoId a LesionadosScreen.';
      });
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final uri = _buildUri(hechoId);
      final res = await http.get(uri, headers: await _headers());

      if (res.statusCode != 200) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      final decoded = jsonDecode(res.body);
      final list = (decoded is Map && decoded['data'] is List)
          ? decoded['data']
          : (decoded is List)
          ? decoded
          : <dynamic>[];

      final items = <Map<String, dynamic>>[];
      for (final e in list) {
        if (e is Map<String, dynamic>) items.add(e);
      }

      if (!mounted) return;
      setState(() {
        _lesionados = items;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  Future<void> _confirmEliminar(int lesionadoId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar lesionado'),
        content: const Text('¿Seguro que deseas eliminar este registro?'),
        actions: [
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
    await _eliminar(lesionadoId);
  }

  Future<void> _eliminar(int lesionadoId) async {
    final hechoId = _hechoIdFromArgs(context);
    if (hechoId <= 0) return;

    try {
      // ✅ Tu API real: DELETE /api/hechos/{hecho}/lesionados/{lesionado}
      final uri = Uri.parse(
        '$_baseUrl/hechos/$hechoId/lesionados/$lesionadoId',
      );
      final res = await http.delete(uri, headers: await _headers());

      if (res.statusCode != 200 && res.statusCode != 204) {
        throw Exception('Error ${res.statusCode}: ${res.body}');
      }

      if (!mounted) return;
      setState(() {
        _lesionados.removeWhere((x) => (x['id'] ?? 0) == lesionadoId);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Eliminado correctamente')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo eliminar: $e')));
    }
  }

  void _irCrear() {
    final hechoId = _hechoIdFromArgs(context);
    Navigator.pushNamed(
      context,
      '/lesionados/create',
      arguments: {'hechoId': hechoId},
    ).then((_) => _cargar());
  }

  void _irEditar(Map<String, dynamic> item) {
    final hechoId = _hechoIdFromArgs(context);
    Navigator.pushNamed(
      context,
      '/lesionados/edit',
      arguments: {'hechoId': hechoId, 'item': item},
    ).then((_) => _cargar());
  }

  void _irDetalle(Map<String, dynamic> item) {
    final hechoId = _hechoIdFromArgs(context);
    Navigator.pushNamed(
      context,
      '/lesionados/show',
      arguments: {'hechoId': hechoId, 'item': item},
    );
  }

  @override
  Widget build(BuildContext context) {
    final hechoId = _hechoIdFromArgs(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text('Lesionados (Hecho #$hechoId)'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _irCrear,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          children: [_buildFiltros(), const SizedBox(height: 10), _buildBody()],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filtros',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _qCtrl,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _cargar(),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Buscar (UI) - todavía no filtra en backend',
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _estado,
                  isExpanded: true,
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Estado (UI)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todos')),
                    DropdownMenuItem(value: 'ACTIVO', child: Text('ACTIVO')),
                    DropdownMenuItem(
                      value: 'INACTIVO',
                      child: Text('INACTIVO'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _estado = v),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: _cargar,
                icon: const Icon(Icons.filter_alt),
                label: const Text('Aplicar'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.only(top: 22),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withOpacity(.2)),
        ),
        child: Text('Error:\n$_error'),
      );
    }

    if (_lesionados.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 22),
        child: Center(child: Text('Sin lesionados para este hecho.')),
      );
    }

    return Column(
      children: _lesionados
          .map(
            (it) => _LesionadoCard(
              item: it,
              onTap: () => _irDetalle(it),
              onEdit: () => _irEditar(it),
              onDelete: () =>
                  _confirmEliminar(int.tryParse('${it['id'] ?? 0}') ?? 0),
            ),
          )
          .toList(),
    );
  }
}

class _LesionadoCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LesionadoCard({
    required this.item,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${item['id'] ?? 0}') ?? 0;
    final nombre = (item['nombre'] ?? 'Sin nombre').toString();

    final edad = item['edad'];
    final sexo = item['sexo'];
    final tipoLesion = item['tipo_lesion'];
    final hospitalizado = item['hospitalizado'];
    final createdAt = item['created_at'];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.personal_injury),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.blue.withOpacity(.25)),
                    ),
                    child: Text(
                      'ID $id',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (tipoLesion != null) _chip('Lesión: $tipoLesion'),
                  if (edad != null) _chip('Edad: $edad'),
                  if (sexo != null) _chip('Sexo: $sexo'),
                  if (hospitalizado != null) _chip('Hosp: $hospitalizado'),
                  if (createdAt != null) _chip('$createdAt'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar'),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete, color: Colors.red),
                    label: const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _chip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }
}
