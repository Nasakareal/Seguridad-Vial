import 'package:flutter/material.dart';

import '../../core/guardianes_camino/guardianes_camino_dispositivos_catalogos.dart';
import '../../services/auth_service.dart';
import 'dispositivo_form_screen.dart';

class DispositivoCreateScreen extends StatefulWidget {
  const DispositivoCreateScreen({super.key});

  @override
  State<DispositivoCreateScreen> createState() =>
      _DispositivoCreateScreenState();
}

class _DispositivoCreateScreenState extends State<DispositivoCreateScreen> {
  bool _checkingAccess = true;
  bool _canCreate = false;

  @override
  void initState() {
    super.initState();
    _loadAccess();
  }

  Future<void> _loadAccess() async {
    final hasUnitAccess = await AuthService.isCarreterasUser(refresh: true);
    final hasPermission = await AuthService.can('crear operativos carreteras');
    if (!mounted) return;
    setState(() {
      _canCreate = hasUnitAccess && hasPermission;
      _checkingAccess = false;
    });
  }

  void _handleCatalogoTap(GuardianesCaminoCatalogoLocal catalogo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DispositivoFormScreen(catalogo: catalogo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingAccess) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Agregar dispositivo'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_canCreate) {
      return Scaffold(
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.blue,
          title: const Text('Agregar dispositivo'),
        ),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No tienes acceso al módulo de carreteras.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.blue,
        title: const Text('Agregar dispositivo'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Selecciona el tipo de dispositivo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...GuardianesCaminoDispositivosCatalogos.items.map((catalogo) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _handleCatalogoTap(catalogo),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_road,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              catalogo.titulo,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.grey.shade500,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
