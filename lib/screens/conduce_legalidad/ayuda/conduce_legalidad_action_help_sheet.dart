import 'package:flutter/material.dart';

class ConduceLegalidadActionHelpSheet extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> steps;
  final String? note;
  final Widget? preview;

  const ConduceLegalidadActionHelpSheet({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.steps,
    this.note,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withValues(alpha: .12),
                    child: Icon(icon, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar ayuda',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(description, style: const TextStyle(height: 1.45)),
              if (preview != null) ...[const SizedBox(height: 18), preview!],
              const SizedBox(height: 20),
              for (var index = 0; index < steps.length; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 15,
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          steps[index],
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
                if (index != steps.length - 1) const SizedBox(height: 14),
              ],
              if (note != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: .07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: .22)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(note!, style: const TextStyle(height: 1.4)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: color),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum ConduceLegalidadCardControl { ticket, share, menu }

class ConduceLegalidadCaptureCardPreview extends StatelessWidget {
  final ConduceLegalidadCardControl highlighted;
  final String? selectedMenuItem;

  const ConduceLegalidadCaptureCardPreview({
    super.key,
    required this.highlighted,
    this.selectedMenuItem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_outline, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Mario Bautista R.',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              _HighlightedControl(
                highlighted: highlighted == ConduceLegalidadCardControl.ticket,
                label: 'BOLETA',
                child: const Icon(Icons.receipt_long_outlined),
              ),
              const SizedBox(width: 4),
              _HighlightedControl(
                highlighted: highlighted == ConduceLegalidadCardControl.share,
                label: 'COMPARTIR',
                child: const Icon(Icons.share_outlined),
              ),
              const SizedBox(width: 4),
              _HighlightedControl(
                highlighted: highlighted == ConduceLegalidadCardControl.menu,
                label: 'OPCIONES',
                child: const Icon(Icons.more_vert),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '2026-09-22 18:08:00',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 10),
          const Text('Se detuvo a motocicleta'),
          const SizedBox(height: 10),
          const Wrap(
            spacing: 7,
            children: [
              _DemoPill(icon: Icons.directions_car, text: '1 vehículos'),
              _DemoPill(icon: Icons.groups_outlined, text: '1 personas'),
              _DemoPill(icon: Icons.photo_library, text: '0 fotos'),
            ],
          ),
          if (highlighted == ConduceLegalidadCardControl.menu) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .14),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MenuDemoItem(
                      icon: Icons.description_outlined,
                      text: 'Descargar IPH',
                      selected: selectedMenuItem == 'iph',
                    ),
                    _MenuDemoItem(
                      icon: Icons.edit_outlined,
                      text: 'Editar',
                      selected: selectedMenuItem == 'editar',
                    ),
                    _MenuDemoItem(
                      icon: Icons.delete_outline,
                      text: 'Eliminar',
                      selected: selectedMenuItem == 'eliminar',
                      danger: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ConduceLegalidadBoletaToolbarPreview extends StatelessWidget {
  const ConduceLegalidadBoletaToolbarPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Boleta de infracción',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                const Icon(Icons.help_outline),
                const SizedBox(width: 6),
                const _HighlightedControl(
                  highlighted: true,
                  label: 'IMPRIMIR',
                  child: Icon(Icons.print_outlined),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.receipt_long_outlined),
                const SizedBox(width: 6),
                const Icon(Icons.refresh),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.arrow_upward, color: Color(0xFFEA580C)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pulsa este icono para elegir papel e impresora.',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ConduceLegalidadAddCapturePreview extends StatelessWidget {
  const ConduceLegalidadAddCapturePreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 210,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            bottom: 62,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mario Bautista R.',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 8),
                  Text('Se detuvo a motocicleta'),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFFE9D5FF),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF7C3AED), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: .25),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Color(0xFF5B21B6)),
                  SizedBox(width: 8),
                  Text(
                    'Agregar captura',
                    style: TextStyle(
                      color: Color(0xFF5B21B6),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightedControl extends StatelessWidget {
  final bool highlighted;
  final String label;
  final Widget child;

  const _HighlightedControl({
    required this.highlighted,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: highlighted ? const Color(0xFFFFEDD5) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: highlighted ? const Color(0xFFEA580C) : Colors.transparent,
            width: 2,
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: const Color(0xFFEA580C).withValues(alpha: .25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

class _DemoPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DemoPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _MenuDemoItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool selected;
  final bool danger;

  const _MenuDemoItem({
    required this.icon,
    required this.text,
    required this.selected,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Colors.black87;
    return Container(
      color: selected ? const Color(0xFFFFEDD5) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Icon(icon, color: selected ? const Color(0xFFEA580C) : color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: selected ? const Color(0xFF9A3412) : color,
                fontWeight: selected ? FontWeight.w900 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
