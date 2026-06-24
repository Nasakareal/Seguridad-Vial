import 'package:flutter/material.dart';

import '../../services/licencia_puntos_service.dart';

class LicenciasPuntosPublicScreen extends StatefulWidget {
  const LicenciasPuntosPublicScreen({super.key});

  @override
  State<LicenciasPuntosPublicScreen> createState() =>
      _LicenciasPuntosPublicScreenState();
}

class _LicenciasPuntosPublicScreenState
    extends State<LicenciasPuntosPublicScreen> {
  final _numeroCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  LicenciaPuntoCuenta? _cuenta;

  @override
  void dispose() {
    _numeroCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final numero = _numeroCtrl.text.trim();
    if (numero.isEmpty) {
      _showSnack('Captura el número de licencia.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final cuenta = await LicenciaPuntosService.buscarPublicaPorNumero(numero);
      if (!mounted) return;
      setState(() => _cuenta = cuenta);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = LicenciaPuntosService.cleanExceptionMessage(e);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final cuenta = _cuenta;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(title: const Text('Consultar puntos de licencia')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            _Panel(
              icon: Icons.search,
              title: 'Consulta ciudadana',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _numeroCtrl,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Número de licencia',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    onSubmitted: (_) => _buscar(),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : _buscar,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: Text(_busy ? 'Consultando...' : 'Consultar'),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              _ErrorCard(message: _error!),
            ],
            const SizedBox(height: 12),
            _SaldoCard(cuenta: cuenta),
            const SizedBox(height: 12),
            _RecoveryCard(cuenta: cuenta),
            const SizedBox(height: 12),
            _HistoryCard(cuenta: cuenta),
          ],
        ),
      ),
    );
  }
}

class _SaldoCard extends StatelessWidget {
  final LicenciaPuntoCuenta? cuenta;

  const _SaldoCard({required this.cuenta});

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    if (c == null) {
      return const _NoticeCard(
        title: 'Sin licencia consultada',
        text: 'Captura el número de licencia para ver saldo y movimientos.',
        icon: Icons.info_outline,
      );
    }

    final color = _saldoColor(c.saldoActual);
    return _Panel(
      icon: Icons.scoreboard_outlined,
      title: 'Saldo actual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  '${c.saldoActual}',
                  style: TextStyle(
                    color: color,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '/ ${c.saldoMaximo} puntos',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _InfoLine(label: 'Licencia', value: c.numeroLicencia),
          if (c.tipoLicenciaLabel.trim().isNotEmpty)
            _InfoLine(label: 'Tipo', value: c.tipoLicenciaLabel),
          if (c.titularNombre.trim().isNotEmpty)
            _InfoLine(label: 'Titular', value: c.titularNombre),
          _InfoLine(
            label: 'Estado',
            value: c.estadoLabel.isEmpty ? 'Vigente' : c.estadoLabel,
          ),
          if (!c.cuentaRegistrada) ...[
            const SizedBox(height: 10),
            Text(
              'No hay movimientos registrados. Para consulta se asume saldo completo.',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  final LicenciaPuntoCuenta? cuenta;

  const _RecoveryCard({required this.cuenta});

  @override
  Widget build(BuildContext context) {
    final c = cuenta;
    if (c == null) {
      return const SizedBox.shrink();
    }

    return _Panel(
      icon: Icons.event_available,
      title: 'Recuperación por tiempo',
      child: Text(
        _recoveryText(c),
        style: TextStyle(
          color: Colors.grey.shade800,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final LicenciaPuntoCuenta? cuenta;

  const _HistoryCard({required this.cuenta});

  @override
  Widget build(BuildContext context) {
    final movimientos =
        cuenta?.movimientos ?? const <LicenciaPuntoMovimiento>[];

    if (cuenta == null) {
      return const SizedBox.shrink();
    }

    if (movimientos.isEmpty) {
      return const _NoticeCard(
        title: 'Sin historial',
        text:
            'Esta licencia no tiene descuentos ni recuperaciones registradas.',
        icon: Icons.history,
      );
    }

    return _Panel(
      icon: Icons.history,
      title: 'Movimientos',
      child: Column(
        children: movimientos.map((mov) {
          final color = mov.puntos < 0
              ? const Color(0xFFDC2626)
              : (mov.puntos > 0 ? const Color(0xFF16A34A) : Colors.grey);
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              mov.infraccionNombre.isNotEmpty
                  ? mov.infraccionNombre
                  : mov.tipo.replaceAll('_', ' '),
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              [
                if (mov.fechaMovimiento.isNotEmpty)
                  _fmtDate(mov.fechaMovimiento),
                if (mov.descripcion.isNotEmpty) mov.descripcion,
                if (mov.referencia.isNotEmpty) 'Folio: ${mov.referencia}',
                'Saldo ${mov.saldoAnterior} -> ${mov.saldoNuevo}',
              ].join('\n'),
            ),
            trailing: Text(
              mov.puntos > 0 ? '+${mov.puntos}' : '${mov.puntos}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _Panel({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: .06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String title;
  final String text;
  final IconData icon;

  const _NoticeCard({
    required this.title,
    required this.text,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      icon: icon,
      title: title,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey.shade700,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFF991B1B),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

Color _saldoColor(int saldo) {
  if (saldo <= 0) return const Color(0xFF111827);
  if (saldo <= 2) return const Color(0xFFDC2626);
  if (saldo <= 4) return const Color(0xFFF59E0B);
  return const Color(0xFF16A34A);
}

String _fmtDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return 'N/A';
  try {
    final dt = DateTime.parse(value).toLocal();
    String two(int x) => x.toString().padLeft(2, '0');
    return '${two(dt.day)}/${two(dt.month)}/${dt.year}';
  } catch (_) {
    return value;
  }
}

String _recoveryText(LicenciaPuntoCuenta cuenta) {
  if (cuenta.saldoActual >= cuenta.saldoMaximo) {
    return 'La licencia ya tiene saldo completo.';
  }

  final rawDate = cuenta.fechaRecuperacion.trim();
  if (rawDate.isEmpty) {
    return 'Aún no hay una fecha de recuperación por tiempo registrada.';
  }

  final parsed = DateTime.tryParse(rawDate);
  if (parsed == null) {
    return 'Fecha estimada de recuperación: $rawDate.';
  }

  final recoveryDate = DateTime(
    parsed.toLocal().year,
    parsed.toLocal().month,
    parsed.toLocal().day,
  );
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = recoveryDate.difference(today).inDays;
  final formatted = _fmtDate(rawDate);

  if (days <= 0) {
    return 'La recuperación por tiempo puede revisarse desde $formatted.';
  }
  if (days == 1) {
    return 'Falta 1 día para la recuperación por tiempo ($formatted).';
  }
  return 'Faltan $days días para la recuperación por tiempo ($formatted).';
}
