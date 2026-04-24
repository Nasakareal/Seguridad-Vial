import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../services/auth_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await AuthService.fetchProfile(refresh: true);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      final stored = await AuthService.getStoredUserPayload();
      if (!mounted) return;
      setState(() {
        _profile = stored;
        _loading = false;
        _error = '$e';
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

  Future<void> _openChangePassword() async {
    final changed = await Navigator.pushNamed(
      context,
      AppRoutes.changePassword,
    );
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada correctamente.')),
      );
    }
  }

  String _readString(dynamic raw, {String fallback = 'No especificado'}) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  String _readNestedLabel(dynamic raw) {
    if (raw is! Map) {
      return 'No especificado';
    }

    final candidates = <dynamic>[
      raw['nombre'],
      raw['name'],
      raw['label'],
      raw['slug'],
      raw['numero_economico'],
    ];

    for (final candidate in candidates) {
      final text = candidate?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }

    return 'No especificado';
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile ?? <String, dynamic>{};
    final role = _readNestedLabel(profile['role']);
    final unidad = _readNestedLabel(profile['unidad']);
    final delegacion = _readNestedLabel(profile['delegacion']);
    final destacamento = _readNestedLabel(profile['destacamento']);
    final turno = _readNestedLabel(profile['turno']);
    final patrulla = _readNestedLabel(profile['patrulla']);
    final name = _readString(profile['name'], fallback: 'Usuario');
    final email = _readString(profile['email']);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Actualizar perfil',
            onPressed: _loadProfile,
            icon: const Icon(Icons.refresh),
          ),
          const AccountMenuAction(),
        ],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadProfile,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                      color: Colors.black.withValues(alpha: .12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.white.withValues(alpha: .16),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .86),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ProfilePill(label: role),
                        _ProfilePill(label: unidad),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _openChangePassword,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: .5),
                        ),
                      ),
                      icon: const Icon(Icons.lock_outline),
                      label: const Text('Cambiar contraseña'),
                    ),
                  ],
                ),
              ),
              if (_loading) ...[
                const SizedBox(height: 32),
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7ED),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B)),
                    ),
                    child: Text(
                      'Mostrando la última información disponible.\n$_error',
                      style: const TextStyle(
                        color: Color(0xFF9A3412),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Datos principales'),
                const SizedBox(height: 10),
                _InfoCard(
                  children: [
                    _InfoRow(label: 'Nombre', value: name),
                    _InfoRow(label: 'Correo', value: email),
                    _InfoRow(
                      label: 'Teléfono',
                      value: _readString(profile['telefono']),
                    ),
                    _InfoRow(
                      label: 'Área',
                      value: _readString(profile['area']),
                    ),
                    _InfoRow(
                      label: 'Estado',
                      value: _readString(profile['estado']),
                    ),
                    _InfoRow(label: 'Rol principal', value: role),
                  ],
                ),
                const SizedBox(height: 16),
                const _SectionTitle(title: 'Asignación'),
                const SizedBox(height: 10),
                _InfoCard(
                  children: [
                    _InfoRow(label: 'Unidad', value: unidad),
                    _InfoRow(label: 'Delegación', value: delegacion),
                    _InfoRow(label: 'Destacamento', value: destacamento),
                    _InfoRow(label: 'Turno', value: turno),
                    _InfoRow(label: 'Patrulla', value: patrulla),
                    _InfoRow(
                      label: 'Compartir ubicación',
                      value: '${profile['compartir_ubicacion'] ?? 0}' == '1'
                          ? 'Activo'
                          : 'Inactivo',
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF0F172A),
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
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

class _ProfilePill extends StatelessWidget {
  final String label;

  const _ProfilePill({required this.label});

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
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _initials(String raw) {
  final parts = raw
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();

  if (parts.isEmpty) {
    return 'SV';
  }

  if (parts.length == 1) {
    final text = parts.first;
    return text.substring(0, text.length >= 2 ? 2 : 1).toUpperCase();
  }

  return (parts.first[0] + parts.last[0]).toUpperCase();
}
