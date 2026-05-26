class TutorialCategory {
  final int id;
  final String nombre;
  final String slug;
  final String descripcion;
  final List<TutorialVideo> tutoriales;

  const TutorialCategory({
    required this.id,
    required this.nombre,
    required this.slug,
    required this.descripcion,
    required this.tutoriales,
  });

  factory TutorialCategory.fromJson(Map<String, dynamic> json) {
    final rawTutoriales = json['tutoriales'];

    return TutorialCategory(
      id: _readInt(json['id']) ?? 0,
      nombre: _readText(json['nombre'] ?? json['name'] ?? json['titulo']),
      slug: _readText(json['slug']),
      descripcion: _readText(json['descripcion'] ?? json['description']),
      tutoriales: rawTutoriales is List
          ? rawTutoriales
                .whereType<Map>()
                .map(
                  (item) =>
                      TutorialVideo.fromJson(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.id > 0 && item.titulo.isNotEmpty)
                .toList()
          : const <TutorialVideo>[],
    );
  }
}

class TutorialVideo {
  final int id;
  final String titulo;
  final String descripcion;
  final String youtubeUrl;
  final String youtubeVideoId;
  final String youtubeEmbedUrl;
  final String youtubeThumbnailUrl;
  final int orden;

  const TutorialVideo({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.youtubeUrl,
    required this.youtubeVideoId,
    required this.youtubeEmbedUrl,
    required this.youtubeThumbnailUrl,
    required this.orden,
  });

  factory TutorialVideo.fromJson(Map<String, dynamic> json) {
    final videoId = _readText(
      json['youtube_video_id'] ?? json['video_id'] ?? json['youtubeVideoId'],
    );
    final thumbnail = _readText(
      json['youtube_thumbnail_url'] ??
          json['thumbnail_url'] ??
          json['youtubeThumbnailUrl'],
    );

    return TutorialVideo(
      id: _readInt(json['id']) ?? 0,
      titulo: _readText(json['titulo'] ?? json['title']),
      descripcion: _readText(json['descripcion'] ?? json['description']),
      youtubeUrl: _readText(
        json['youtube_url'] ?? json['url'] ?? json['youtubeUrl'],
      ),
      youtubeVideoId: videoId,
      youtubeEmbedUrl: _readText(
        json['youtube_embed_url'] ??
            json['embed_url'] ??
            json['youtubeEmbedUrl'],
      ),
      youtubeThumbnailUrl: thumbnail.isNotEmpty
          ? thumbnail
          : (videoId.isEmpty
                ? ''
                : 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'),
      orden: _readInt(json['orden'] ?? json['order']) ?? 0,
    );
  }
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String _readText(dynamic value) => value?.toString().trim() ?? '';
