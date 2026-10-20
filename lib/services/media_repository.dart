import 'dart:io';
import 'dart:typed_data';

import '../models/account.dart';
import '../models/media.dart';

/// Uploads and fetches post photos and videos. Cloud Storage in the app,
/// in memory in tests.
///
/// Files are only ever fetched through the security rules (members only),
/// never through public download links.
abstract class MediaRepository {
  Future<MediaItem> uploadPhoto(Account owner, PreparedPhoto photo);

  Future<MediaItem> uploadVideo(Account owner, PreparedVideo video);

  /// A photo or video thumbnail, cached in memory.
  Future<Uint8List> imageBytes(String path);

  /// A local copy of a video, for playback.
  Future<File> videoFile(String path);
}
