/// Photos and videos attached to posts.
///
/// Files live in Cloud Storage at `media/{id}.jpg` (photo) or
/// `media/{id}.mp4` plus `media/{id}_thumb.jpg` (video). The owner is
/// recorded privately in `mediaOwners/{id}`, never in the path, so media on
/// anonymous posts can't be traced to the poster.
enum MediaKind { photo, video }

const maxPhotosPerPost = 4;
const maxVideoDuration = Duration(seconds: 60);

class MediaItem {
  const MediaItem({
    required this.id,
    required this.kind,
    required this.width,
    required this.height,
    this.durationMs,
  });

  factory MediaItem.fromMap(Map<String, dynamic> m) => MediaItem(
    id: m['id'] as String,
    kind: m['kind'] == 'video' ? MediaKind.video : MediaKind.photo,
    width: (m['width'] as num?)?.toInt() ?? 0,
    height: (m['height'] as num?)?.toInt() ?? 0,
    durationMs: (m['durationMs'] as num?)?.toInt(),
  );

  final String id;
  final MediaKind kind;
  final int width;
  final int height;
  final int? durationMs;

  /// The photo, or the video file.
  String get path => 'media/$id.${kind == MediaKind.photo ? 'jpg' : 'mp4'}';

  /// Still image shown before a video plays.
  String get previewPath =>
      kind == MediaKind.video ? 'media/${id}_thumb.jpg' : path;

  double get aspectRatio => width > 0 && height > 0 ? width / height : 4 / 3;

  Map<String, Object?> toMap() => {
    'id': id,
    'kind': kind.name,
    'width': width,
    'height': height,
    if (durationMs != null) 'durationMs': durationMs,
  };
}

/// A photo picked on the device, already cleaned (resized, no metadata).
class PreparedPhoto {
  const PreparedPhoto({
    required this.jpeg,
    required this.width,
    required this.height,
  });

  final List<int> jpeg;
  final int width;
  final int height;
}

/// A video picked on the device, re-exported without location metadata.
class PreparedVideo {
  const PreparedVideo({
    required this.path,
    required this.thumbnailPath,
    required this.width,
    required this.height,
    required this.durationMs,
  });

  final String path;
  final String thumbnailPath;
  final int width;
  final int height;
  final int durationMs;
}
