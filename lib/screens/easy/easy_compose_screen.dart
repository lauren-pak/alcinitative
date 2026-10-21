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
import '../feed/capture_screen.dart';
import 'easy_widgets.dart';

enum _Step { topic, kind, write, tags, check }

/// Easy mode posting, one question per screen: topic → share or ask →
/// camera (video first; photo or just words also possible) → write →
/// check and post. Advanced options use safe
/// defaults: replies from athletes, not anonymous, no journey.
/// Pops with the created [Post].
///
/// With [respondingTo] it answers another post: the topic comes from that
/// post, so it goes straight to the camera, then words, then check.
class EasyComposeScreen extends StatefulWidget {
  const EasyComposeScreen({
    super.key,
    required this.account,
    this.initialVideo,
    this.initialPhotos = const [],
    this.respondingTo,
  });

  final Account account;
  final Post? respondingTo;

  /// Captured on the camera screen, already cleaned.
  final PreparedVideo? initialVideo;
  final List<PreparedPhoto> initialPhotos;

  @override
  State<EasyComposeScreen> createState() => _EasyComposeScreenState();
}

class _EasyComposeScreenState extends State<EasyComposeScreen> {
  final _draft = NewPost();
  final _photos = <PreparedPhoto>[];
  PreparedVideo? _video;
  final _text = TextEditingController();

  bool get _hasMedia => _video != null || _photos.isNotEmpty;
  _Step _step = _Step.topic;
  bool _working = false;

  Account get _account => widget.account;

  /// General public members can only ask, so they skip that question.
  /// Answers to a post skip both questions.
  List<_Step> get _steps => widget.respondingTo != null
      ? const [_Step.write, _Step.tags, _Step.check]
      : FeedRules.postTypesFor(_account).length > 1
      ? _Step.values
      : const [_Step.topic, _Step.write, _Step.tags, _Step.check];

  int get _index => _steps.indexOf(_step);

