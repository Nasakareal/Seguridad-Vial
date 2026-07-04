import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class ConstanciasManejoScheduleGuard extends StatefulWidget {
  final Widget child;

  const ConstanciasManejoScheduleGuard({super.key, required this.child});

  @override
  State<ConstanciasManejoScheduleGuard> createState() =>
      _ConstanciasManejoScheduleGuardState();
}

class _ConstanciasManejoScheduleGuardState
    extends State<ConstanciasManejoScheduleGuard> {
  late Future<ConstanciasManejoHorarioAccess> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService.constanciasManejoHorarioAccess();
  }

  void _refresh() {
    setState(() {
      _future = AuthService.constanciasManejoHorarioAccess(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ConstanciasManejoHorarioAccess>(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F6FA),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final access = snapshot.data!;
        if (access.allowed) {
          return widget.child;
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FA),
          appBar: AppBar(title: const Text('Constancias de manejo')),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF1D4ED8,
                              ).withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.lock_clock,
                              color: Color(0xFF1D4ED8),
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Modulo bloqueado por horario',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            access.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade800,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () => Navigator.maybePop(context),
                                icon: const Icon(Icons.arrow_back),
                                label: const Text('Volver'),
                              ),
                              ElevatedButton.icon(
                                onPressed: _refresh,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Revisar horario'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
