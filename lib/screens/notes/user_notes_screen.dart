import 'package:flutter/material.dart';

import '../../models/user_note.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../services/user_notes_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';
import 'note_editor_screen.dart';

class UserNotesScreen extends StatefulWidget {
  const UserNotesScreen({super.key});

  @override
  State<UserNotesScreen> createState() => _UserNotesScreenState();
}

class _UserNotesScreenState extends State<UserNotesScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<UserNote> _notes = const <UserNote>[];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refreshFilter);
    _load();
  }

  void _refreshFilter() => setState(() {});

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final notes = await UserNotesService.fetchNotes();
      if (!mounted) return;
      setState(() {
        _notes = notes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _friendlyError(error);
        _loading = false;
      });
    }
  }

  List<UserNote> get _visibleNotes {
    final query = _normalize(_searchController.text);
    if (query.isEmpty) return _notes;
    return _notes
        .where((note) {
          return _normalize('${note.title} ${note.content}').contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openEditor([UserNote? note]) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
    if (changed == true) await _load();
  }

  Future<void> _togglePin(UserNote note) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await UserNotesService.save(
        id: note.id,
        title: note.title,
        content: note.content,
        color: note.color,
        isPinned: !note.isPinned,
        highlights: note.highlights,
      );
      await _load();
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(UserNote note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: Text(
          note.title.trim().isEmpty
              ? '¿Quieres eliminar esta nota?'
              : '¿Quieres eliminar “${note.title.trim()}”?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || _busy) return;

    setState(() => _busy = true);
    try {
      await UserNotesService.delete(note.id);
      if (!mounted) return;
      setState(
        () => _notes = _notes.where((item) => item.id != note.id).toList(),
      );
      _message('Nota eliminada.');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await TrackingService.stop();
    } catch (_) {}
    await AuthService.logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = _visibleNotes;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Mis notas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar desde el servidor',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.sync),
          ),
          const AccountMenuAction(),
        ],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : () => _openEditor(),
        icon: const Icon(Icons.note_add_outlined),
        label: const Text('Nueva nota'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar en mis notas',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          onPressed: _searchController.clear,
                          icon: const Icon(Icons.close),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(child: _buildContent(notes)),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(List<UserNote> notes) {
    if (_loading && _notes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _notes.isEmpty) {
      return _NotesState(
        icon: Icons.cloud_off_outlined,
        title: 'No se pudieron recuperar tus notas',
        subtitle: _error!,
        action: OutlinedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Reintentar'),
        ),
      );
    }
    if (notes.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;
      return _NotesState(
        icon: searching ? Icons.search_off : Icons.sticky_note_2_outlined,
        title: searching
            ? 'No encontramos coincidencias'
            : 'Aún no tienes notas',
        subtitle: searching
            ? 'Prueba con otra palabra o limpia la búsqueda.'
            : 'Crea una nota, elige su color y resalta lo importante.',
        action: searching
            ? OutlinedButton(
                onPressed: _searchController.clear,
                child: const Text('Limpiar búsqueda'),
              )
            : FilledButton.icon(
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add),
                label: const Text('Crear mi primera nota'),
              ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 1050
              ? 3
              : constraints.maxWidth >= 680
              ? 2
              : 1;
          const gap = 12.0;
          final width =
              (constraints.maxWidth - 28 - (gap * (columns - 1))) / columns;
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final note in notes)
                  SizedBox(
                    width: width,
                    child: _NoteCard(
                      note: note,
                      onOpen: () => _openEditor(note),
                      onTogglePin: () => _togglePin(note),
                      onDelete: () => _delete(note),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _searchController.removeListener(_refreshFilter);
    _searchController.dispose();
    super.dispose();
  }
}

class _NoteCard extends StatelessWidget {
  final UserNote note;
  final VoidCallback onOpen;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onOpen,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final accent = NotePalette.cardAccent(note.color);
    return Material(
      color: NotePalette.cardBackground(note.color),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: onOpen,
        child: Container(
          constraints: const BoxConstraints(minHeight: 170),
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: accent.withValues(alpha: .24)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (note.isPinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: Icon(Icons.push_pin, size: 17, color: accent),
                    ),
                  Expanded(
                    child: Text(
                      note.title.trim().isEmpty ? 'Sin título' : note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Opciones de la nota',
                    onSelected: (value) {
                      if (value == 'pin') onTogglePin();
                      if (value == 'delete') onDelete();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'pin',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            note.isPinned
                                ? Icons.push_pin_outlined
                                : Icons.push_pin,
                          ),
                          title: Text(
                            note.isPinned ? 'Desfijar' : 'Fijar arriba',
                          ),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                          ),
                          title: Text('Eliminar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (note.content.trim().isEmpty)
                Text(
                  'Nota sin contenido',
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                _HighlightedPreview(note: note),
              const SizedBox(height: 14),
              Text(
                _updatedLabel(note.updatedAt),
                style: TextStyle(
                  color: accent.withValues(alpha: .86),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightedPreview extends StatelessWidget {
  final UserNote note;

  const _HighlightedPreview({required this.note});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      _highlightedSpan(note.content, note.highlights),
      maxLines: 7,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xFF334155),
        height: 1.38,
        fontSize: 14,
      ),
    );
  }
}

TextSpan _highlightedSpan(String text, List<NoteHighlight> highlights) {
  final valid =
      highlights
          .where(
            (item) =>
                item.start >= 0 &&
                item.end <= text.length &&
                item.end > item.start,
          )
          .toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final children = <InlineSpan>[];
  var offset = 0;
  for (final item in valid) {
    if (item.start < offset) continue;
    if (item.start > offset) {
      children.add(TextSpan(text: text.substring(offset, item.start)));
    }
    children.add(
      TextSpan(
        text: text.substring(item.start, item.end),
        style: TextStyle(
          backgroundColor: NotePalette.marker(item.color),
          color: const Color(0xFF111827),
        ),
      ),
    );
    offset = item.end;
  }
  if (offset < text.length) {
    children.add(TextSpan(text: text.substring(offset)));
  }
  return TextSpan(children: children);
}

class _NotesState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget action;

  const _NotesState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 58, color: const Color(0xFF64748B)),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            action,
          ],
        ),
      ),
    );
  }
}

String _updatedLabel(DateTime? value) {
  if (value == null) return 'Guardada';
  final local = value.toLocal();
  final now = DateTime.now();
  final sameDay =
      local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (sameDay) return 'Editada hoy, $hour:$minute';
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return 'Editada $day/$month/${local.year}, $hour:$minute';
}

String _normalize(String value) {
  return value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .trim();
}

String _friendlyError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
