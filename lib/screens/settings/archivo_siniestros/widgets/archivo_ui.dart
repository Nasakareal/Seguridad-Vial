import 'package:flutter/material.dart';

const archivoInk = Color(0xFF0F172A);
const archivoTeal = Color(0xFF0F766E);
const archivoBg = Color(0xFFF1F5F9);
const archivoMuted = Color(0xFF64748B);

class ArchivoLayout extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ArchivoLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: archivoBg,
    appBar: AppBar(title: Text(title), actions: actions),
    floatingActionButton: floatingActionButton,
    body: SafeArea(
      child: Column(children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [archivoInk, Color(0xFF0F3B3B)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('UNIDAD DE ATENCIÓN A SINIESTROS',
                style: TextStyle(color: Color(0xFF99F6E4), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: .7)),
            const SizedBox(height: 7),
            Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ]),
        ),
        Expanded(child: child),
      ]),
    ),
  );
}

class ArchivoLoading extends StatelessWidget {
  const ArchivoLoading({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}

class ArchivoError extends StatelessWidget {
  final Object error;
  final VoidCallback retry;
  const ArchivoError({super.key, required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.error_outline, size: 44, color: Colors.deepOrange),
        const SizedBox(height: 8),
        Text(error.toString(), textAlign: TextAlign.center),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Reintentar')),
      ]),
    ),
  );
}

class ArchivoVacio extends StatelessWidget {
  final String mensaje;
  const ArchivoVacio(this.mensaje, {super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.inventory_2_outlined, color: archivoTeal, size: 42),
        const SizedBox(height: 10),
        Text(mensaje, textAlign: TextAlign.center, style: const TextStyle(color: archivoMuted)),
      ]),
    ),
  );
}

class ArchivoKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const ArchivoKpi({super.key, required this.icon, required this.label, required this.value, this.color = archivoTeal});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        CircleAvatar(backgroundColor: color.withValues(alpha: .12), foregroundColor: color, child: Icon(icon)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
          Text(label, style: const TextStyle(color: archivoMuted, fontSize: 12)),
        ])),
      ]),
    ),
  );
}

class ArchivoSection extends StatelessWidget {
  final String title;
  final Widget child;
  const ArchivoSection({super.key, required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        child,
      ]),
    ),
  );
}

class ArchivoPaginacion extends StatelessWidget {
  final int page;
  final int lastPage;
  final ValueChanged<int> onChanged;
  const ArchivoPaginacion({super.key, required this.page, required this.lastPage, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    if (lastPage <= 1) return const SizedBox.shrink();
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      IconButton(onPressed: page > 1 ? () => onChanged(page - 1) : null, icon: const Icon(Icons.chevron_left)),
      Text('Página $page de $lastPage', style: const TextStyle(fontWeight: FontWeight.w700)),
      IconButton(onPressed: page < lastPage ? () => onChanged(page + 1) : null, icon: const Icon(Icons.chevron_right)),
    ]);
  }
}

InputDecoration archivoInput(String label, {String? hint, IconData? icon}) => InputDecoration(
  labelText: label,
  hintText: hint,
  prefixIcon: icon == null ? null : Icon(icon),
  border: const OutlineInputBorder(),
  isDense: true,
);

void archivoToast(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? Colors.red.shade700 : archivoTeal,
  ));
}

Future<bool> archivoConfirmar(BuildContext context, String titulo, String mensaje) async =>
  await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(titulo),
      content: Text(mensaje),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
      ],
    ),
  ) ?? false;

String archivoEtiqueta(String value) => value.replaceAll('_', ' ').trim();
