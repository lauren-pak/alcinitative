import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/account.dart';
import '../models/media.dart';
import 'media_repository.dart';

/// Post media in Cloud Storage (bucket in asia-southeast1), protected by
/// `storage.rules`.
///
/// Upload order: first the private `mediaOwners/{id}` record (the storage
/// rules check it), then the file(s). Each file and record is also listed in
/// the owner's `contributions`, so deleting the account deletes the media.
class FirebaseMediaRepository implements MediaRepository {
  FirebaseMediaRepository({FirebaseFirestore? db, FirebaseStorage? storage})
    : _db = db ?? FirebaseFirestore.instance,
      _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;
  final _imageCache = <String, Future<Uint8List>>{};

  static const _maxImageBytes = 5 * 1024 * 1024;

  /// Records ownership and returns the new media ID.
  Future<String> _claim(
    Account owner,
    MediaKind kind,
    List<String> files,
  ) async {
    final ownerDoc = _db.collection('mediaOwners').doc();
    final contributions = _db
        .collection('users')
        .doc(owner.uid)
        .collection('contributions');
    final batch = _db.batch()
      ..set(ownerDoc, {'uid': owner.uid, 'kind': kind.name})
      ..set(contributions.doc(), {'path': ownerDoc.path});
    for (final file in files) {
      batch.set(contributions.doc(), {
        'path': file.replaceAll('{id}', ownerDoc.id),
        'storage': true,
      });
    }
    await batch.commit();
    return ownerDoc.id;
  }

  @override
  Future<MediaItem> uploadPhoto(Account owner, PreparedPhoto photo) async {
    final id = await _claim(owner, MediaKind.photo, ['media/{id}.jpg']);
    final item = MediaItem(
      id: id,
      kind: MediaKind.photo,
      width: photo.width,
      height: photo.height,
    );
    final bytes = Uint8List.fromList(photo.jpeg);
    await _storage
        .ref(item.path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    _imageCache[item.path] = Future.value(bytes);
    return item;
  }

  @override
  Future<MediaItem> uploadVideo(Account owner, PreparedVideo video) async {
    final id = await _claim(owner, MediaKind.video, [
      'media/{id}.mp4',
      'media/{id}_thumb.jpg',
    ]);
    final item = MediaItem(
      id: id,
      kind: MediaKind.video,
      width: video.width,
      height: video.height,
      durationMs: video.durationMs,
    );
    await _storage
        .ref(item.previewPath)
        .putFile(
          File(video.thumbnailPath),
          SettableMetadata(contentType: 'image/jpeg'),
        );
    await _storage
        .ref(item.path)
        .putFile(File(video.path), SettableMetadata(contentType: 'video/mp4'));
    return item;
  }

  @override
  Future<Uint8List> imageBytes(String path) {
    return _imageCache
        .putIfAbsent(path, () async {
          final data = await _storage.ref(path).getData(_maxImageBytes);
          if (data == null) throw StateError('Image not found: $path');
          return data;
        })
        .catchError((Object e) {
          // Don't cache failures, so the next view retries.
          _imageCache.remove(path);
          throw e;
        });
  }

  @override
  Future<File> videoFile(String path) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/${path.replaceAll('/', '_')}');
    if (await file.exists() && await file.length() > 0) return file;
    await _storage.ref(path).writeToFile(file);
    return file;
  }
}