  @override
  void initState() {
    super.initState();
    _draft.type = FeedRules.postTypesFor(_account).first;
    _video = widget.initialVideo;
    _photos.addAll(widget.initialPhotos);
    if (widget.respondingTo case final target?) {
      _draft
        ..respondingTo = target
        ..topic = target.topic;
      _step = _Step.write;
      // Video first, as for any new post. Closing it leaves just words.
      if (!_hasMedia) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openCamera();
        });
      }
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _go(int delta) async {
    final next = _index + delta;
    if (next < 0) {
      Navigator.of(context).pop();
      return;
    }
    FocusScope.of(context).unfocus();
    // After the topic and share-or-ask questions, open the camera.
    if (delta > 0 && _steps[next] == _Step.write && !_hasMedia) {
      if (!await _openCamera()) return;
    }
    if (mounted) setState(() => _step = _steps[next]);
  }

  /// Returns false if they closed the camera without choosing anything.
  Future<bool> _openCamera() async {
    final captured = await Navigator.of(context).push<CapturedMedia>(
      MaterialPageRoute(
        builder: (_) => CaptureScreen(account: _account, returnMedia: true),
      ),
    );
    if (captured == null || !mounted) return false;
    setState(() {
      _video = captured.video;
      _photos
        ..clear()
        ..addAll(captured.photos);
    });
    return true;
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addPhoto() async {
    final picked = await ImagePicker().pickMultiImage(
      limit: maxPhotosPerPost - _photos.length,
      maxWidth: 2048,
      imageQuality: 90,
      requestFullMetadata: false,
    );
    if (picked.isEmpty || !mounted) return;
    setState(() => _working = true);
    try {
      for (final file in picked) {
        final photo = await cleanPhotoInBackground(await file.readAsBytes());
        if (!mounted) return;
        setState(() => _photos.add(photo));
      }
    } catch (_) {
      if (mounted) _say('That photo did not work. Try another one.');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _post() async {
    if (FeedRules.flagged(_text.text, _draft.tags) &&
        !await confirmFlaggedPost(context)) {
      return;
    }
    if (!mounted) return;
    setState(() => _working = true);
    try {
      _draft
        ..text = _text.text.trim()
        ..media = [
          for (final photo in _photos)
            await Services.media.uploadPhoto(_account, photo),
          if (_video case final video?)
            await Services.media.uploadVideo(_account, video),
        ];
      final post = await Services.feed.createPost(_account, _draft);
      if (mounted) Navigator.of(context).pop(post);
    } catch (_) {
      if (!mounted) return;
      setState(() => _working = false);
      _say('Your post did not send. Check the internet and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final last = _index == _steps.length - 1;
    final canGoOn = switch (_step) {
      _Step.topic => _draft.topic != null,
      _Step.kind => true,
      _Step.write => _text.text.trim().length >= (_hasMedia ? 1 : 3),
      _Step.tags => true,
      _Step.check => !_working,
    };

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: _working ? null : () => _go(-1)),
        title: Text('Step ${_index + 1} of ${_steps.length}'),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(value: (_index + 1) / _steps.length),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    switch (_step) {
                      _Step.topic => _topicStep(textTheme),
                      _Step.kind => _kindStep(textTheme),
                      _Step.write => _writeStep(textTheme),
                      _Step.tags => _tagsStep(textTheme),
                      _Step.check => _checkStep(textTheme),
                    },
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: canGoOn ? (last ? _post : () => _go(1)) : null,
                    child: _working && last
                        ? const CircularProgressIndicator()
                        : Text(last ? 'Post it' : 'Next'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topicStep(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What is your post about?', style: textTheme.headlineSmall),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.2,
          children: [
            for (final topic in Topic.values)
              EasyTile(
                icon: topicIcon(topic),
                label: easyTopicLabel(topic),
                selected: _draft.topic == topic,
                onTap: () => setState(() => _draft.topic = topic),
              ),
          ],
        ),
        if (_draft.topic != null &&
            FeedRules.topicReviewNoteFor(_account, _draft.topic!) != null) ...[
          const SizedBox(height: 12),
          const EasyNote(
            text:
                'A helper will check your post about food before others '
                'see it.',
            icon: Icons.verified_user_outlined,
          ),
        ],
      ],
    );
  }

  Widget _kindStep(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('What do you want to do?', style: textTheme.headlineSmall),
        const SizedBox(height: 16),
        SizedBox(
          height: 160,
          child: Row(
            children: [
              Expanded(
                child: EasyTile(
                  icon: Icons.auto_stories_outlined,
                  label: 'Share my story',
                  selected: _draft.type == PostType.experience,
                  onTap: () =>
                      setState(() => _draft.type = PostType.experience),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: EasyTile(
                  icon: Icons.help_outline,
                  label: 'Ask a question',
                  selected: _draft.type == PostType.question,
                  onTap: () => setState(() => _draft.type = PostType.question),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _writeStep(TextTheme textTheme) {
    final asking = _draft.type == PostType.question;
    final target = widget.respondingTo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target != null) ...[
          _AnsweringNote(post: target),
          const SizedBox(height: 16),
        ],
        Text(
          _video != null
              ? 'Say something about your video'
              : target != null
              ? 'Write your answer'
              : asking
              ? 'Write your question'
              : 'Write your story',
          style: textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        if (target != null && !_hasMedia) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _openCamera,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record a video'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_video case final video?) ...[
          _VideoThumb(video: video),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working ? null : _openCamera,
              icon: const Icon(Icons.videocam_outlined),
              label: const Text('Record again'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _text,
          minLines: 4,
          maxLines: 10,
          maxLength: maxPostLength,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: asking ? 'What do you want to know?' : 'What happened?',
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (_video == null)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _working || _photos.length >= maxPhotosPerPost
                  ? null
                  : _addPhoto,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(
                _photos.isEmpty ? 'Add a photo' : 'Add another photo',
              ),
            ),
          ),
        if (_working) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PhotoRow(
            photos: _photos,
            onRemove: (i) => setState(() => _photos.removeAt(i)),
          ),
        ],
      ],
    );
  }

  /// Easy tag ideas for each topic.
  static const _tagIdeas = {
    Topic.injury: ['knee', 'ankle', 'shoulder', 'rehab', 'recovery'],
    Topic.training: ['strength', 'running', 'stretching', 'teamwork', 'coach'],
    Topic.nutrition: ['water', 'breakfast', 'snacks', 'energy', 'raceday'],
    Topic.competition: ['nerves', 'medal', 'warmup', 'teamwork', 'travel'],
  };

  void _toggleTag(String tag) => setState(() {
    if (_draft.tags.contains(tag)) {
      _draft.tags = [..._draft.tags]..remove(tag);
    } else if (_draft.tags.length < maxTags) {
      _draft.tags = [..._draft.tags, tag];
    }
  });

  Widget _tagsStep(TextTheme textTheme) {
    final ideas = _tagIdeas[_draft.topic] ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add tags?', style: textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Tags help other athletes find your post. You can skip this.',
          style: textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in {...ideas, ..._draft.tags})
              FilterChip(
                label: Text('#$tag'),
                selected: _draft.tags.contains(tag),
                onSelected: (_) => _toggleTag(tag),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Or write your own', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        TagEditor(
          tags: _draft.tags,
          onChanged: (tags) => setState(() => _draft.tags = tags),
        ),
      ],
    );
  }

  Widget _checkStep(TextTheme textTheme) {
    final topic = _draft.topic!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Is this right?', style: textTheme.headlineSmall),
        const SizedBox(height: 16),
        if (widget.respondingTo case final target?) ...[
          _AnsweringNote(post: target),
          const SizedBox(height: 12),
          if (FeedRules.holdReasonFor(_account, _draft) != null) ...[
            const EasyNote(
              text: 'A helper will check your post before others see it.',
              icon: Icons.verified_user_outlined,
            ),
            const SizedBox(height: 12),
          ],
        ] else
          Row(
            children: [
              Icon(topicIcon(topic), size: 32),
              const SizedBox(width: 8),
              Text(easyTopicLabel(topic), style: textTheme.titleMedium),
              const SizedBox(width: 16),
              Text(
                _draft.type == PostType.question ? '❓ Question' : '📖 Story',
                style: textTheme.titleMedium,
              ),
            ],
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(_text.text.trim(), style: textTheme.bodyLarge),
        ),
        if (_video case final video?) ...[
          const SizedBox(height: 12),
          _VideoThumb(video: video),
        ],
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: 12),
          _PhotoRow(photos: _photos),
        ],
        if (_draft.tags.isNotEmpty) ...[
          const SizedBox(height: 12),
          TagChips(tags: _draft.tags),
        ],
        const SizedBox(height: 16),
        const EasyNote(
          text: 'Other athletes will see your name and your post.',
          icon: Icons.visibility_outlined,
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({required this.photos, this.onRemove});

  final List<PreparedPhoto> photos;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < photos.length; i++)
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  Uint8List.fromList(photos[i].jpeg),
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
              if (onRemove != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton.filledTonal(
                    tooltip: 'Remove photo',
                    onPressed: () => onRemove!(i),
                    icon: const Icon(Icons.close),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// The recorded video's first frame with a play badge.
class _VideoThumb extends StatelessWidget {
  const _VideoThumb({required this.video});

  final PreparedVideo video;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.file(
            File(video.thumbnailPath),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
          const CircleAvatar(
            radius: 30,
            backgroundColor: Colors.black54,
            child: Icon(Icons.videocam, color: Colors.white, size: 32),
          ),
        ],
      ),
    );
  }
}

/// "You are answering Sam: …" at the top of an answer.
class _AnsweringNote extends StatelessWidget {
  const _AnsweringNote({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💬 You are answering ${post.authorName}',
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            post.text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}
