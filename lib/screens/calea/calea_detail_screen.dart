import 'package:flutter/material.dart';

import '../../models/calea.dart';
import '../../services/auth_service.dart';
import '../../services/calea_service.dart';
import '../../services/pdf_document_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';

class CaleaDetailScreen extends StatefulWidget {
  const CaleaDetailScreen({super.key});

  @override
  State<CaleaDetailScreen> createState() => _CaleaDetailScreenState();
}

class _CaleaDetailScreenState extends State<CaleaDetailScreen> {
  static const _navy = Color(0xFF102A43);
  int? _id;
  bool _initialized = false;
  String _query = '';
  CaleaDirectiva? _directiva;
  bool _loading = true;
  bool _pdfBusy = false;
  bool _loggingOut = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _id = int.tryParse(args['directiva_id']?.toString() ?? '');
      _query = args['search_query']?.toString().trim() ?? '';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (_id == null || _id! <= 0) {
      setState(() {
        _loading = false;
        _error = 'No se indicó una directiva válida.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await CaleaService.show(_id!);
      if (!mounted) return;
      setState(() {
        _directiva = item;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = CaleaService.cleanError(error);
      });
    }
  }

  Future<void> _openPdf() async {
    final item = _directiva;
    final version = item?.version;
    if (item == null || version == null || version.pdfUrl.isEmpty || _pdfBusy) {
      return;
    }
    setState(() => _pdfBusy = true);
    try {
      await PdfDocumentService.openFromUrl(
        url: version.pdfUrl,
        fileName:
            '${item.codigo.isEmpty ? 'directiva-calea' : item.codigo}.pdf',
      );
    } catch (error) {
      if (mounted) _message(CaleaService.cleanError(error));
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
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
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F8),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          title: Text(
            _directiva?.codigo.isNotEmpty == true
                ? _directiva!.codigo
                : 'Directiva CALEA',
          ),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
            const AccountMenuAction(),
          ],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: _body(),
        floatingActionButton: _directiva?.version?.pdfDisponible == true
            ? FloatingActionButton.extended(
                onPressed: _pdfBusy ? null : _openPdf,
                backgroundColor: const Color(0xFFC59D2A),
                foregroundColor: const Color(0xFF102A43),
                icon: _pdfBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_pdfBusy ? 'Abriendo…' : 'Ver PDF'),
              )
            : null,
      ),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 46, color: Colors.blueGrey),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
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
    final item = _directiva;
    if (item == null) return const SizedBox.shrink();
    final version = item.version;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          _DocumentHeader(item: item),
          if (version != null) ...[
            const SizedBox(height: 14),
            _VersionCard(version: version),
          ],
          if (_query.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.saved_search, color: Color(0xFF7A5A00)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Se resaltan las apariciones de “$_query”.',
                      style: const TextStyle(
                        color: Color(0xFF6B5200),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Contenido de la directiva',
                  style: TextStyle(
                    color: _navy,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${version?.secciones.length ?? 0} secciones',
                style: const TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (version == null || version.secciones.isEmpty)
            const _EmptyContent()
          else
            ...version.secciones.map(
              (section) => _SectionCard(section: section, query: _query),
            ),
        ],
      ),
    );
  }
}

class _DocumentHeader extends StatelessWidget {
  final CaleaDirectiva item;
  const _DocumentHeader({required this.item});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF102A43), Color(0xFF245B78)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _HeaderChip(
              icon: Icons.verified_outlined,
              label: item.codigo.isEmpty ? 'CALEA' : item.codigo,
            ),
            if (item.categoria.isNotEmpty)
              _HeaderChip(icon: Icons.folder_outlined, label: item.categoria),
          ],
        ),
        const SizedBox(height: 15),
        Text(
          item.titulo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            height: 1.2,
          ),
        ),
        if (item.descripcion.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            item.descripcion,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .78),
              height: 1.4,
            ),
          ),
        ],
      ],
    ),
  );
}

class _HeaderChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HeaderChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: const Color(0xFFFFD76A)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _VersionCard extends StatelessWidget {
  final CaleaVersion version;
  const _VersionCard({required this.version});

