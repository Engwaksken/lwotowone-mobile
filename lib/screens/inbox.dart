import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';

/// Notices from the institute, and work saved on the phone that has not reached the server yet.
class InboxTab extends StatefulWidget {
  final Repository repo;
  const InboxTab({super.key, required this.repo});

  @override
  State<InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<InboxTab> {
  bool showQueue = false;
  Repository get repo => widget.repo;

  Future<void> discard(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard pending work?'),
        content: const Text('This removes the unsent copy on this phone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await runGuarded(context, () => repo.discard(id));
    }
  }

  static String actionLabel(Object? action) => switch ('$action') {
    'complete' => 'Lesson completion',
    'submit' => 'Assignment submission',
    'practice' => 'Practical log',
    'income' => 'Income or expense record',
    _ => '$action',
  };

  @override
  Widget build(BuildContext context) {
    final notices = repo.rows('notifications');
    final unread = notices.where((n) => n['read_at'] == null).length;
    return PageList(
      onRefresh: repo.sync,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text(unread > 0 ? 'Notices ($unread new)' : 'Notices'),
            ),
            ButtonSegment(
              value: true,
              label: Text('Waiting to sync (${repo.pending.length})'),
            ),
          ],
          selected: {showQueue},
          showSelectedIcon: false,
          onSelectionChanged: (value) =>
              setState(() => showQueue = value.first),
        ),
        const SizedBox(height: 12),
        if (!showQueue) ...[
          if (notices.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notices yet',
            ),
          for (final n in notices)
            InfoCard(
              leading: CircleAvatar(
                backgroundColor: n['read_at'] == null
                    ? Brand.green
                    : Brand.greenSoft,
                foregroundColor: n['read_at'] == null
                    ? Colors.white
                    : Brand.green,
                child: const Icon(Icons.campaign_outlined, size: 20),
              ),
              title: '${(n['data'] as Map?)?['title'] ?? 'Notification'}',
              body: '${(n['data'] as Map?)?['body'] ?? ''}',
              action: Row(
                children: [
                  Text(
                    shortDate(n['created_at']),
                    style: const TextStyle(color: Brand.muted, fontSize: 12),
                  ),
                  const Spacer(),
                  if (n['read_at'] == null)
                    TextButton(
                      onPressed: () => runGuarded(
                        context,
                        () => repo.readNotice('${n['id']}'),
                      ),
                      child: const Text('Mark read'),
                    ),
                ],
              ),
            ),
        ] else ...[
          const Text(
            'Work is kept on this phone until the server accepts it. Items that need changes stay here with the server’s message.',
            style: TextStyle(color: Brand.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: repo.busy ? null : repo.sync,
            icon: const Icon(Icons.sync),
            label: const Text('Synchronise now'),
          ),
          const SizedBox(height: 8),
          if (repo.pending.isEmpty)
            const EmptyState(
              icon: Icons.cloud_done_outlined,
              title: 'Everything is synchronised',
            ),
          for (final p in repo.pending)
            InfoCard(
              leading: Icon(
                p['error'] == null ? Icons.schedule : Icons.error_outline,
                color: p['error'] == null ? Brand.green : Brand.danger,
              ),
              title: actionLabel(p['action']),
              body:
                  'Saved ${shortDate(p['created_at'])}\n${p['error'] ?? 'Waiting to synchronise'}',
              action: Wrap(
                children: [
                  if (p['error'] != null)
                    TextButton(
                      onPressed: () =>
                          runGuarded(context, () => repo.retry('${p['id']}')),
                      child: const Text('Retry'),
                    ),
                  TextButton(
                    onPressed: () => discard('${p['id']}'),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
