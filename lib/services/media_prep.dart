import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

import '../models/media.dart';

/// Resizes a photo and re-encodes it as a JPEG with **no metadata**, which
/// removes GPS location, camera details and timestamps (PDPC children's
/// guidelines: don't collect precise location). Pure Dart, so it's tested.
PreparedPhoto cleanPhoto(Uint8List original, {int maxSide = 1600}) {
  final decoded = img.decodeImage(original);
  if (decoded == null) throw const FormatException('Not a supported image');
  // Apply the camera's rotation before dropping the metadata that holds it.
  var image = img.bakeOrientation(decoded);
  final longest = max(image.width, image.height);
  if (longest > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(image, width: maxSide)
        : img.copyResize(image, height: maxSide);
  }
  image.exif = img.ExifData();
  return PreparedPhoto(
    jpeg: img.encodeJpg(image, quality: 85),
    width: image.width,
    height: image.height,
  );
}

/// [cleanPhoto] on a background isolate, so big photos don't freeze the UI.
Future<PreparedPhoto> cleanPhotoInBackground(Uint8List original) =>
    compute(cleanPhoto, original);

const _videoChannel = MethodChannel('athlete_app/video_prep');

/// Re-exports a picked video as MP4 using Apple's "for sharing" metadata
/// filter (removes location and personal details) and makes a thumbnail.
/// Native code: `VideoPrep` in `ios/Runner/AppDelegate.swift`.
Future<PreparedVideo> prepareVideo(String path) async {
  if (defaultTargetPlatform != TargetPlatform.iOS) {
    throw UnsupportedError("Videos can't be added on this device yet.");
  }
  final result = await _videoChannel
      .invokeMapMethod<String, Object?>('prepare', {'path': path});
  if (result == null) throw StateError('Video preparation returned nothing');
  return PreparedVideo(
    path: result['path']! as String,
    thumbnailPath: result['thumbnailPath']! as String,
    width: (result['width'] as num?)?.toInt() ?? 0,
    height: (result['height'] as num?)?.toInt() ?? 0,
    durationMs: (result['durationMs'] as num?)?.toInt() ?? 0,
  );
}
