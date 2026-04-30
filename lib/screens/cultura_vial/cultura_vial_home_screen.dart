import 'package:flutter/material.dart';

import '../../app/routes.dart';
import '../../models/cultura_vial.dart';
import '../../services/auth_service.dart';
import '../../services/cultura_vial_service.dart';
import '../../services/tracking_service.dart';
import '../../widgets/account_drawer.dart';
import '../../widgets/app_drawer.dart';
import '../login_screen.dart';

class CulturaVialHomeScreen extends StatefulWidget {
  const CulturaVialHomeScreen({super.key});

  @override
  State<CulturaVialHomeScreen> createState() => _CulturaVialHomeScreenState();
}

class _CulturaVialHomeScreenState extends State<CulturaVialHomeScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<CulturaVialSala> _salas = const <CulturaVialSala>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final salas = await CulturaVialService.fetchSalas();
      if (!mounted) return;
      setState(() => _salas = salas);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CulturaVialService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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

  Future<void> _createSala() async {
    final controller = TextEditingController(
      text: 'Clase de Cultura Vial ${DateTime.now().day}',
    );

    final nombre = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Nueva sala'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Nombre de la sala',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) =>
                Navigator.pop(dialogContext, controller.text.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Crear'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (nombre == null) return;

    setState(() => _busy = true);
    try {
      final sala = await CulturaVialService.createSala(nombre: nombre);
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        AppRoutes.culturaVialSala,
        arguments: {'salaId': sala.id},
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CulturaVialService.cleanExceptionMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF083344),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE047),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.sports_esports,
                  color: Color(0xFF083344),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Cultura Vial Interactiva',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Salas con QR, juego rápido y puntaje en vivo para cada participante.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .86),
              fontSize: 14,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _createSala,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFDE047),
                foregroundColor: const Color(0xFF083344),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline),
              label: Text(_busy ? 'Creando...' : 'Crear sala con QR'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomCard(CulturaVialSala sala) {
    final color = sala.abierta ? const Color(0xFF16A34A) : Colors.grey;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.qr_code_2, color: color),
        ),
        title: Text(
          sala.nombre,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(
          '${sala.codigo} • ${sala.participantesCount} participantes • ${sala.estado}',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          await Navigator.pushNamed(
            context,
            AppRoutes.culturaVialSala,
            arguments: {'salaId': sala.id},
          );
          if (mounted) await _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Cultura Vial'),
        actions: const [AccountMenuAction()],
      ),
      drawer: const AppDrawer(trackingOn: false),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            _header(),
            const SizedBox(height: 16),
            const Text(
              'Salas recientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 28),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else if (_salas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 34),
                child: Text(
                  'Todavía no hay salas. Crea una para empezar con el grupo.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._salas.map(_roomCard),
          ],
        ),
      ),
    );
  }
}

class CulturaVialSalaScreen extends StatefulWidget {
  const CulturaVialSalaScreen({super.key});

  @override
  State<CulturaVialSalaScreen> createState() => _CulturaVialSalaScreenState();
}

class _CulturaVialSalaScreenState extends State<CulturaVialSalaScreen> {
  int? _salaId;
  CulturaVialSala? _sala;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_salaId != null) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      final raw = args['salaId'] ?? args['id'];
      _salaId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    }
    _load();
  }

  Future<void> _load() async {
    final id = _salaId;
    if (id == null || id <= 0) {
      setState(() {
        _loading = false;
        _error = 'Sala inválida.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sala = await CulturaVialService.fetchSala(id);
      if (!mounted) return;
      setState(() => _sala = sala);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = CulturaVialService.cleanExceptionMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _closeRoom() async {
    final sala = _sala;
    if (sala == null || !sala.abierta || _busy) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar sala'),
        content: const Text('Los niños ya no podrán enviar nuevos puntajes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      final updated = await CulturaVialService.closeSala(sala.id);
      if (!mounted) return;
      setState(() => _sala = updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(CulturaVialService.cleanExceptionMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _qrPanel(CulturaVialSala sala) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Código de sala',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sala.codigo,
                      style: const TextStyle(
                        fontSize: 34,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(open: sala.abierta),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<Map<String, String>>(
            future: CulturaVialService.authHeaders(json: false),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const SizedBox(
                  height: 220,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  CulturaVialService.qrUrlFor(sala.id),
                  headers: snap.data,
                  width: 240,
                  height: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 240,
                    height: 240,
                    alignment: Alignment.center,
                    color: Colors.grey.shade100,
                    child: const Text(
                      'No se pudo cargar el QR.\nUsa el código de sala.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            sala.joinPayload,
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ranking(CulturaVialSala sala) {
    final participantes = sala.participantes;
    if (participantes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Text(
          'Cuando los niños terminen el juego, aquí aparecerá el ranking.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < participantes.length; i++)
          _RankingTile(rank: i + 1, participante: participantes[i]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sala = _sala;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Sala de juego'),
        actions: [
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 80),
                child: Text(_error!, textAlign: TextAlign.center),
              )
            else if (sala != null) ...[
              Text(
                sala.nombre,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Misión Ciudad Segura • ${sala.participantesCount} participantes',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              _qrPanel(sala),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _load,
                      icon: const Icon(Icons.leaderboard),
                      label: const Text('Actualizar ranking'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (sala.abierta)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _busy ? null : _closeRoom,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Cerrar sala'),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Ranking',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              _ranking(sala),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final bool open;

  const _StatusPill({required this.open});

  @override
  Widget build(BuildContext context) {
    final color = open ? const Color(0xFF16A34A) : Colors.grey.shade700;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        open ? 'Abierta' : 'Cerrada',
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _RankingTile extends StatelessWidget {
  final int rank;
  final CulturaVialParticipante participante;

  const _RankingTile({required this.rank, required this.participante});

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFFF59E0B),
      const Color(0xFF64748B),
      const Color(0xFFB45309),
    ];
    final color = rank <= 3 ? colors[rank - 1] : const Color(0xFF2563EB);
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .14),
          child: Text(
            '$rank',
            style: TextStyle(color: color, fontWeight: FontWeight.w900),
          ),
        ),
        title: Text(
          participante.nombre,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text('${participante.intentos} intento(s)'),
        trailing: Text(
          '${participante.mejorPuntaje}',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}
