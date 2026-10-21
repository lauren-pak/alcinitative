import 'package:flutter/material.dart';

import '../../models/moderation.dart';
import '../../services/safety_repository.dart';
import '../../services/services.dart';
import '../../widgets/feed_widgets.dart';

/// The review queue: held posts, held replies and open reports. Only
/// accounts in `moderators/{uid}` can open it (the rules refuse others).
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Moderation'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Posts'),
              Tab(text: 'Replies'),
              Tab(text: 'Reports'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _QueueList(load: Services.moderation.heldPosts),
            _QueueList(load: Services.moderation.heldReplies),
            const _ReportList(),
          ],
        ),
      ),
    );
  }
}

class _QueueList extends StatefulWidget {
  const _QueueList({required this.load});

  final Future<List<QueueItem>> Function() load;

  @override
  State<_QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<_QueueList> {
  late Future<List<QueueItem>> _items = widget.load();

  Future<void> _refresh() async {
    final next = widget.load();
    setState(() {
      _items = next;
    });
    await next.catchError((_) => <QueueItem>[]);
  }

  Future<void> _act(QueueItem item, bool approve) async {
    try {
      approve
          ? await Services.moderation.approve(item)
          : await Services.moderation.remove(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(approve ? 'Approved: now visible.' : 'Removed.'),
      ));
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<QueueItem>>(
      future: _items,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('Moderation queue failed: ${snapshot.error}');
          return _message("Couldn't load the queue. Pull to retry.");
        }
        final items = snapshot.data!;
        if (items.isEmpty) return _message('Nothing waiting. 🎉');
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final item in items)
                _ReviewCard(
                  label: item.holdReason?.label ??
                      (item.reportCount >= reportsToHide
                          ? HoldReason.reports.label
                          : 'Held'),
                  author: item.authorName ?? 'Unknown',
                  authorUid: item.authorUid,
                  text: item.text,
                  time: timeAgo(context, item.createdAt),
                  reports: item.reportCount,
                  primary: 'Approve',
                  onPrimary: () => _act(item, true),
                  onRemove: () => _act(item, false),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _message(String text) => RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [Text(text, textAlign: TextAlign.center)],
        ),
      );
}

class _ReportList extends StatefulWidget {
  const _ReportList();

  @override
  State<_ReportList> createState() => _ReportListState();
}

class _ReportListState extends State<_ReportList> {
  late Future<List<Report>> _reports = Services.moderation.openReports();

  Future<void> _refresh() async {
    final next = Services.moderation.openReports();
    setState(() {
      _reports = next;
    });
    await next.catchError((_) => <Report>[]);
  }

  Future<void> _resolve(Report report, bool remove) async {
    try {
      await Services.moderation.resolveReport(report, removeContent: remove);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(remove ? 'Removed and report closed.' : 'Kept. Report closed.'),
      ));
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save. Try again.")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Report>>(
      future: _reports,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          debugPrint('Reports failed: ${snapshot.error}');
        }
        final reports = snapshot.data ?? const <Report>[];
        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (reports.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No open reports. 🎉', textAlign: TextAlign.center),
                ),
              for (final report in reports)
                _ReviewCard(
                  label: '${report.reason.label} · '
                      '${report.isReply ? 'reply' : 'post'}',
                  author: null,
                  text: report.targetText,
                  details: report.details,
                  time: timeAgo(context, report.createdAt),
                  primary: 'Keep',
                  onPrimary: () => _resolve(report, false),
                  onRemove: () => _resolve(report, true),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.label,
    required this.author,
    required this.text,
    required this.time,
    required this.primary,
    required this.onPrimary,
    required this.onRemove,
    this.authorUid,
    this.details = '',
    this.reports = 0,
  });

  final String label;
  final String? author;
  final String? authorUid;
  final String text;
  final String details;
  final String time;
  final int reports;
  final String primary;
  final VoidCallback onPrimary;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: FeedChip(label: label, emphasis: true)),
                Text(time, style: textTheme.bodySmall),
              ],
            ),
            if (author != null) ...[
              const SizedBox(height: 8),
              Text(
                authorUid == null ? author! : '$author · $authorUid',
                style: textTheme.labelMedium,
              ),
            ],
            const SizedBox(height: 8),
            SelectableText(text, style: textTheme.bodyLarge),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Reporter said: $details', style: textTheme.bodySmall),
            ],
            if (reports > 0) ...[
              const SizedBox(height: 4),
              Text('$reports report${reports == 1 ? '' : 's'}',
                  style: textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: scheme.error),
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onPrimary,
                  icon: const Icon(Icons.check),
                  label: Text(primary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