  @override
  Widget build(BuildContext context) {
    final data = <({IconData icon, String label, String value})>[
      if (version.numeroVersion.isNotEmpty)
        (icon: Icons.history, label: 'Versión', value: version.numeroVersion),
      if (version.fechaRevision.isNotEmpty)
        (
          icon: Icons.event_available_outlined,
          label: 'Revisión',
          value: version.fechaRevision,
        ),
      if (version.areaResponsable.isNotEmpty)
        (
          icon: Icons.apartment_outlined,
          label: 'Área',
          value: version.areaResponsable,
        ),
      if (version.numeroPaginas > 0)
        (
          icon: Icons.description_outlined,
          label: 'Extensión',
          value: '${version.numeroPaginas} páginas',
        ),
      if (version.autoriza.isNotEmpty)
        (
          icon: Icons.approval_outlined,
          label: 'Autoriza',
          value: version.autoriza,
        ),
      if (version.realizadoPor.isNotEmpty)
        (
          icon: Icons.edit_note_outlined,
          label: 'Elaboró',
          value: version.realizadoPor,
        ),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 13,
        children: data
            .map(
              (value) => SizedBox(
                width: MediaQuery.sizeOf(context).width > 650
                    ? 245
                    : (MediaQuery.sizeOf(context).width - 58) / 2,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(value.icon, size: 19, color: const Color(0xFF245B78)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            value.label.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .6,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            value.value,
                            style: const TextStyle(
                              color: Color(0xFF102A43),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final CaleaSeccion section;
  final String query;
  const _SectionCard({required this.section, required this.query});

  @override
  Widget build(BuildContext context) {
    final page = _pageLabel(section.paginaInicio, section.paginaFin);
    return Card(
      margin: const EdgeInsets.only(bottom: 11),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: Colors.blueGrey.shade100),
      ),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: query.isNotEmpty && _contains(section, query),
        tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 17),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF2F6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            section.numero.isEmpty ? '${section.orden}' : section.numero,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF245B78),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        title: Text(
          section.titulo.isEmpty ? 'Sección ${section.orden}' : section.titulo,
          style: const TextStyle(
            color: Color(0xFF102A43),
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: page.isEmpty ? null : Text(page),
        children: [
          if (section.contenido.isNotEmpty)
            _HighlightedText(text: section.contenido, query: query),
          if (section.contenido.isNotEmpty && section.bloques.isNotEmpty)
            const Divider(height: 28),
          ...section.bloques.map(
            (block) => _BlockView(block: block, query: query, depth: 0),
          ),
        ],
      ),
    );
  }

  static bool _contains(CaleaSeccion section, String query) {
    final q = query.toLowerCase();
    if (section.titulo.toLowerCase().contains(q) ||
        section.contenido.toLowerCase().contains(q)) {
      return true;
    }
    bool blockContains(CaleaBloque block) =>
        block.titulo.toLowerCase().contains(q) ||
        block.contenido.toLowerCase().contains(q) ||
        block.hijos.any(blockContains);
    return section.bloques.any(blockContains);
  }
}

class _BlockView extends StatelessWidget {
  final CaleaBloque block;
  final String query;
  final int depth;
  const _BlockView({
    required this.block,
    required this.query,
    required this.depth,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: EdgeInsets.only(top: 10, left: depth > 0 ? 12 : 0),
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: depth.isEven ? const Color(0xFFF6F9FB) : Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: Colors.blueGrey.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (block.titulo.isNotEmpty || block.numero.isNotEmpty)
          Text(
            [
              block.numero,
              block.titulo,
            ].where((value) => value.isNotEmpty).join(' · '),
            style: const TextStyle(
              color: Color(0xFF102A43),
              fontWeight: FontWeight.w900,
            ),
          ),
        if (block.contenido.isNotEmpty) ...[
          if (block.titulo.isNotEmpty || block.numero.isNotEmpty)
            const SizedBox(height: 7),
          _HighlightedText(text: block.contenido, query: query),
        ],
        ...block.hijos.map(
          (child) => _BlockView(block: child, query: query, depth: depth + 1),
        ),
      ],
    ),
  );
}

class _HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  const _HighlightedText({required this.text, required this.query});

  @override
  Widget build(BuildContext context) {
    const normal = TextStyle(
      color: Color(0xFF334E68),
      height: 1.5,
      fontSize: 14,
    );
    if (query.isEmpty) return SelectableText(text, style: normal);
    final spans = <TextSpan>[];
    final lower = text.toLowerCase();
    final needle = query.toLowerCase();
    var start = 0;
    while (true) {
      final index = lower.indexOf(needle, start);
      if (index < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + needle.length),
          style: const TextStyle(
            backgroundColor: Color(0xFFFFE082),
            color: Color(0xFF3D3000),
            fontWeight: FontWeight.w900,
          ),
        ),
      );
      start = index + needle.length;
    }
    return SelectableText.rich(TextSpan(style: normal, children: spans));
  }
}

class _EmptyContent extends StatelessWidget {
  const _EmptyContent();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: const Column(
      children: [
        Icon(Icons.menu_book_outlined, size: 38, color: Colors.blueGrey),
        SizedBox(height: 9),
        Text(
          'Esta versión no tiene secciones de lectura disponibles.',
          textAlign: TextAlign.center,
        ),
      ],
    ),
  );
}

String _pageLabel(int start, int end) {
  if (start <= 0) return '';
  if (end <= 0 || end == start) return 'Página $start';
  return 'Páginas $start–$end';
}
