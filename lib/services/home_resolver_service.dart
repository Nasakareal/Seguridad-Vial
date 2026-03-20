import 'package:http/http.dart' as http;
import 'auth_service.dart';

class HomeResolverService {
  static Future<bool> _isAvailable(String path) async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) return false;

    final uri = Uri.parse('${AuthService.baseUrl}/$path');

    try {
      final res = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isPeritoHomeAvailable() async {
    return _isAvailable('perito-home/filtros');
  }

  static Future<bool> isAgenteUpecHomeAvailable() async {
    return _isAvailable('agente-upec-home/filtros');
  }
}
