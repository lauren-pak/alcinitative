import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/account.dart';
import '../../models/media.dart';
import '../../models/post.dart';
import '../../models/sign_up_data.dart';
import '../../services/media_prep.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';
import '../../widgets/safety_widgets.dart';
import '../../widgets/tag_widgets.dart';

/// Write an experience or a question, optionally with photos or a video, or
/// in response to another post. Pops with the created [Post].
class ComposePostScreen extends StatefulWidget {
  const ComposePostScreen({
    super.key,
    required this.account,
    this.respondingTo,
    this.initialVideo,
    this.initialPhotos = const [],
    this.initialType,
    this.prompt,
  });

  final Account account;

  /// Answering this week's Huddle question (always a spotlight).
  final WeeklyPrompt? prompt;

  /// Start as a Spotlight or an "Ask an athlete" question.
  final PostType? initialType;

  /// Captured on the camera screen, already cleaned.
  final PreparedVideo? initialVideo;
  final List<PreparedPhoto> initialPhotos;

  /// The post this one responds to; it will also appear in its comments.
  final Post? respondingTo;

  @override
  State<ComposePostScreen> createState() => _ComposePostScreenState();
}

class _ComposePostScreenState extends State<ComposePostScreen> {
  static const _minLength = 10;

  final _draft = NewPost();
  final _picker = ImagePicker();
  List<Journey> _journeys = [];
  final List<PreparedPhoto> _photos = [];
  PreparedVideo? _video;
  bool _preparingMedia = false;
  bool _posting = false;
  String? _progress;
  String? _error;

  Account get _account => widget.account;
  bool get _isAthlete => _account.profile.role == UserRole.athlete;
  bool get _isMinor => FeedRules.isMinor(_account);
  bool get _hasMedia => _video != null || _photos.isNotEmpty;

  /// A caption can be short when there's a video or photo.
  int get _requiredLength => _hasMedia ? 1 : _minLength;

  @override
  void initState() {
    super.initState();
    final types = FeedRules.postTypesFor(_account);
    _draft.type = types.contains(widget.initialType)
        ? widget.initialType!
        : types.first;
    _video = widget.initialVideo;
    _photos.addAll(widget.initialPhotos);
    if (widget.prompt case final prompt?) {
      _draft
        ..prompt = prompt
        ..type = PostType.experience;
    }
    final target = widget.respondingTo;
    if (target != null) {
      _draft
        ..respondingTo = target
        ..topic = target.topic;
    }
    if (_isAthlete) _loadJourneys();
  }

  void _showError(String message) {
    setState(() => _error = message);
    // The form is long, so also show the problem where it can be seen.
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhotos() async {
    final room = maxPhotosPerPost - _photos.length;
    if (room <= 0) return;
    // requestFullMetadata: false avoids asking for full library access; the
    // photos are cleaned of all metadata below either way.
    final picked = await _picker.pickMultiImage(
      limit: room,
      maxWidth: 2048,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _preparingMedia = true);
    try {
      for (final file in picked.take(room)) {
        final cleaned = await cleanPhotoInBackground(await file.readAsBytes());
        if (!mounted) return;
        setState(() => _photos.add(cleaned));
      }
    } catch (_) {
      if (mounted) _showError("Couldn't add that photo. Try a different one.");
    } finally {
      if (mounted) setState(() => _preparingMedia = false);
    }
  }

  Future<void> _addVideo() async {
    final picked = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: maxVideoDuration,
    );
    if (picked == null || !mounted) return;
    setState(() => _preparingMedia = true);
    try {
      final video = await prepareVideo(picked.path);
      if (!mounted) return;
      if (video.durationMs > maxVideoDuration.inMilliseconds + 1000) {
        _showError(
          'Videos can be up to ${maxVideoDuration.inSeconds} '
          'seconds long. Trim it in Photos first.',
        );
        return;
      }
      setState(() => _video = video);
    } catch (_) {
      if (mounted) _showError("Couldn't add that video. Try a different one.");
    } finally {
      if (mounted) setState(() => _preparingMedia = false);
    }
  }

  /// Uploads the picked media, returning the items to attach to the post.
  Future<List<MediaItem>> _uploadMedia() async {
    final media = Services.media;
    final items = <MediaItem>[];
    final total = _photos.length + (_video == null ? 0 : 1);
    for (final photo in _photos) {
      setState(() => _progress = 'Uploading ${items.length + 1} of $total…');
      items.add(await media.uploadPhoto(_account, photo));
    }
    if (_video case final video?) {
      setState(() => _progress = 'Uploading video…');
      items.add(await media.uploadVideo(_account, video));
    }
    return items;
  }

