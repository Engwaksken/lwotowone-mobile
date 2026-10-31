import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../theme.dart';
import '../widgets/media_view.dart';
import '../widgets/ui.dart';
import 'content.dart';
import 'learner_profile.dart';

class ProfileTab extends StatefulWidget {
  final Repository repo;
  const ProfileTab({super.key, required this.repo});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  Repository get repo => widget.repo;

  String titleOf(String type, Object? id) {
    for (final row in repo.rows(type)) {
      if ('${row['id']}' == '$id') {
        return '${row['title'] ?? 'Learning content'}';
      }
    }
    if (type == 'attachments') {
      for (final lesson in repo.rows('lessons')) {
        for (final file in lesson['attachments'] as List? ?? const []) {
          if (file is Map && '${file['id']}' == '$id') return '${file['name']}';
        }
      }
    }
    return 'Learning content';
  }

  String courseTitle(Object? id) =>
      '${repo.rows('courses').firstWhere((c) => '${c['id']}' == '$id', orElse: () => {'title': 'Course'})['title']}';

  Future<void> signOut() async {
    if (repo.pending.isNotEmpty) {
      showMessage(
        context,
        'Synchronise or review and discard pending work first.',
      );
      return;
    }
    await runGuarded(context, () => repo.logout());
  }

  @override
  Widget build(BuildContext context) {
    final user = repo.data['user'] as Map? ?? const {};
    final access = repo.data['access'] as Map? ?? const {};
    final percent =
        (access['profile_percent'] as num?)?.toInt() ??
        (user['profile_complete'] == false ? 0 : 100);
    final name = '${user['name'] ?? 'Learner'}';
    final photo = '${user['profile_photo_url'] ?? ''}';
    final downloads = repo.rows('download_requests');
    final enrollments = repo.rows('enrollment_requests');
    return PageList(
      onRefresh: repo.sync,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Brand.gold,
                  foregroundColor: Brand.greenDark,
                  child: photo.isEmpty
                      ? Text(
                          name.isEmpty
                              ? 'L'
                              : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        )
                      : ClipOval(
                          child: Image.network(
                            photo,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            headers: repo.authHeaders,
                            errorBuilder: (_, _, _) =>
                                Text(name.characters.first),
                          ),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      for (final detail in [
                        user['learner_no'],
                        user['email'],
                        user['phone'],
                      ])
                        if (detail != null && '$detail'.isNotEmpty)
                          Text(
                            '$detail',
                            style: const TextStyle(color: Brand.muted),
                          ),
                      const SizedBox(height: 6),
                      StatusChip.neutral(
                        user['preferred_language'] == 'lg'
                            ? 'Learning in Luganda'
                            : 'Learning in English',
                        icon: Icons.translate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        ProfileProgressCard(
          percent: percent,
          missing: [
            for (final item in access['profile_missing'] as List? ?? const [])
              '$item',
          ],
        ),
        FilledButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LearnerProfile(repo: repo)),
          ),
          icon: const Icon(Icons.assignment_ind_outlined),
          label: Text(
            user['profile_complete'] == false
                ? 'Complete learner profile'
                : 'Edit learner profile',
          ),
        ),
        const SectionTitle('My requests'),
        if (downloads.isEmpty && enrollments.isEmpty)
          const Text(
            'Course and download requests you send appear here.',
            style: TextStyle(color: Brand.muted),
          ),
        for (final request in enrollments)
          _RequestTile(
            icon: Icons.how_to_reg_outlined,
            title: 'Join ${courseTitle(request['course_id'])}',
            state: '${request['status']}',
            note: request['decision_note'],
          ),
        for (final request in downloads)
          _RequestTile(
            icon: Icons.download_outlined,
            title:
                'Download: ${titleOf('${request['item_type']}', request['item_id'])}',
            state: '${request['state']}',
            note: request['state'] == 'approved'
                ? '${request['downloads_left']} downloads left until ${shortDate(request['expires_at'])}'
                : request['decision_note'],
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ContentScreen(
                  repo: repo,
                  type: '${request['item_type']}',
                  id: request['item_id'],
                ),
              ),
            ),
          ),
        const SectionTitle('Saved in the app'),
        FutureBuilder<List<SavedFile>>(
          future: repo.savedFiles(),
          builder: (context, snapshot) {
            final files = snapshot.data ?? const <SavedFile>[];
            if (files.isEmpty) {
              return const Text(
                'Nothing saved yet. Approved downloads let you keep lessons and resources in the app for offline use.',
                style: TextStyle(color: Brand.muted),
              );
            }
            final total = files.fold<int>(0, (sum, file) => sum + file.size);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${files.length} files · ${formatBytes(total)}',
                  style: const TextStyle(color: Brand.muted),
                ),
                const SizedBox(height: 8),
                for (final saved in files)
                  Card(
                    child: ListTile(
                      leading: Icon(
                        mediaIcon(mediaKindForName(saved.file.path)),
                        color: Brand.green,
                      ),
                      title: Text(titleOf(saved.type, saved.id)),
                      subtitle: Text(formatBytes(saved.size)),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => Scaffold(
                            appBar: AppBar(
                              title: Text(titleOf(saved.type, saved.id)),
                            ),
                            body: PageList(
                              children: [
                                MediaView(
                                  repo: repo,
                                  kind: mediaKindForName(saved.file.path),
                                  title: titleOf(saved.type, saved.id),
                                  file: saved.file,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      trailing: IconButton(
                        tooltip: 'Remove from phone',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await repo.removeSavedFile(saved.type, saved.id);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign out'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Synchronise your pending work before signing out. Signing out needs internet and removes saved files from this phone.',
          style: TextStyle(color: Brand.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _RequestTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String state;
  final Object? note;
  final VoidCallback? onTap;
  const _RequestTile({
    required this.icon,
    required this.title,
    required this.state,
    this.note,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = switch (state) {
      'approved' => const StatusChip('Approved', icon: Icons.check_circle),
      'pending' => const StatusChip.warning('Pending'),
      'rejected' => const StatusChip.neutral('Declined'),
      'revoked' => const StatusChip.neutral('Withdrawn'),
      'expired' || 'used_up' => const StatusChip.neutral('Ended'),
      _ => StatusChip.neutral(state),
    };
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: Brand.green),
        title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: note == null || '$note'.isEmpty ? null : Text('$note'),
        trailing: chip,
      ),
    );
  }
}
