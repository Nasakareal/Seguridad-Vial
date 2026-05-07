import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class SuperadminGuard extends StatelessWidget {
  final Widget child;
  final String title;

  const SuperadminGuard({
    super.key,
    required this.child,
    this.title = 'Acceso restringido',
  });

  Future<bool> _checkAccess() async {
    var allowed = await AuthService.isSuperadmin();
    if (allowed) return true;

    await AuthService.refreshCurrentUserAccess();
    allowed = await AuthService.isSuperadmin();
    return allowed;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkAccess(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6F7FB),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data != true) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7FB),
            appBar: AppBar(title: Text(title), backgroundColor: Colors.blue),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Solo los usuarios Superadmin pueden acceder a este modulo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }

        return child;
      },
    );
  }
}
