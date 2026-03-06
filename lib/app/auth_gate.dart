import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';

import '../screens/welcome_screen.dart';
import '../screens/home_screen.dart';
import '../screens/home_perito_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<Widget> _resolveHome() async {
    final logged = await AuthService.isLoggedIn();
    if (!logged) {
      return const WelcomeScreen();
    }

    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) {
      return const WelcomeScreen();
    }

    final peritoHome = await HomeResolverService.isPeritoHomeAvailable();

    if (peritoHome) {
      return const HomePeritoScreen();
    }

    return const HomeScreen();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _resolveHome(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
