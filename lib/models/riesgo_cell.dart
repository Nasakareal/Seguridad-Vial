class RiesgoCell {
  final double lat;
  final double lng;
  final String cell;
  final double score;
  final int hechosHist;
  final int jamsNow;
  final int accidentsNow;

  const RiesgoCell({
    required this.lat,
    required this.lng,
    required this.cell,
    required this.score,
    required this.hechosHist,
    required this.jamsNow,
    required this.accidentsNow,
  });

  static double _toD(dynamic v) {
    final n = (v is num) ? v.toDouble() : double.tryParse('$v');
    return n ?? 0.0;
  }

  static int _toI(dynamic v) {
    final n = (v is num) ? v.toInt() : int.tryParse('$v');
    return n ?? 0;
  }

  factory RiesgoCell.fromJson(Map<String, dynamic> j) {
    return RiesgoCell(
      lat: _toD(j['lat']),
      lng: _toD(j['lng']),
      cell: (j['cell'] ?? '').toString(),
      score: _toD(j['score']),
      hechosHist: _toI(j['hechos_hist']),
      jamsNow: _toI(j['jams_now']),
      accidentsNow: _toI(j['accidents_now']),
    );
  }
}
