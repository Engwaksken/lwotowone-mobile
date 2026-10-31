import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/repository.dart';
import '../theme.dart';
import '../widgets/download_panel.dart';
import '../widgets/media_view.dart';
import '../widgets/ui.dart';

/// One lesson or resource: its text, in-app media, attached files, download
/// request and (for lessons) completion.
class ContentScreen extends StatelessWidget {
  final Repository repo;
  final String type;
  final Object? id;
  final String? subtitle;
  const ContentScreen({
    super.key,
    required this.repo,
    required this.type,
    required this.id,
    this.subtitle,
  });

  Map<String, dynamic>? get item {
    for (final row in repo.rows(type)) {
      if ('${row['id']}' == '$id') return row;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) {
      final current = item;
      if (current == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
            icon: Icons.search_off,
            title: 'This content is no longer available',
          ),
        );
      }
      final lesson = type == 'lessons';
      final completed =
          lesson &&
          repo.rows('lesson_progress').any((p) => '${p['lesson_id']}' == '$id');
      final text = (lesson ? current['body'] : current['content_body'] ?? '')
          .toString()
          .trim();
      final description = lesson
          ? ''
          : (current['description'] ?? '').toString().trim();
      return Scaffold(
        appBar: AppBar(title: Text(lesson ? 'Lesson' : 'Resource')),
        body: PageList(
          onRefresh: repo.sync,
          children: [
            if (subtitle != null)
              Text(
                subtitle!,
                style: const TextStyle(
                  color: Brand.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Text(
              '${current['title'] ?? (lesson ? 'Lesson' : 'Resource')}',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (completed)
                  const StatusChip('Completed', icon: Icons.check_circle),
                if (current['media_type'] != null && current['locked'] != true)
                  StatusChip.neutral(
                    '${current['media_type']}'.toUpperCase(),
                    icon: mediaIcon('${current['media_type']}'),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (current['locked'] == true)
              const NoticeCard(
                icon: Icons.lock_outline,
                warning: true,
                text:
                    'Locked. Finish the earlier lessons, and confirm payment if your trial has ended.',
              )
            else ...[
              if (description.isNotEmpty) ...[
                Text(description, style: const TextStyle(color: Brand.muted)),
                const SizedBox(height: 12),
              ],
              _ContentMedia(repo: repo, type: type, item: current),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 16),
                SelectableText(
                  text,
                  style: const TextStyle(fontSize: 16, height: 1.55),
                ),
              ],
              if (lesson) _Attachments(repo: repo, lesson: current),
              DownloadPanel(repo: repo, type: type, item: current),
              if (lesson) ...[
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: completed || repo.busy
                      ? null
                      : () => runGuarded(context, () async {
                          await repo.act('complete', {
                            'lesson_id': current['id'],
                          }, offlineAllowed: true);
                          if (context.mounted) {
                            showMessage(context, 'Lesson marked complete.');
                          }
                        }),
                  icon: Icon(completed ? Icons.check_circle : Icons.task_alt),
                  label: Text(completed ? 'Completed' : 'Mark lesson complete'),
                ),
              ],
            ],
          ],
        ),
      );
    },
  );
}

class _ContentMedia extends StatelessWidget {
  final Repository repo;
  final String type;
  final Map<String, dynamic> item;
  const _ContentMedia({
    required this.repo,
    required this.type,
    required this.item,
  });

  Future<void> openLink(BuildContext context, String link) =>
      runGuarded(context, () async {
        final uri = Uri.tryParse(link);
        if (uri == null ||
            !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          throw ApiFailure('Could not open the link.', 0);
        }
      });

  @override
  Widget build(BuildContext context) {
    final kind = '${item['media_type'] ?? 'document'}';
    final title = '${item['title'] ?? 'Learning content'}';
    if (repo.hasSavedFile(type, item['id'])) {
      return _SavedMedia(repo: repo, type: type, id: item['id'], title: title);
    }
    final stream = item['download_url']?.toString();
    if (stream != null &&
        stream.isNotEmpty &&
        item['content_source'] != 'url' &&
        item['content_source'] != 'write') {
      return MediaView(repo: repo, kind: kind, title: title, url: stream);
    }
    final link = (item['video_url'] ?? item['content_url'])?.toString();
    if (link != null && link.isNotEmpty) {
      final video = kind == 'video' || item['video_url'] != null;
      return OutlinedButton.icon(
        onPressed: () => openLink(context, link),
        icon: Icon(video ? Icons.smart_display_outlined : Icons.open_in_new),
        label: Text(video ? 'Watch video (uses internet data)' : 'Open link'),
      );
    }
    return const SizedBox.shrink();
  }
}

class _SavedMedia extends StatefulWidget {
  final Repository repo;
  final String type;
  final Object? id;
  final String title;
  const _SavedMedia({
    required this.repo,
    required this.type,
    required this.id,
    required this.title,
  });

  @override
  State<_SavedMedia> createState() => _SavedMediaState();
}

class _SavedMediaState extends State<_SavedMedia> {
  late final saved = widget.repo.savedFile(widget.type, widget.id);

  @override
  Widget build(BuildContext context) => FutureBuilder(
    future: saved,
    builder: (context, snapshot) => snapshot.data == null
        ? const SizedBox(height: 48)
        : MediaView(
            repo: widget.repo,
            kind: mediaKindForName(snapshot.data!.path),
            title: widget.title,
            file: snapshot.data,
          ),
  );
}

/// A lesson's extra files. Their names are always listed; opening or saving
/// them comes with an approved download of the lesson.
class _Attachments extends StatefulWidget {
  final Repository repo;
  final Map<String, dynamic> lesson;
  const _Attachments({required this.repo, required this.lesson});

  @override
  State<_Attachments> createState() => _AttachmentsState();
}

class _AttachmentsState extends State<_Attachments> {
  final Set<String> saving = {};

  @override
  Widget build(BuildContext context) {
    final repo = widget.repo;
    final files = [
      for (final file in widget.lesson['attachments'] as List? ?? const [])
        if (file is Map) file,
    ];
    if (files.isEmpty) return const SizedBox.shrink();
    final approved =
        repo.downloadRequestFor('lessons', widget.lesson['id'])?['state'] ==
        'approved';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Lesson files'),
        for (final file in files)
          Card(
            child: ListTile(
              leading: Icon(
                mediaIcon(mediaKindForName('${file['name']}')),
                color: Brand.green,
              ),
              title: Text('${file['name']}'),
              subtitle: Text(
                repo.hasSavedFile('attachments', file['id'])
                    ? 'Saved in the app'
                    : approved
                    ? 'Included in your approved download'
                    : 'Available after your download request is approved',
              ),
              trailing: saving.contains('${file['id']}')
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : repo.hasSavedFile('attachments', file['id'])
                  ? const Icon(Icons.chevron_right)
                  : approved
                  ? const Icon(Icons.download)
                  : const Icon(Icons.lock_outline, size: 18),
              onTap: () async {
                final id = file['id'];
                if (!repo.hasSavedFile('attachments', id)) {
                  if (!approved) return;
                  setState(() => saving.add('$id'));
                  await runGuarded(
                    context,
                    () => repo.saveApprovedAttachment(widget.lesson['id'], id),
                  );
                  if (mounted) setState(() => saving.remove('$id'));
                }
                final saved = await repo.savedFile('attachments', id);
                if (saved == null || !context.mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: Text('${file['name']}')),
                      body: PageList(
                        children: [
                          MediaView(
                            repo: repo,
                            kind: mediaKindForName('${file['name']}'),
                            title: '${file['name']}',
                            file: saved,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
