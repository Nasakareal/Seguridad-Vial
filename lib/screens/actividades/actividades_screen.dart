import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/app_version_service.dart';
import '../../services/actividades_service.dart';

import '../../models/actividad.dart';
import '../../models/actividad_categoria.dart';
import '../../models/actividad_subcategoria.dart';

import '../../widgets/app_drawer.dart';
import '../../widgets/header_card.dart';

import '../login_screen.dart';
import '../../main.dart' show AppRoutes;

class ActividadesScreen extends StatefulWidget {
  const ActividadesScreen({super.key});

  @override
  State<ActividadesScreen> createState() => _ActividadesScreenState();
}

class _ActividadesScreenState extends State<ActividadesScreen>
    with WidgetsBindingObserver {
  bool _trackingOn = false;
  bool _bootstrapped = false;
  bool _busy = false;

  DateTime _selectedDate = DateTime.now();

  bool _loading = true;
  String? _error;
  List<Actividad> _items = [];

  List<ActividadCategoria> _categorias = [];
  List<ActividadSubcategoria> _subcategorias = [];

  int? _categoriaId;
  int? _subcategoriaId;

  final TextEditingController _qCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await AppVersionService.enforceUpdateIfNeeded(context);
      await _bootstrapTrackingStatusOnly();
      await _loadCatalogos();
      await _load();
    });
  }

  Future<void> _bootstrapTrackingStatusOnly() async {
    if (_bootstrapped) return;
    _bootstrapped = true;

    final running = await FlutterForegroundTask.isRunningService;
    if (!mounted) return;
    setState(() => _trackingOn = running);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      final running = await FlutterForegroundTask.isRunningService;
      if (!mounted) return;
      setState(() => _trackingOn = running);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      await TrackingService.stop();
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

  void _go(BuildContext context, String route, {Object? args}) {
    Navigator.pushNamed(context, route, arguments: args);
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  String _fmtDmY(DateTime d) {
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
    );

    if (picked == null) return;

    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
    });

    await _load();
  }

  Future<void> _loadCatalogos() async {
    try {
      final cats = await ActividadesService.fetchCategorias();
      if (!mounted) return;
      setState(() => _categorias = cats);
    } catch (_) {
      // Si todavía no tienes endpoint de categorías, no truena la app.
      if (!mounted) return;
      setState(() => _categorias = const []);
    }
  }

  Future<void> _loadSubcategorias(int categoriaId) async {
    setState(() {
      _subcategorias = [];
      _subcategoriaId = null;
    });

    try {
      final subs = await ActividadesService.fetchSubcategorias(categoriaId);
      if (!mounted) return;
      setState(() => _subcategorias = subs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _subcategorias = const [];
        _subcategoriaId = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudieron cargar subcategorías.\n$e')),
      );
    }
  }

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await ActividadesService.fetchIndex(
        date: _selectedDate,
        perPage: 50,
        actividadCategoriaId: _categoriaId,
        actividadSubcategoriaId: _subcategoriaId,
        q: _qCtrl.text,
      );

      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [];
        _loading = false;
        _error = 'No se pudieron obtener las actividades.\n$e';
      });
    }
  }

  Future<void> _confirmDelete(Actividad a) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text('¿Eliminar la actividad #${a.id}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ActividadesService.destroy(a.id);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Actividad eliminada.')));
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Error'),
          content: Text('No se pudo eliminar.\n\n$e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  Widget _filtersBar() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mostrando: ${_fmtYmd(_selectedDate)}',
                style: TextStyle(
                  color: Colors.blue.shade900,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _fmtDmY(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _qCtrl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre…',
            prefixIcon: const Icon(Icons.search),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _categoriaId,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Categoría (todas)'),
                  ),
                  ..._categorias.map(
                    (c) => DropdownMenuItem<int>(
                      value: c.id,
                      child: Text(c.nombre),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  setState(() {
                    _categoriaId = v;
                    _subcategoriaId = null;
                    _subcategorias = [];
                  });

                  if (v != null) {
                    await _loadSubcategorias(v);
                  }

                  await _load();
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<int>(
                value: _subcategoriaId,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Subcategoría (todas)'),
                  ),
                  ..._subcategorias.map(
                    (s) => DropdownMenuItem<int>(
                      value: s.id,
                      child: Text(s.nombre),
                    ),
                  ),
                ],
                onChanged: (v) async {
                  setState(() => _subcategoriaId = v);
                  await _load();
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _thumb(Actividad a) {
    final p = (a.fotoPath ?? '').trim();
    if (p.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Icon(Icons.image_not_supported, color: Colors.grey.shade500),
      );
    }

    final url = ActividadesService.toPublicUrl(p);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: 58,
        height: 58,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 58,
          height: 58,
          color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Container(
            width: 58,
            height: 58,
            color: Colors.grey.shade200,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Actividades'),
        actions: [
          IconButton(
            tooltip: 'Buscar hechos',
            icon: const Icon(Icons.search),
            onPressed: () => _go(context, AppRoutes.hechosBuscar),
          ),
        ],
      ),
      drawer: AppDrawer(
        trackingOn: _trackingOn,
        onLogout: () => _logout(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _bootstrapTrackingStatusOnly();
            await _load();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (_trackingOn) HeaderCard(trackingOn: _trackingOn),
              if (_trackingOn) const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.blue.withOpacity(.06),
                  border: Border.all(color: Colors.blue.withOpacity(.18)),
                ),
                child: _filtersBar(),
              ),

              const SizedBox(height: 12),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(child: Text(_error!)),
                )
              else if (_items.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text('No hay actividades para este filtro.'),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final a = _items[i];
                    final cat = a.categoria?.nombre ?? '—';
                    final sub = a.subcategoria?.nombre;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ListTile(
                        leading: _thumb(a),
                        title: Text('#${a.id} • $cat'),
                        subtitle: Text(
                          sub == null || sub.trim().isEmpty
                              ? a.nombre
                              : '${a.nombre} • $sub',
                        ),
                        onTap: () => _go(
                          context,
                          AppRoutes.actividadesShow,
                          args: {'actividad_id': a.id},
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'show') {
                              _go(
                                context,
                                AppRoutes.actividadesShow,
                                args: {'actividad_id': a.id},
                              );
                            } else if (v == 'edit') {
                              _go(
                                context,
                                AppRoutes.actividadesEdit,
                                args: {'actividad_id': a.id},
                              );
                            } else if (v == 'delete') {
                              _confirmDelete(a);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'show', child: Text('Ver')),
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _go(context, AppRoutes.actividadesCreate),
        tooltip: 'Crear actividad',
        child: const Icon(Icons.add),
      ),
    );
  }
}
