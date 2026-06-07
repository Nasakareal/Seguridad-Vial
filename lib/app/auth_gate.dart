import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/home_resolver_service.dart';

import '../screens/welcome_screen.dart';
import '../screens/home_agente_vial_screen.dart';
import '../screens/home_agente_upec_screen.dart';
import '../screens/home_delegaciones_screen.dart';
import '../screens/home_fenix_screen.dart';
import '../screens/home_motociclista_screen.dart';
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

    final motociclistaHome =
        await HomeResolverService.isMotociclistaHomeAvailable();
    if (motociclistaHome) {
      return const HomeMotociclistaScreen();
    }

    final fenixHome = await HomeResolverService.isFenixHomeAvailable();
    if (fenixHome) {
      return const HomeFenixScreen();
    }

    final agenteVialHome =
        await HomeResolverService.isAgenteVialHomeAvailable();
    if (agenteVialHome) {
      return const HomeAgenteVialScreen();
    }

    final agenteUpecHome =
        await HomeResolverService.isAgenteUpecHomeAvailable();
    if (agenteUpecHome) {
      return const HomeAgenteUpecScreen();
    }

    final delegacionesHome =
        await HomeResolverService.isDelegacionesPoliciaHomeAvailable();
    if (delegacionesHome) {
      return const HomeDelegacionesScreen();
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
