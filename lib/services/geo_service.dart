import 'package:geolocator/geolocator.dart';

class GeoResult {
  final double? lat;
  final double? lng;
  final String? calidadGeo;
  final String? notaGeo;
  final String? fuenteUbicacion;

  const GeoResult({
    required this.lat,
    required this.lng,
    required this.calidadGeo,
    required this.notaGeo,
    required this.fuenteUbicacion,
  });
}

class GeoService {
  static Future<GeoResult> getCurrent() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GeoResult(
          lat: null,
          lng: null,
          calidadGeo: 'OFF',
          notaGeo: 'GPS desactivado',
          fuenteUbicacion: null,
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return const GeoResult(
          lat: null,
          lng: null,
          calidadGeo: 'DENIED',
          notaGeo: 'Permiso de ubicación denegado',
          fuenteUbicacion: null,
        );
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      final acc = pos.accuracy;
      final calidad = acc.isFinite ? acc.toStringAsFixed(1) : null;

      return GeoResult(
        lat: pos.latitude,
        lng: pos.longitude,
        calidadGeo: calidad,
        notaGeo: 'ACC:${calidad ?? ''}',
        fuenteUbicacion: 'GPS_APP',
      );
    } catch (e) {
      return GeoResult(
        lat: null,
        lng: null,
        calidadGeo: 'ERR',
        notaGeo: 'Error al inicializar ubicación: $e',
        fuenteUbicacion: null,
      );
    }
  }
}
