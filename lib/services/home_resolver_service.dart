import 'package:http/http.dart' as http;
import 'auth_service.dart';

class HomeResolverService {
  static Future<bool> isPeritoHomeAvailable() async {
    final token = await AuthService.getToken();
    if (token == null || token.trim().isEmpty) return false;

    final uri = Uri.parse('${AuthService.baseUrl}/home/perito');

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
}