  Future<void> _loadJourneys() async {
    try {
      final journeys = await Services.feed.myJourneys(_account);
      if (mounted) setState(() => _journeys = journeys);
    } catch (_) {
      // Journeys are optional; posting still works without them.
    }
  }

  Future<void> _newJourney() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('New journey'),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 60,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'e.g. ACL rehab 2026',
              helperText: 'Tag posts into it, like a playlist.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
    if (title == null || title.isEmpty || !mounted) return;
    try {
      final journey = await Services.feed.createJourney(_account, title);
      if (!mounted) return;
      setState(() {
        _journeys = [journey, ..._journeys];
        _draft.journey = journey;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't create the journey.")),
        );
      }
    }
  }

  Future<void> _post() async {
    FocusScope.of(context).unfocus();
    final topic = _draft.topic;
    String? error;
    if (topic == null) {
      error = 'Choose a topic';
    } else if (_draft.text.trim().length < _requiredLength) {
      error = _hasMedia
          ? 'Add a few words about it'
          : 'Write at least $_minLength characters';
    }
    if (error != null) {
      _showError(error);
      return;
    }
    if (FeedRules.flagged(_draft.text, _draft.tags) &&
        !await confirmFlaggedPost(context)) {
      return;
    }
    if (!mounted) return;

    setState(() {
      _posting = true;
      _error = null;
    });
    try {
      _draft.media = await _uploadMedia();
      if (!mounted) return;
      setState(() => _progress = 'Posting…');
      final post = await Services.feed.createPost(_account, _draft);
      if (mounted) Navigator.of(context).pop(post);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _posting = false;
        _progress = null;
      });
      _showError("Couldn't post. Check your connection and try again.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isQuestion = _draft.type == PostType.question;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.respondingTo != null
              ? 'Respond with a post'
              : _isAthlete
              ? 'New post'
              : 'Ask a question',
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _posting ? null : _post,
              child: const Text('Post'),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: AbsorbPointer(
          absorbing: _posting,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.prompt case final prompt?) ...[
                PromptLine(text: prompt.text),
                const SizedBox(height: 16),
              ],
              if (widget.respondingTo case final target?) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RespondsToLine(text: target.text),
                      const SizedBox(height: 4),
                      Text(
                        'Your post will also appear in its comments.',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_isAthlete)
                SegmentedButton<PostType>(
                  segments: const [
                    ButtonSegment(
                      value: PostType.experience,
                      icon: Icon(Icons.auto_stories_outlined),
                      label: Text('Share a spotlight'),
                    ),
                    ButtonSegment(
                      value: PostType.question,
                      icon: Icon(Icons.help_outline),
                      label: Text('Ask a question'),
                    ),
                  ],
                  selected: {_draft.type},
                  onSelectionChanged: (s) =>
                      setState(() => _draft.type = s.first),
                )
              else
                Text(
                  'Ask athletes for advice. Your question will be labelled '
                  '"Question from the public".',
                  style: textTheme.bodyMedium,
                ),
              const SizedBox(height: 20),
              Text('Topic', style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final topic in Topic.values)
                    ChoiceChip(
                      avatar: Icon(topicIcon(topic), size: 18),
                      label: Text(topic.label),
                      selected: _draft.topic == topic,
                      onSelected: (_) => setState(() {
                        _draft.topic = topic;
                        _error = null;
                      }),
                    ),
                ],
              ),
              if (isQuestion) ...[
                const SizedBox(height: 12),
                const AdviceBanner(compact: true),
              ],
              const SizedBox(height: 20),
              TextField(
                minLines: 5,
                maxLines: 12,
                maxLength: maxPostLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: _hasMedia
                      ? 'Caption'
                      : isQuestion
                      ? 'Your question'
                      : 'Your spotlight',
                  hintText: isQuestion
                      ? 'What would you like advice on?'
                      : _hasMedia
                      ? 'Say something about it'
                      : 'What happened, and what did you learn?',
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() {
                  _draft.text = v;
                  _error = null;
                }),
              ),
              const SizedBox(height: 4),
              _MediaPicker(
                photos: _photos,
                video: _video,
                busy: _preparingMedia,
                videoNote: FeedRules.videoReviewNoteFor(_account),
                onAddPhotos: _addPhotos,
                onAddVideo: _addVideo,
                onRemovePhoto: (i) => setState(() => _photos.removeAt(i)),
                onRemoveVideo: () => setState(() => _video = null),
              ),
              const SizedBox(height: 16),
              TagEditor(
                tags: _draft.tags,
                onChanged: (tags) => setState(() => _draft.tags = tags),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ReplyPolicy>(
                initialValue: _draft.replyPolicy,
                decoration: InputDecoration(
                  labelText: 'Who can reply',
                  helperText: _isMinor && !_draft.adultRepliesAllowed
                      ? 'Only other under-18s can reply to your posts.'
                      : null,
                  border: const OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ReplyPolicy.athletes,
                    child: Text('Athletes'),
                  ),
                  DropdownMenuItem(
                    value: ReplyPolicy.everyone,
                    child: Text('Everyone, including the public'),
                  ),
                  DropdownMenuItem(
                    value: ReplyPolicy.none,
                    child: Text('No replies'),
                  ),
                ],
                onChanged: (v) => setState(() => _draft.replyPolicy = v!),
              ),
              if (_isMinor)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.adultRepliesAllowed,
                  onChanged: (v) =>
                      setState(() => _draft.adultRepliesAllowed = v),
                  title: const Text('Let adults reply'),
                  subtitle: const Text(
                    "Off unless you turn it on. Adults' replies are checked "
                    'by a moderator before anyone sees them.',
                  ),
                ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _draft.anonymous,
                onChanged: (v) => setState(() => _draft.anonymous = v),
                title: const Text('Post anonymously'),
                subtitle: const Text(
                  "Other members won't see your name. Moderators can still "
                  'see who posted, to keep everyone safe.',
                ),
              ),
              if (_isAthlete && !_draft.anonymous) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  // Rebuilt when a journey is created, to show it selected.
                  key: ValueKey('${_draft.journey?.id}-${_journeys.length}'),
                  initialValue: _draft.journey?.id ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Add to a journey (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(value: '', child: Text('None')),
                    for (final j in _journeys)
                      DropdownMenuItem(value: j.id, child: Text(j.title)),
                    const DropdownMenuItem(
                      value: '+new',
                      child: Text('+ New journey…'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == '+new') {
                      _newJourney();
                      return;
                    }
                    setState(
                      () => _draft.journey = v == null || v.isEmpty
                          ? null
                          : _journeys.firstWhere((j) => j.id == v),
                    );
                  },
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: TextStyle(color: scheme.error)),
              ],
              if (_posting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
                if (_progress != null) ...[
                  const SizedBox(height: 8),
                  Center(child: Text(_progress!, style: textTheme.bodySmall)),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Add-photos and add-video buttons, with removable previews.
class _MediaPicker extends StatelessWidget {
  const _MediaPicker({
    required this.photos,
    required this.video,
    required this.busy,
    required this.videoNote,
    required this.onAddPhotos,
    required this.onAddVideo,
    required this.onRemovePhoto,
    required this.onRemoveVideo,
  });

  final List<PreparedPhoto> photos;
  final PreparedVideo? video;
  final bool busy;

  /// Shown when videos will be reviewed (under-18s).
  final String? videoNote;
  final VoidCallback onAddPhotos;
  final VoidCallback onAddVideo;
  final ValueChanged<int> onRemovePhoto;
  final VoidCallback onRemoveVideo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final canAddPhotos =
        !busy && video == null && photos.length < maxPhotosPerPost;
    final canAddVideo = !busy && video == null && photos.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: canAddPhotos ? onAddPhotos : null,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(
                photos.isEmpty
                    ? 'Add photos'
                    : 'Photos ${photos.length}/$maxPhotosPerPost',
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: canAddVideo ? onAddVideo : null,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Add video'),
            ),
            if (busy) ...[
              const SizedBox(width: 12),
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ],
        ),
        Text(
          'Up to $maxPhotosPerPost photos or one video '
          '(${maxVideoDuration.inSeconds}s). Location data is removed.',
          style: textTheme.bodySmall,
        ),
        if (videoNote != null) Text(videoNote!, style: textTheme.bodySmall),
        if (photos.isNotEmpty || video != null) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (var i = 0; i < photos.length; i++)
                  _Thumb(
                    image: Image.memory(
                      Uint8List.fromList(photos[i].jpeg),
                      fit: BoxFit.cover,
                    ),
                    onRemove: () => onRemovePhoto(i),
                  ),
                if (video case final v?)
                  _Thumb(
                    image: Image.file(File(v.thumbnailPath), fit: BoxFit.cover),
                    isVideo: true,
                    onRemove: onRemoveVideo,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.image,
    required this.onRemove,
    this.isVideo = false,
  });

  final Widget image;
  final VoidCallback onRemove;
  final bool isVideo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(
          dimension: 88,
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (isVideo)
                const Center(
                  child: Icon(Icons.play_circle, color: Colors.white, size: 32),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton.filledTonal(
                  tooltip: 'Remove',
                  visualDensity: VisualDensity.compact,
                  iconSize: 16,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
