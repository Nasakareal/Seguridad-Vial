import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/calea.dart';
import '../../services/auth_service.dart';
import '../../services/calea_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';

class CaleaScreen extends StatefulWidget {
  const CaleaScreen({super.key});

  @override
  State<CaleaScreen> createState() => _CaleaScreenState();
}

class _CaleaScreenState extends State<CaleaScreen> {
  static const _navy = Color(0xFF102A43);
  static const _gold = Color(0xFFC59D2A);
  final _searchController = TextEditingController();
  Timer? _debounce;
  CaleaMeta _meta = const CaleaMeta.empty();
  List<CaleaDirectiva> _directivas = const [];
  List<CaleaEstudioGrupo> _grupos = const [];
  String _categoria = '';
  String _query = '';
  bool _studyMode = false;
  bool _loading = true;
  bool _loggingOut = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _load(refreshMeta: true),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refreshMeta = false}) async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (refreshMeta || _meta.categorias.isEmpty) {
        _meta = await CaleaService.meta();
      }
      if (_studyMode) {
        _grupos = await CaleaService.estudio(categoria: _categoria);
      } else if (_query.isNotEmpty) {
        _directivas = await CaleaService.buscar(
          texto: _query,
          categoria: _categoria,
        );
      } else {
        _directivas = await CaleaService.index(categoria: _categoria);
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = CaleaService.cleanError(error);
      });
    }
  }

  void _scheduleSearch(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 550), () {
      final next = value.trim();
      if (next == _query || _studyMode) return;
      _query = next;
      _load();
    });
  }

  void _submitSearch() {
    _debounce?.cancel();
    final next = _searchController.text.trim();
    if (_studyMode) setState(() => _studyMode = false);
    _query = next;
    _load();
  }

  void _setMode(bool study) {
    if (_studyMode == study) return;
    setState(() => _studyMode = study);
    _load();
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    _query = '';
    _load();
  }

  Future<void> _open(CaleaDirectiva directiva) async {
    await Navigator.pushNamed(
      context,
      AppRoutes.caleaDetalle,
      arguments: {'directiva_id': directiva.id, 'search_query': _query},
    );
  }

  Future<void> _logout(BuildContext context) async {
    if (_loggingOut) return;
    _loggingOut = true;
    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
      await AuthService.logout();
    } finally {
      _loggingOut = false;
    }
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGuard(
      permission: 'ver calea',
      message:
          'Necesitas el permiso “ver calea” para consultar las directivas.',
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: const Text('Biblioteca CALEA'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : () => _load(refreshMeta: true),
              icon: const Icon(Icons.refresh),
            ),
            const AccountMenuAction(),
          ],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: RefreshIndicator(
          onRefresh: () => _load(refreshMeta: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _hero()),
              SliverToBoxAdapter(child: _controls()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _StateMessage(
                    icon: Icons.cloud_off_outlined,
                    title: 'No pudimos abrir la biblioteca',
                    message: _error!,
                    action: 'Reintentar',
                    onPressed: _load,
                  ),
                )
              else if (_studyMode)
                _studyList()
              else
                _libraryList(),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      decoration: const BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 26),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF173F5F), Color(0xFF245B78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: .12)),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _gold.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.policy_outlined,
                color: Color(0xFFFFD76A),
                size: 31,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Directivas a tu alcance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_meta.totalDirectivas} documentos vigentes · ${_meta.categorias.length} categorías',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: Column(
        children: [
          SegmentedButton<bool>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.library_books_outlined),
                label: Text('Biblioteca'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.school_outlined),
                label: Text('Modo estudio'),
              ),
            ],
            selected: {_studyMode},
            onSelectionChanged: (values) => _setMode(values.first),
          ),
          const SizedBox(height: 13),
          if (!_studyMode)
            TextField(
              controller: _searchController,
              onChanged: _scheduleSearch,
              onSubmitted: (_) => _submitSearch(),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                hintText: 'Buscar una palabra, tema, código o área…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? IconButton(
                        onPressed: _submitSearch,
                        icon: const Icon(Icons.arrow_forward),
                      )
                    : IconButton(
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          if (!_studyMode) const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _meta.categorias.contains(_categoria) ? _categoria : '',
            isExpanded: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              labelText: 'Categoría',
              prefixIcon: const Icon(Icons.category_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Todas las categorías'),
              ),
              ..._meta.categorias.map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value, overflow: TextOverflow.ellipsis),
                ),
              ),
            ],
            onChanged: (value) {
              _categoria = value ?? '';
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _libraryList() {
    if (_directivas.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.search_off,
          title: 'Sin coincidencias',
          message: _query.isEmpty
              ? 'No hay directivas publicadas en esta categoría.'
              : 'Prueba con otra palabra o quita el filtro de categoría.',
          action: 'Limpiar búsqueda',
          onPressed: _clearSearch,
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: _directivas.length,
        itemBuilder: (_, index) => _DirectivaCard(
          directiva: _directivas[index],
          query: _query,
          onTap: () => _open(_directivas[index]),
        ),
      ),
    );
  }

  Widget _studyList() {
    if (_grupos.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: _StateMessage(
          icon: Icons.menu_book_outlined,
          title: 'Sin material de estudio',
          message: 'No hay directivas publicadas en esta categoría.',
          action: 'Ver todas',
          onPressed: () {
            _categoria = '';
            _load();
          },
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList.builder(
        itemCount: _grupos.length,
        itemBuilder: (_, index) {
          final group = _grupos[index];
          return _StudyGroup(group: group, onOpen: _open);
        },
      ),
    );
  }
}

