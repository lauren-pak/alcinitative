import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models/media.dart';
import '../services/services.dart';

/// A photo (or video thumbnail) from Cloud Storage, fetched through the
/// security rules.
class StorageImage extends StatelessWidget {
  const StorageImage({super.key, required this.path, this.fit = BoxFit.cover});

  final String path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder(
      future: Services.media.imageBytes(path),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return Image.memory(snapshot.data!, fit: fit, gaplessPlayback: true);
        }
        return ColoredBox(
          color: scheme.surfaceContainerHighest,
          child: Center(
            child: snapshot.hasError
                ? Icon(Icons.broken_image_outlined,
                    color: scheme.onSurfaceVariant)
                : const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
          ),
        );
      },
    );
  }
}

String _duration(int? ms) {
  final s = ((ms ?? 0) / 1000).round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// Video thumbnail with a play badge and its length.
class VideoPreview extends StatelessWidget {
  const VideoPreview({super.key, required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        StorageImage(path: item.previewPath),
        const Center(
          child: CircleAvatar(
            radius: 26,
            backgroundColor: Colors.black54,
            child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
          ),
        ),
        Positioned(
          right: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _duration(item.durationMs),
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}

/// Media on a feed card: one photo or video wide, or a grid of up to four.
class MediaPreviewGrid extends StatelessWidget {
  const MediaPreviewGrid({super.key, required this.media});

  final List<MediaItem> media;

  Widget _tile(MediaItem m) => m.kind == MediaKind.video
      ? VideoPreview(item: m)
      : StorageImage(path: m.path);

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();
    final Widget content;
    if (media.length == 1) {
      content = AspectRatio(
        aspectRatio: media.first.aspectRatio.clamp(0.8, 1.9),
        child: _tile(media.first),
      );
    } else {
      content = GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: [for (final m in media) _tile(m)],
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: content);
  }
}

/// Full-width media on the post page; videos play inline when tapped.
class PostMediaView extends StatelessWidget {
  const PostMediaView({super.key, required this.media});

  final List<MediaItem> media;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final m in media)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: m.aspectRatio,
                child: m.kind == MediaKind.video
                    ? InlineVideo(item: m)
                    : StorageImage(path: m.path, fit: BoxFit.contain),
              ),
            ),
          ),
      ],
    );
  }
}

/// Shows the thumbnail until tapped, then downloads and plays the video.
class InlineVideo extends StatefulWidget {
  const InlineVideo({super.key, required this.item});

  final MediaItem item;

  @override
  State<InlineVideo> createState() => _InlineVideoState();
}

class _InlineVideoState extends State<InlineVideo> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _failed = false;

  Future<void> _start() async {
    setState(() => _loading = true);
    try {
      final file = await Services.media.videoFile(widget.item.path);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(() => mounted ? setState(() {}) : null);
      await controller.play();
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return GestureDetector(
        onTap: _loading ? null : _start,
        child: Stack(
          fit: StackFit.expand,
          children: [
            VideoPreview(item: widget.item),
            if (_loading)
              const ColoredBox(
                color: Colors.black26,
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_failed)
              const Center(
                child: Text("Couldn't play this video",
                    style: TextStyle(color: Colors.white)),
              ),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => controller.value.isPlaying
          ? controller.pause()
          : controller.play(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(controller),
          if (!controller.value.isPlaying)
            const Center(
              child: CircleAvatar(
                radius: 26,
                backgroundColor: Colors.black54,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 32),
              ),
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: VideoProgressIndicator(controller, allowScrubbing: true),
          ),
        ],
      ),
    );
  }
}
