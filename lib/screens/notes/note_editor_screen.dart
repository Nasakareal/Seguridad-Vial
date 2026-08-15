import 'package:flutter/material.dart';

import '../../models/user_note.dart';
import '../../services/user_notes_service.dart';
import 'note_text_editing_controller.dart';

class NoteEditorScreen extends StatefulWidget {
  final UserNote? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final NoteTextEditingController _contentController;
  final FocusNode _contentFocus = FocusNode();
  late String _cardColor;
  late bool _isPinned;
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = NoteTextEditingController(
      text: note?.content ?? '',
      highlights: note?.highlights ?? const <NoteHighlight>[],
    );
    _cardColor = note?.color ?? 'neutral';
    _isPinned = note?.isPinned ?? false;
    _titleController.addListener(_markDirty);
    _contentController.addListener(_markDirty);
  }

  void _markDirty() {
    if (!_dirty && mounted) setState(() => _dirty = true);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_titleController.text.trim().isEmpty &&
        _contentController.text.trim().isEmpty) {
      _message('Escribe un título o contenido antes de guardar.');
      return;
    }

    setState(() => _saving = true);
    try {
      await UserNotesService.save(
        id: widget.note?.id,
        title: _titleController.text,
        content: _contentController.text,
        color: _cardColor,
        isPinned: _isPinned,
        highlights: _contentController.highlights,
      );
      _dirty = false;
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _tryClose() async {
    if (!_dirty || _saving) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        content: const Text('Hay cambios en esta nota que todavía no guardas.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) {
      _dirty = false;
      Navigator.of(context).pop();
    }
  }

  void _applyMarker(String color) {
    if (!_contentController.applyHighlight(color)) {
      _message('Selecciona primero el texto que quieres resaltar.');
    }
    _contentFocus.requestFocus();
  }

  void _clearMarker() {
    if (!_contentController.clearHighlight()) {
      _message('Selecciona el texto al que quieres quitar el resaltado.');
    }
    _contentFocus.requestFocus();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _tryClose();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        appBar: AppBar(
          title: Text(widget.note == null ? 'Nueva nota' : 'Editar nota'),
          leading: IconButton(
            tooltip: 'Volver',
            onPressed: _saving ? null : _tryClose,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              tooltip: _isPinned ? 'Desfijar nota' : 'Fijar nota',
              onPressed: _saving
                  ? null
                  : () => setState(() {
                      _isPinned = !_isPinned;
                      _dirty = true;
                    }),
              icon: Icon(_isPinned ? Icons.push_pin : Icons.push_pin_outlined),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_done_outlined, size: 18),
                label: Text(_saving ? 'Guardando' : 'Guardar'),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 30),
            children: [
              _EditorToolbar(
                selectedCardColor: _cardColor,
                onCardColor: (color) => setState(() {
                  _cardColor = color;
                  _dirty = true;
                }),
                onMarker: _applyMarker,
                onClearMarker: _clearMarker,
              ),
              const SizedBox(height: 12),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                constraints: const BoxConstraints(minHeight: 460),
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                decoration: BoxDecoration(
                  color: NotePalette.cardBackground(_cardColor),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: NotePalette.cardAccent(
                      _cardColor,
                    ).withValues(alpha: .28),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _titleController,
                      maxLength: 160,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 23,
                        height: 1.15,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Título',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                    Divider(
                      color: NotePalette.cardAccent(
                        _cardColor,
                      ).withValues(alpha: .18),
                    ),
                    TextField(
                      controller: _contentController,
                      focusNode: _contentFocus,
                      minLines: 14,
                      maxLines: null,
                      maxLength: 50000,
                      keyboardType: TextInputType.multiline,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 16,
                        height: 1.48,
                        color: Color(0xFF1E293B),
                      ),
                      decoration: const InputDecoration(
                        hintText:
                            'Escribe aquí. Para usar el marcatexto, selecciona una parte y toca un color arriba.',
                        border: InputBorder.none,
                        counterText: '',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.removeListener(_markDirty);
    _contentController.removeListener(_markDirty);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }
}

class _EditorToolbar extends StatelessWidget {
  final String selectedCardColor;
  final ValueChanged<String> onCardColor;
  final ValueChanged<String> onMarker;
  final VoidCallback onClearMarker;

  const _EditorToolbar({
    required this.selectedCardColor,
    required this.onCardColor,
    required this.onMarker,
    required this.onClearMarker,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Color de la nota',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in NotePalette.cardColors)
                  _ColorDot(
                    color: NotePalette.cardBackground(color),
                    accent: NotePalette.cardAccent(color),
                    selected: selectedCardColor == color,
                    tooltip: color,
                    onTap: () => onCardColor(color),
                  ),
              ],
            ),
            const SizedBox(height: 13),
            const Text(
              'Marcatexto para la selección',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final color in NotePalette.markerColors)
                  _ColorDot(
                    color: NotePalette.marker(color),
                    accent: NotePalette.cardAccent(color),
                    tooltip: 'Resaltar $color',
                    onTap: () => onMarker(color),
                  ),
                IconButton.filledTonal(
                  tooltip: 'Quitar resaltado de la selección',
                  onPressed: onClearMarker,
                  icon: const Icon(Icons.format_color_reset_outlined),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final Color accent;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.accent,
    this.selected = false,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: accent, width: selected ? 3 : 1.2),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .25),
                      blurRadius: 7,
                    ),
                  ]
                : null,
          ),
          child: selected ? Icon(Icons.check, size: 19, color: accent) : null,
        ),
      ),
    );
  }
}

String _friendlyError(Object error) {
  return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
}
