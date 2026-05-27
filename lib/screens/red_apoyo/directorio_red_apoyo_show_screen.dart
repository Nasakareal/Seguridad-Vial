import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/red_apoyo.dart';
import '../../services/auth_service.dart';
import '../../services/directorio_red_apoyo_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/permission_guard.dart';
import '../login_screen.dart';

class DirectorioRedApoyoShowScreen extends StatefulWidget {
  const DirectorioRedApoyoShowScreen({super.key});

  @override
  State<DirectorioRedApoyoShowScreen> createState() =>
      _DirectorioRedApoyoShowScreenState();
}

class _DirectorioRedApoyoShowScreenState
    extends State<DirectorioRedApoyoShowScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  RedApoyoContact? _contact;

  int? _idFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['red_apoyo_id'] ?? args['id'];
      if (raw is int) return raw;
      return int.tryParse(raw?.toString() ?? '');
    }
    if (args is int) return args;
    return int.tryParse(args?.toString() ?? '');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_contact == null && _loading) {
      _load();
    }
  }

  Future<void> _load() async {
    final id = _idFromArgs();
    if (id == null || id <= 0) {
      setState(() {
        _loading = false;
        _error = 'Falta red_apoyo_id.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final contact = await DirectorioRedApoyoService.show(id);
      if (!mounted) return;
      setState(() {
        _contact = contact;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'No se pudo cargar el contacto.\n${DirectorioRedApoyoService.cleanExceptionMessage(e)}';
      });
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (_busy) return;
    _busy = true;

    try {
      try {
        await TrackingService.stop();
      } catch (_) {}
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

  Future<void> _launchPhone(String phone) async {
    final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) {
      _showMessage('El contacto no tiene telefono.');
      return;
    }

    final opened = await launchUrl(Uri.parse('tel:$digits'));
    if (!opened) {
      _showMessage('No se pudo abrir el telefono.');
    }
  }

  Future<void> _launchWhatsApp(String url) async {
    if (url.trim().isEmpty) {
      _showMessage('El contacto no tiene WhatsApp disponible.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showMessage('Link de WhatsApp invalido.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      _showMessage('No se pudo abrir WhatsApp.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contact = _contact;

    return PermissionGuard(
      permission: 'ver directorio red apoyo',
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F7FB),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Contacto de apoyo'),
          actions: [
            IconButton(
              tooltip: 'Actualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            const AccountMenuAction(),
          ],
        ),
        endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
        body: SafeArea(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _MessageCard(
                    icon: Icons.error_outline,
                    title: 'Sin detalle',
                    message: _error!,
                    color: Colors.red,
                    onAction: _load,
                  )
                else if (contact == null)
                  _MessageCard(
                    icon: Icons.support_agent_outlined,
                    title: 'Sin datos',
                    message: 'No hay informacion para este contacto.',
                    color: Colors.blue,
                    onAction: _load,
                  )
                else ...[
                  _HeroCard(contact: contact),
                  const SizedBox(height: 14),
                  _ContactActions(
                    contact: contact,
                    onCall: _launchPhone,
                    onWhatsApp: _launchWhatsApp,
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: 'Datos principales',
                    children: [
                      _InfoRow('Region', contact.regionLabel),
                      _InfoRow('Adscripcion', contact.territorioLabel),
                      _InfoRow('Nivel', contact.nivelLabel),
                      _InfoRow('Tipo de apoyo', contact.tipoApoyoLabel),
                      _InfoRow('Municipio', _value(contact.municipio)),
                      _InfoRow('Direccion', _value(contact.direccion)),
                      _InfoRow(
                        'Destacamento',
                        _value(contact.destacamento?.nombre),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: 'Contacto',
                    children: [
                      _InfoRow('Encargado', _value(contact.contacto)),
                      _InfoRow('Cargo', _value(contact.cargo)),
                      _InfoRow('Telefono', _value(contact.telefono)),
                      _InfoRow(
                        'Secundario',
                        _value(contact.telefonoSecundario),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InfoCard(
                    title: 'Observaciones',
                    children: [
                      Text(
                        _value(contact.observaciones),
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final RedApoyoContact contact;

  const _HeroCard({required this.contact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.institucion,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      [
                        contact.contacto,
                        contact.cargo,
                      ].where((value) => value.trim().isNotEmpty).join(' · '),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .82),
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _HeroChip(label: contact.regionLabel),
              _HeroChip(label: contact.nivelLabel),
              _HeroChip(label: contact.tipoApoyoLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  final String label;

  const _HeroChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _ContactActions extends StatelessWidget {
  final RedApoyoContact contact;
  final ValueChanged<String> onCall;
  final ValueChanged<String> onWhatsApp;

  const _ContactActions({
    required this.contact,
    required this.onCall,
    required this.onWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: contact.telefono.isEmpty
                      ? null
                      : () => onCall(contact.telefono),
                  icon: const Icon(Icons.call),
                  label: const Text('Llamar'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: contact.whatsapp.url.isEmpty
                      ? null
                      : () => onWhatsApp(contact.whatsapp.url),
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp'),
                ),
              ),
            ],
          ),
          if (contact.telefonoSecundario.isNotEmpty ||
              contact.whatsapp.urlSecundaria.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: contact.telefonoSecundario.isEmpty
                        ? null
                        : () => onCall(contact.telefonoSecundario),
                    icon: const Icon(Icons.phone_in_talk_outlined),
                    label: const Text('Llamar 2'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: contact.whatsapp.urlSecundaria.isEmpty
                        ? null
                        : () => onWhatsApp(contact.whatsapp.urlSecundaria),
                    icon: const Icon(Icons.mark_unread_chat_alt_outlined),
                    label: const Text('WhatsApp 2'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final MaterialColor color;
  final VoidCallback onAction;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color.shade700, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade800,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

String _value(String? raw) {
  final text = raw?.trim() ?? '';
  return text.isEmpty ? '-' : text;
}
