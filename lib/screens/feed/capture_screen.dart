import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/account.dart';
import '../../models/display_mode.dart';
import '../../models/media.dart';
import '../../models/post.dart';
import '../../services/media_prep.dart';
import '../easy/easy_compose_screen.dart';
import 'compose_post_screen.dart';

enum CaptureMode {
  video('Video', Icons.videocam),
  photo('Photo', Icons.photo_camera),
  text('Text', Icons.notes);

  const CaptureMode(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// What the camera screen hands back in [CaptureScreen.returnMedia] mode.
/// Both empty means "just words".
class CapturedMedia {
  const CapturedMedia({this.video, this.photos = const []});

  final PreparedVideo? video;
  final List<PreparedPhoto> photos;
}

/// Where new posts start: a camera, front-facing and ready to record a
/// casual video. Members can switch to a photo or a text-only post.
///
/// Normally, after capturing it opens the composer and pops with the created
/// [Post]. With [returnMedia] (used by the Easy posting guide, which asks the
/// topic first) it pops with a [CapturedMedia] instead.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({
    super.key,
    required this.account,
    this.respondingTo,
    this.returnMedia = false,
    this.prompt,
  });

  final Account account;
  final Post? respondingTo;

  /// Answering this week's Huddle question.
  final WeeklyPrompt? prompt;
  final bool returnMedia;

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final _picker = ImagePicker();
  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  late CaptureMode _mode;
  String? _cameraProblem;
  bool _recording = false;
  bool _busy = false;
  int _seconds = 0;
  Timer? _timer;

  /// Under-18s can record, but a moderator checks the video first.
  String? get _videoNote => FeedRules.videoReviewNoteFor(widget.account);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Video first, for everyone.
    _mode = CaptureMode.video;
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The camera must be released when the app goes to the background.
    if (state == AppLifecycleState.inactive) {
      _stopTimer();
      _camera?.dispose();
      setState(() {
        _camera = null;
        _recording = false;
      });
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  Future<void> _startCamera({CameraDescription? use}) async {
    try {
      // Never leave people stuck on a spinner if the camera doesn't answer.
      if (_cameras.isEmpty) {
        _cameras = await availableCameras().timeout(const Duration(seconds: 5));
      }
      if (_cameras.isEmpty) {
        setState(() => _cameraProblem = 'No camera found on this device.');
        return;
      }
      final description =
          use ??
          _cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => _cameras.first,
          );
      final controller = CameraController(
        description,
        ResolutionPreset.high,
        enableAudio: _mode == CaptureMode.video,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _camera?.dispose();
      setState(() {
        _camera = controller;
        _cameraProblem = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _cameraProblem = e.code.contains('AccessDenied')
            ? 'Camera access is off. Turn it on in Settings, or use your '
                  'library.'
            : "The camera couldn't start.",
      );
    } catch (_) {
      // e.g. no camera plugin (simulator, tests).
      if (mounted) {
        setState(() => _cameraProblem = 'No camera found on this device.');
      }
    }
  }

  Future<void> _flip() async {
    final current = _camera?.description;
    if (current == null || _cameras.length < 2 || _recording) return;
    final next = _cameras.firstWhere(
      (c) => c.lensDirection != current.lensDirection,
      orElse: () => current,
    );
    await _startCamera(use: next);
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _toggleRecording() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    if (_recording) {
      _stopTimer();
      final file = await camera.stopVideoRecording();
      setState(() => _recording = false);
      await _useVideo(file.path);
      return;
    }
    await camera.startVideoRecording();
    setState(() {
      _recording = true;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= maxVideoDuration.inSeconds) _toggleRecording();
    });
  }

  Future<void> _takePhoto() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() => _busy = true);
    try {
      final file = await camera.takePicture();
      final photo = await cleanPhotoInBackground(await file.readAsBytes());
      await _compose(photos: [photo]);
    } catch (_) {
      _say("Couldn't take the photo. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromLibrary() async {
    if (_busy) return;
    if (_mode == CaptureMode.video) {
      final picked = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: maxVideoDuration,
      );
      if (picked != null) await _useVideo(picked.path);
      return;
    }
    final picked = await _picker.pickMultiImage(
      limit: maxPhotosPerPost,
      maxWidth: 2048,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      final photos = [
        for (final f in picked.take(maxPhotosPerPost))
          await cleanPhotoInBackground(await f.readAsBytes()),
      ];
      await _compose(photos: photos);
    } catch (_) {
      _say("Couldn't add those photos. Try different ones.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Strips location from the video, then opens the composer.
  Future<void> _useVideo(String path) async {
    setState(() => _busy = true);
    try {
      final video = await prepareVideo(path);
      if (video.durationMs > maxVideoDuration.inMilliseconds + 1000) {
        _say('Videos can be up to ${maxVideoDuration.inSeconds} seconds.');
        return;
      }
      await _compose(video: video);
    } catch (_) {
      _say("Couldn't use that video. Try again.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _compose({
    PreparedVideo? video,
    List<PreparedPhoto> photos = const [],
  }) async {
    if (widget.returnMedia) {
      Navigator.of(context).pop(CapturedMedia(video: video, photos: photos));
      return;
    }
    final post = await Navigator.of(context).push<Post>(
      MaterialPageRoute(
        builder: (_) => isEasyMode
            ? EasyComposeScreen(
                account: widget.account,
                initialVideo: video,
                initialPhotos: photos,
              )
            : ComposePostScreen(
                account: widget.account,
                respondingTo: widget.respondingTo,
                prompt: widget.prompt,
                initialVideo: video,
                initialPhotos: photos,
              ),
      ),
    );
    if (post != null && mounted) Navigator.of(context).pop(post);
  }

  void _say(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setMode(CaptureMode mode) {
    if (_recording || mode == _mode) return;
    final needsAudioChange =
        (mode == CaptureMode.video) != (_mode == CaptureMode.video);
    setState(() => _mode = mode);
    // Video needs the microphone; photos don't.
    if (needsAudioChange && _camera != null) {
      _startCamera(use: _camera!.description);
    }
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            if (widget.respondingTo != null)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Responding to a post',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: _mode == CaptureMode.text
                      ? _textPanel()
                      : camera != null && camera.value.isInitialized
                      ? _preview(camera)
                      : _noCameraPanel(),
                ),
              ),
            ),
            _controls(),
            _modeSwitcher(),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Row(
      children: [
        IconButton(
          tooltip: 'Close',
          color: Colors.white,
          onPressed: _recording ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
        const Spacer(),
        if (_recording)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_clock(_seconds)} / ${_clock(maxVideoDuration.inSeconds)}',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        const Spacer(),
        IconButton(
          tooltip: 'Switch camera',
          color: Colors.white,
          onPressed: _cameras.length > 1 && !_recording ? _flip : null,
          icon: const Icon(Icons.cameraswitch_outlined),
        ),
      ],
    );
  }

  static String _clock(int s) =>
      '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';

  Widget _preview(CameraController camera) {
    return FittedBox(
      fit: BoxFit.cover,
      child: SizedBox(
        width: camera.value.previewSize?.height ?? 1080,
        height: camera.value.previewSize?.width ?? 1920,
        child: CameraPreview(camera),
      ),
    );
  }

  Widget _noCameraPanel() {
    return ColoredBox(
      color: Colors.white10,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _cameraProblem == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _cameraProblem!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'You can still choose from your library, or write a '
                      'text post.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _textPanel() {
    return ColoredBox(
      color: Colors.white10,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aa',
              style: TextStyle(color: Colors.white, fontSize: 64),
            ),
            const SizedBox(height: 8),
            const Text(
              'Share an experience or ask a question in words.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _compose(),
              icon: const Icon(Icons.edit),
              label: Text(
                widget.returnMedia ? 'Just use words' : 'Write a post',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _controls() {
    if (_mode == CaptureMode.text) return const SizedBox(height: 96);
    final cameraReady = _camera?.value.isInitialized ?? false;
    final isVideo = _mode == CaptureMode.video;
    return SizedBox(
      height: 96,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: 88,
            child: TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              onPressed: _recording || _busy ? null : _fromLibrary,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Library'),
            ),
          ),
          Semantics(
            button: true,
            label: isVideo
                ? (_recording ? 'Stop recording' : 'Start recording')
                : 'Take photo',
            child: GestureDetector(
              onTap: !cameraReady || _busy
                  ? null
                  : (isVideo ? _toggleRecording : _takePhoto),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                ),
                padding: EdgeInsets.all(_recording ? 20 : 4),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: !cameraReady
                        ? Colors.white24
                        : isVideo
                        ? Colors.red
                        : Colors.white,
                    borderRadius: BorderRadius.circular(_recording ? 6 : 40),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: _busy
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _modeSwitcher() {
    final note = _mode == CaptureMode.video ? _videoNote : null;
    return Column(
      children: [
        if (note != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              note,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final mode in CaptureMode.values)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  avatar: Icon(mode.icon, size: 18),
                  label: Text(mode.label),
                  selected: _mode == mode,
                  onSelected: (_) => _setMode(mode),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
