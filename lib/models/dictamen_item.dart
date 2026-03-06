class DictamenItem {
  final int id;
  final String label;

  final String? numeroDictamen;
  final int? anio;
  final String? nombrePolicia;
  final String? nombreMp;
  final String? area;
  final String? archivoDictamen;
  final int? createdBy;
  final int? updatedBy;

  const DictamenItem({
    required this.id,
    required this.label,
    this.numeroDictamen,
    this.anio,
    this.nombrePolicia,
    this.nombreMp,
    this.area,
    this.archivoDictamen,
    this.createdBy,
    this.updatedBy,
  });
}
