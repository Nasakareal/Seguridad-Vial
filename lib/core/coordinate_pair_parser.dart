class CoordinatePair {
  final double latitude;
  final double longitude;

  const CoordinatePair({required this.latitude, required this.longitude});
}

class CoordinatePairParser {
  const CoordinatePairParser._();

  static final RegExp _pairPattern = RegExp(
    r'^\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*(?:,|;|\s)\s*([+-]?(?:\d+(?:\.\d+)?|\.\d+))\s*$',
  );

  static CoordinatePair? parse(String raw) {
    final normalized = raw.replaceAll('\u2212', '-');
    final match = _pairPattern.firstMatch(normalized);
    if (match == null) return null;

    final latitude = double.tryParse(match.group(1) ?? '');
    final longitude = double.tryParse(match.group(2) ?? '');
    if (latitude == null || longitude == null) return null;
    if (!latitude.isFinite || !longitude.isFinite) return null;
    if (latitude < -90 || latitude > 90) return null;
    if (longitude < -180 || longitude > 180) return null;

    return CoordinatePair(latitude: latitude, longitude: longitude);
  }
}
