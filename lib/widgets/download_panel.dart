import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../theme.dart';
import 'ui.dart';

/// Request, approval and saving for one lesson or resource file. Learners
/// stream content freely; keeping a copy on the phone needs an approved request.
class DownloadPanel extends StatefulWidget {
  final Repository repo;
  final String type;
  final Map<String, dynamic> item;
  const DownloadPanel({
    super.key,
    required this.repo,
    required this.type,
    required this.item,
  });

  @override
  State<DownloadPanel> createState() => _DownloadPanelState();
}

class _DownloadPanelState extends State<DownloadPanel> {
  double? progress;
  Repository get repo => widget.repo;

  int get validDays =>
      ((repo.data['download_policy'] as Map?)?['valid_days'] as num?)
          ?.toInt() ??
      7;
  int get maxDownloads =>
      ((repo.data['download_policy'] as Map?)?['max_downloads'] as num?)
          ?.toInt() ??
      3;

  Future<void> ask({bool again = false}) async {
    final message = await askForMessage(
      context,
      title: again ? 'Request download again' : 'Request a download',
      label: 'Why do you need a copy? (optional)',
      confirm: 'Send request',
      explanation:
          'You can watch and read this content in the app at any time while online. An approved download lets you keep a copy in the app for offline use. Approvals allow $maxDownloads downloads within $validDays days.',
    );
    if (message == null || !mounted) return;
    await runGuarded(context, () async {
      await repo.requestDownload(widget.type, widget.item['id'], message);
      if (mounted) {
        showMessage(
          context,
          'Download request sent. You will be notified when it is reviewed.',
        );
      }
    });
  }

  Future<void> save() async {
    setState(() => progress = 0);
    await runGuarded(context, () async {
      await repo.saveApprovedDownload(
        widget.type,
        widget.item['id'],
        onProgress: (value) {
          if (mounted) setState(() => progress = value);
        },
      );
      if (mounted) showMessage(context, 'Saved in the app for offline use.');
    });
    if (mounted) setState(() => progress = null);
  }

  Future<void> remove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove saved copy?'),
        content: const Text(
          'This frees storage on your phone. You can still watch or read it online. Saving it again needs an approved download.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repo.removeSavedFile(widget.type, widget.item['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.item['downloadable'] != true || widget.item['locked'] == true) {
      return const SizedBox.shrink();
    }
    final request = repo.downloadRequestFor(widget.type, widget.item['id']);
    final state = request?['state'];
    final saved = repo.hasSavedFile(widget.type, widget.item['id']);
    final Widget body;
    if (saved) {
      body = Row(
        children: [
          const StatusChip('Saved in the app', icon: Icons.offline_pin),
          const Spacer(),
          TextButton.icon(
            onPressed: remove,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Remove'),
          ),
        ],
      );
    } else if (progress != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(value: progress! < 0 ? null : progress),
          const SizedBox(height: 6),
          Text(
            progress! < 0
                ? 'Saving…'
                : 'Saving · ${(progress! * 100).round()}%',
          ),
        ],
      );
    } else if (state == 'approved') {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Download approved · ${request!['downloads_left']} of $maxDownloads left until ${shortDate(request['expires_at'])}',
            style: const TextStyle(color: Brand.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: repo.busy ? null : save,
            icon: const Icon(Icons.download),
            label: const Text('Save in the app'),
          ),
        ],
      );
    } else if (state == 'pending') {
      body = const StatusChip.warning(
        'Download requested · waiting for approval',
      );
    } else {
      final ended = state == 'expired' || state == 'used_up';
      final declined = state == 'rejected' || state == 'revoked';
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (declined)
            Text(
              'Your download request was declined.${(request?['decision_note'] ?? '').toString().isEmpty ? '' : ' ${request!['decision_note']}'}',
              style: const TextStyle(color: Brand.muted, fontSize: 13),
            ),
          if (ended)
            const Text(
              'Your download access has ended.',
              style: TextStyle(color: Brand.muted, fontSize: 13),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: repo.busy ? null : () => ask(again: state != null),
              icon: const Icon(Icons.download_for_offline_outlined),
              label: Text(
                state == null ? 'Request download' : 'Request download again',
              ),
            ),
          ),
        ],
      );
    }
    return Padding(padding: const EdgeInsets.only(top: 12), child: body);
  }
}
