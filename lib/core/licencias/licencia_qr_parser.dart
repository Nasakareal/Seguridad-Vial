class LicenciaQrData {
  final String rawText;
  final String? numeroLicencia;
  final String? nombre;
  final String? tipoLicencia;
  final DateTime? fechaNacimiento;
  final DateTime? expedicion;
  final DateTime? vigencia;
  final bool permanente;

  const LicenciaQrData({
    required this.rawText,
    this.numeroLicencia,
    this.nombre,
    this.tipoLicencia,
    this.fechaNacimiento,
    this.expedicion,
    this.vigencia,
    this.permanente = false,
  });

  bool get hasAnyValue {
    return <String?>[
          numeroLicencia,
          nombre,
          tipoLicencia,
        ].any((value) => (value ?? '').trim().isNotEmpty) ||
        fechaNacimiento != null ||
        expedicion != null ||
        vigencia != null ||
        permanente;
  }
}

class LicenciaQrParser {
  static LicenciaQrData parse(String raw) {
    final rawText = raw.trim();
    if (rawText.isEmpty) {
      return const LicenciaQrData(rawText: '');
    }

    final cleanText = _cleanRaw(rawText);
    final segments = _segments(cleanText);
    final pairs = _extractPairs(cleanText);

    final numero =
        _licenseNumberFromPairs(pairs) ??
        _licenseNumberFromSignedPayload(cleanText) ??
        _licenseNumberFromSegments(segments);
    final nombre = _nameFromPairs(pairs) ?? _nameFromSegments(segments);
    final tipo =
        _licenseTypeFromPairs(pairs) ?? _licenseTypeFromSegments(segments);
    final nacimiento = _birthDateFromPairs(pairs) ?? _birthDate(cleanText);
    final dates = _numericDates(cleanText);
    final vigencia = _vigenciaFromPairs(pairs) ?? _vigenciaFromDates(dates);
    final expedicion =
        _expedicionFromPairs(pairs) ?? _expedicionFromDates(dates, vigencia);
    final permanente =
        _containsPermanente(cleanText) ||
        (vigencia != null && vigencia.year >= 2100);

    return LicenciaQrData(
      rawText: rawText,
      numeroLicencia: numero,
      nombre: nombre,
      tipoLicencia: tipo,
      fechaNacimiento: nacimiento,
      expedicion: expedicion,
      vigencia: permanente ? null : vigencia,
      permanente: permanente,
    );
  }