class _DirectivaCard extends StatelessWidget {
  final CaleaDirectiva directiva;
  final String query;
  final VoidCallback onTap;

  const _DirectivaCard({
    required this.directiva,
    required this.query,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final version = directiva.version;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF4D1),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      directiva.codigo.isEmpty ? 'CALEA' : directiva.codigo,
                      style: const TextStyle(
                        color: Color(0xFF7A5A00),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      directiva.titulo,
                      style: const TextStyle(
                        color: Color(0xFF102A43),
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.blueGrey),
                ],
              ),
              if (directiva.descripcion.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  directiva.descripcion,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.blueGrey.shade700,
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  if (directiva.categoria.isNotEmpty)
                    _Pill(
                      icon: Icons.folder_outlined,
                      label: directiva.categoria,
                    ),
                  if ((version?.numeroVersion ?? '').isNotEmpty)
                    _Pill(
                      icon: Icons.history,
                      label: 'Versión ${version!.numeroVersion}',
                    ),
                  if (version?.pdfDisponible == true)
                    const _Pill(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'PDF',
                    ),
                ],
              ),
              if (query.isNotEmpty && directiva.coincidencias.isNotEmpty) ...[
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(
                      Icons.manage_search,
                      size: 18,
                      color: Color(0xFF245B78),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${directiva.coincidencias.length} ${directiva.coincidencias.length == 1 ? 'coincidencia' : 'coincidencias'}',
                      style: const TextStyle(
                        color: Color(0xFF245B78),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...directiva.coincidencias
                    .take(2)
                    .map(
                      (hit) => Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Text(
                          hit.contenido.isNotEmpty ? hit.contenido : hit.titulo,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, height: 1.35),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyGroup extends StatelessWidget {
  final CaleaEstudioGrupo group;
  final Future<void> Function(CaleaDirectiva) onOpen;

  const _StudyGroup({required this.group, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 13),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        backgroundColor: Colors.white,
        collapsedBackgroundColor: Colors.white,
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFE5F0F5),
          child: Icon(Icons.school_outlined, color: Color(0xFF245B78)),
        ),
        title: Text(
          group.categoria,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          '${group.directivas.length} ${group.directivas.length == 1 ? 'directiva' : 'directivas'}',
        ),
        children: group.directivas
            .map((directiva) {
              final sections = directiva.version?.secciones.length ?? 0;
              return ListTile(
                contentPadding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
                leading: Container(
                  width: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF4D1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    directiva.codigo.isEmpty ? '•' : directiva.codigo,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF7A5A00),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  directiva.titulo,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text('$sections secciones para estudiar'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 15),
                onTap: () => onOpen(directiva),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(
      maxWidth: MediaQuery.sizeOf(context).width - 60,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFEAF2F6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF245B78)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF245B78),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String action;
  final VoidCallback onPressed;
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    required this.action,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 46, color: Colors.blueGrey),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF102A43),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade700, height: 1.4),
          ),
          const SizedBox(height: 15),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.refresh),
            label: Text(action),
          ),
        ],
      ),
    ),
  );
}
