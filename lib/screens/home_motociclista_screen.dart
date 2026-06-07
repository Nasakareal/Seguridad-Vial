import 'package:flutter/material.dart';

import '../app/routes.dart';
import '../services/auth_service.dart';
import '../services/motociclista_report_service.dart';
import '../services/tracking_service.dart';
import '../widgets/account_drawer.dart';
import 'login_screen.dart';

class HomeMotociclistaScreen extends StatefulWidget {
  const HomeMotociclistaScreen({super.key});

  @override
  State<HomeMotociclistaScreen> createState() => _HomeMotociclistaScreenState();
}

class _HomeMotociclistaScreenState extends State<HomeMotociclistaScreen> {
  bool _busy = false;

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

  void _openReport(MotociclistaReportKind kind) {
    Navigator.pushNamed(
      context,
      AppRoutes.motociclistaReporte,
      arguments: kind,
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = <_ReportCardData>[
      _ReportCardData(
        kind: MotociclistaReportKind.abanderamiento,
        icon: Icons.traffic,
        color: const Color(0xFF0F766E),
      ),
      _ReportCardData(
        kind: MotociclistaReportKind.apoyoPreventivo,
        icon: Icons.health_and_safety_outlined,
        color: const Color(0xFF2563EB),
      ),
      _ReportCardData(
        kind: MotociclistaReportKind.cierreVialidad,
        icon: Icons.do_not_disturb_on_outlined,
        color: const Color(0xFFB45309),
      ),
      _ReportCardData(
        kind: MotociclistaReportKind.dispositivoVial,
        icon: Icons.route_outlined,
        color: const Color(0xFF7C3AED),
      ),
      _ReportCardData(
        kind: MotociclistaReportKind.monitoreoSinNovedad,
        icon: Icons.check_circle_outline,
        color: const Color(0xFF15803D),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      appBar: AppBar(
        title: const Text('Motociclista'),
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: const [AccountMenuAction()],
      ),
      endDrawer: AppAccountDrawer(onLogout: () => _logout(context)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
          children: [
            const _Header(),
            const SizedBox(height: 16),
            for (final item in items) ...[
              _ReportCard(data: item, onTap: () => _openReport(item.kind)),
              const SizedBox(height: 12),
            ],
            const SizedBox(height: 4),
            ElevatedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.motociclistaReportes),
              icon: const Icon(Icons.list_alt),
              label: const Text('Reportes enviados'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.offlineSyncErrors),
              icon: const Icon(Icons.sync_problem_outlined),
              label: const Text('Pendientes por enviar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Reporte rápido',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 6),
          Text(
            'Unidad de Protección en Vialidades Urbanas',
            style: TextStyle(fontSize: 15, height: 1.25),
          ),
        ],
      ),
    );
  }
}

class _ReportCardData {
  final MotociclistaReportKind kind;
  final IconData icon;
  final Color color;

  const _ReportCardData({
    required this.kind,
    required this.icon,
    required this.color,
  });
}

class _ReportCard extends StatelessWidget {
  final _ReportCardData data;
  final VoidCallback onTap;

  const _ReportCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(data.icon, size: 32, color: data.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  data.kind.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 30),
            ],
          ),
        ),
      ),
    );
  }
}