  static String _cleanRaw(String raw) {
    return raw
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<String> _segments(String raw) {
    return raw
        .split(RegExp(r'(?:/{2,}|\|{2,}|[\n;]+)'))
        .map(_cleanSegment)
        .where((part) => part.isNotEmpty)
        .take(12)
        .toList();
  }

  static String _cleanSegment(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'^[\s:,\-_*]+|[\s:,\-_*]+$'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Map<String, String> _extractPairs(String raw) {
    final pairs = <String, String>{};
    final matches = RegExp(
      r'([A-Za-zÁÉÍÓÚÜÑáéíóúüñ0-9 _\-/\.]{2,45})\s*[:=#]\s*([^|;\n\r/]{1,120})',
      multiLine: true,
    ).allMatches(raw);

    for (final match in matches) {
      final key = _normalizeKey(match.group(1) ?? '');
      final value = _cleanSegment(match.group(2) ?? '');
      if (key.isNotEmpty && value.isNotEmpty) {
        pairs.putIfAbsent(key, () => value);
      }
    }

    return pairs;
  }

  static String? _licenseNumberFromPairs(Map<String, String> pairs) {
    return _pick(pairs, const [
      'numero licencia',
      'número licencia',
      'no licencia',
      'num licencia',
      'licencia',
      'folio licencia',
    ]).let(_normalizeLicenseNumber);
  }

  static String? _licenseNumberFromSignedPayload(String raw) {
    final matches = RegExp(
      r'(?:^|//)([A-Za-z0-9]{6,24})\s*&\s*S\s*=',
    ).allMatches(raw);
    if (matches.isEmpty) return null;

    for (final match in matches.toList().reversed) {
      final value = _normalizeLicenseNumber(match.group(1));
      if (value != null && RegExp(r'[A-Z]').hasMatch(value)) {
        return value;
      }
    }

    return null;
  }

  static String? _licenseNumberFromSegments(List<String> segments) {
    final candidates = <_LicenseNumberCandidate>[];

    for (var i = 0; i < segments.length && i < 8; i += 1) {
      final candidateText = segments[i]
          .split(RegExp(r'&\s*S\s*=', caseSensitive: false))
          .first;
      final value = _normalizeLicenseNumber(candidateText);
      if (value != null) {
        candidates.add(_LicenseNumberCandidate(value, i));
      }
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first.value;
  }

  static String? _normalizeLicenseNumber(String? value) {
    final cleaned = (value ?? '').trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    if (cleaned.length < 5 || cleaned.length > 24) return null;
    if (!RegExp(r'\d').hasMatch(cleaned)) return null;
    return cleaned;
  }

  static String? _nameFromPairs(Map<String, String> pairs) {
    return _pick(pairs, const [
      'nombre',
      'titular',
      'nombre titular',
      'conductor',
      'nombre conductor',
    ]).let(_normalizeName);
  }

  static String? _nameFromSegments(List<String> segments) {
    for (final segment in segments) {
      final name = _normalizeName(segment);
      if (name != null) return name;
    }
    return null;
  }

  static String? _normalizeName(String? value) {
    final text = _cleanSegment(value ?? '');
    if (text.length < 8 || text.length > 80) return null;
    if (RegExp(r'\d').hasMatch(text)) return null;
    final words = text.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (words.length < 2) return null;
    if (!RegExp(r'[A-Za-zÁÉÍÓÚÜÑáéíóúüñ]').hasMatch(text)) return null;
    return text.toUpperCase();
  }

  static String? _licenseTypeFromPairs(Map<String, String> pairs) {
    return _pick(pairs, const [
      'tipo licencia',
      'tipo de licencia',
      'clase licencia',
      'categoria licencia',
      'categoría licencia',
    ]).let(_normalizeLicenseType);
  }

  static String? _licenseTypeFromSegments(List<String> segments) {
    for (final segment in segments.skip(1).take(5)) {
      final type = _normalizeLicenseType(segment);
      if (type != null) return type;
    }
    return null;
  }

  static String? _normalizeLicenseType(String? value) {
    final text = _cleanSegment(value ?? '');
    if (text.isEmpty) return null;
    final upper = _removeAccents(text).toUpperCase();
    if (RegExp(r'^\d{1,2}$').hasMatch(upper)) return null;
    if (_parseSpanishDate(upper) != null || _parseNumericDate(upper) != null) {
      return null;
    }

    const known = <String>[
      'A',
      'B',
      'C',
      'D',
      'E',
      'AUTOMOVILISTA',
      'CHOFER',
      'MOTOCICLISTA',
      'OPERADOR',
      'SERVICIO PUBLICO',
      'PARTICULAR',
      'PERMISO',
    ];

    for (final item in known) {
      if (item.length == 1) {
        if (upper == item) return upper;
        continue;
      }

      if (upper == item || upper.contains(item)) {
        return upper;
      }
    }

    return null;
  }

  static DateTime? _birthDateFromPairs(Map<String, String> pairs) {
    return _pick(pairs, const [
      'fecha nacimiento',
      'fecha de nacimiento',
      'nacimiento',
      'fecha nac',
    ]).let((value) => _parseSpanishDate(value) ?? _parseNumericDate(value));
  }

  static DateTime? _birthDate(String raw) {
    final spanish = _parseSpanishDate(raw);
    if (spanish != null && spanish.year <= DateTime.now().year - 10) {
      return spanish;
    }
    return null;
  }

  static DateTime? _vigenciaFromPairs(Map<String, String> pairs) {
    return _pick(pairs, const [
      'vigencia',
      'fecha vigencia',
      'vence',
      'vencimiento',
      'valida hasta',
      'válida hasta',
    ]).let((value) => _parseSpanishDate(value) ?? _parseNumericDate(value));
  }

  static DateTime? _expedicionFromPairs(Map<String, String> pairs) {
    return _pick(pairs, const [
      'expedicion',
      'expedición',
      'fecha expedicion',
      'fecha expedición',
      'emision',
      'emisión',
    ]).let((value) => _parseSpanishDate(value) ?? _parseNumericDate(value));
  }

  static DateTime? _vigenciaFromDates(List<DateTime> dates) {
    final now = DateTime.now();
    final plausible = dates
        .where((date) => date.year >= now.year - 1 && date.year <= 2100)
        .toList();
    if (plausible.isEmpty) return null;
    plausible.sort();
    return plausible.last;
  }

  static DateTime? _expedicionFromDates(
    List<DateTime> dates,
    DateTime? vigencia,
  ) {
    if (dates.length < 2) return null;
    final beforeVigencia = dates
        .where((date) => vigencia == null || date.isBefore(vigencia))
        .where((date) => date.year >= 1990)
        .toList();
    if (beforeVigencia.isEmpty) return null;
    beforeVigencia.sort();
    return beforeVigencia.first;
  }

  static List<DateTime> _numericDates(String raw) {
    final dates = <DateTime>[];
    final matches = RegExp(
      r'\b(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})\b',
    ).allMatches(raw);
    for (final match in matches) {
      final parsed = _parseNumericDate(match.group(0));
      if (parsed != null) dates.add(parsed);
    }
    return dates;
  }

  static DateTime? _parseSpanishDate(String? raw) {
    final text = _removeAccents(raw ?? '').toUpperCase();
    final match = RegExp(
      r'\b(\d{1,2})[\s|/\-.]+(ENE|FEB|MAR|ABR|MAY|JUN|JUL|AGO|SEP|SEPT|OCT|NOV|DIC)[\s|/\-.]+(\d{2,4})\b',
    ).firstMatch(text);
    if (match == null) return null;

    final day = int.tryParse(match.group(1) ?? '');
    final year = _normalizeYear(match.group(3));
    final month = const <String, int>{
      'ENE': 1,
      'FEB': 2,
      'MAR': 3,
      'ABR': 4,
      'MAY': 5,
      'JUN': 6,
      'JUL': 7,
      'AGO': 8,
      'SEP': 9,
      'SEPT': 9,
      'OCT': 10,
      'NOV': 11,
      'DIC': 12,
    }[match.group(2)];
    return _safeDate(year, month, day);
  }

  static DateTime? _parseNumericDate(String? raw) {
    final match = RegExp(
      r'^(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})$',
    ).firstMatch((raw ?? '').trim());
    if (match == null) return null;

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final year = _normalizeYear(match.group(3));
    return _safeDate(year, month, day);
  }

  static int? _normalizeYear(String? raw) {
    var year = int.tryParse(raw ?? '');
    if (year == null) return null;
    if (year < 100) year += year >= 70 ? 1900 : 2000;
    return year;
  }

  static DateTime? _safeDate(int? year, int? month, int? day) {
    if (year == null || month == null || day == null) return null;
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String? _pick(Map<String, String> pairs, List<String> aliases) {
    final normalizedAliases = aliases.map(_normalizeKey).toList();
    for (final alias in normalizedAliases) {
      final exact = pairs[alias];
      if ((exact ?? '').trim().isNotEmpty) return exact;
    }
    for (final entry in pairs.entries) {
      for (final alias in normalizedAliases) {
        if (entry.key.contains(alias)) return entry.value;
      }
    }
    return null;
  }

  static String _normalizeKey(String value) {
    return _removeAccents(
      value,
    ).toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]+'), '');
  }

  static bool _containsPermanente(String raw) {
    final normalized = _removeAccents(raw).toUpperCase();
    return normalized.contains('PERMANENTE');
  }

  static String _removeAccents(String value) {
    return value
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .replaceAll('Á', 'A')
        .replaceAll('É', 'E')
        .replaceAll('Í', 'I')
        .replaceAll('Ó', 'O')
        .replaceAll('Ú', 'U')
        .replaceAll('Ü', 'U')
        .replaceAll('Ñ', 'N');
  }
}

extension _NullableStringLet on String? {
  T? let<T>(T? Function(String value) fn) {
    final value = this;
    if (value == null || value.trim().isEmpty) return null;
    return fn(value);
  }
}

class _LicenseNumberCandidate {
  final String value;
  final int segmentIndex;

  const _LicenseNumberCandidate(this.value, this.segmentIndex);

  int get score {
    var total = 0;
    final hasLetter = RegExp(r'[A-Z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);

    if (hasLetter && hasDigit) total += 100;
    if (value.length >= 8) total += 20;
    if (segmentIndex >= 3) total += 20;
    if (!hasLetter) total -= 30;
    if (segmentIndex == 0 && !hasLetter) total -= 20;

    return total;
  }
}
