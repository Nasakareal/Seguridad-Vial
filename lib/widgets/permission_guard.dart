import 'package:flutter/material.dart';

import '../services/auth_service.dart';

class PermissionGuard extends StatelessWidget {
  final Widget child;
  final String permission;
  final String title;
  final String message;

  const PermissionGuard({
    super.key,
    required this.child,
    required this.permission,
    this.title = 'Acceso restringido',
    this.message = 'No tienes permiso para acceder a este modulo.',
  });

  Future<bool> _checkAccess() async {
    if (await AuthService.isSuperadmin()) return true;

    var allowed = await AuthService.can(permission);
    if (allowed) return true;

    await AuthService.refreshCurrentUserAccess();
    allowed = await AuthService.can(permission);
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
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
