import 'package:flutter/material.dart';

import '../services/course_progress.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'course.dart';

class CoursesTab extends StatefulWidget {
  final Repository repo;
  const CoursesTab({super.key, required this.repo});

  @override
  State<CoursesTab> createState() => _CoursesTabState();
}

class _CoursesTabState extends State<CoursesTab> {
  bool browsing = false;
  String search = '';
  Repository get repo => widget.repo;

  bool matches(Map<String, dynamic> course) =>
      search.isEmpty ||
      '${course['title']} ${course['summary']}'.toLowerCase().contains(
        search.toLowerCase(),
      );

  Future<void> requestToJoin(Map<String, dynamic> course) async {
    final message = await askForMessage(
      context,
      title: 'Join ${course['title']}',
      label: 'Message to the admin (optional)',
      confirm: 'Send request',
      explanation:
          'An administrator reviews your request. You will be notified when you are enrolled.',
    );
    if (message == null || !mounted) return;
    await runGuarded(context, () async {
      await repo.requestEnrollment(course['id'], message);
      if (mounted) {
        showMessage(
          context,
          'Enrollment request sent. An administrator will review it.',
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enrolled = {
      for (final e in repo.rows('enrolments')) '${e['course_id']}',
    };
    final mine = repo
        .rows('courses')
        .where((c) => enrolled.contains('${c['id']}') && matches(c))
        .toList();
    final others = repo
        .rows('courses')
        .where((c) => !enrolled.contains('${c['id']}') && matches(c))
        .toList();
    return PageList(
      onRefresh: repo.sync,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(
              value: false,
              label: Text('My courses (${enrolled.length})'),
              icon: const Icon(Icons.school_outlined),
            ),
            const ButtonSegment(
              value: true,
              label: Text('Browse'),
              icon: Icon(Icons.explore_outlined),
            ),
          ],
          selected: {browsing},
          showSelectedIcon: false,
          onSelectionChanged: (value) => setState(() => browsing = value.first),
        ),
        const SizedBox(height: 12),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search courses',
            isDense: true,
          ),
          onChanged: (value) => setState(() => search = value),
        ),
        const SizedBox(height: 12),
        if (!browsing) ...[
          if (mine.isEmpty)
            EmptyState(
              icon: Icons.school_outlined,
              title: search.isEmpty
                  ? 'You are not enrolled in a course yet'
                  : 'No courses match your search',
              message: search.isEmpty
                  ? 'Browse the catalogue and ask to join a course.'
                  : '',
              action: search.isEmpty
                  ? FilledButton(
                      onPressed: () => setState(() => browsing = true),
                      child: const Text('Browse courses'),
                    )
                  : null,
            ),
          for (final course in mine) _MyCourseCard(repo: repo, course: course),
        ] else ...[
          if (others.isEmpty)
            const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No other courses to join right now',
            ),
          for (final course in others)
            _BrowseCard(
              course: course,
              request: repo.enrollmentRequestFor(course['id']),
              busy: repo.busy,
              onRequest: () => requestToJoin(course),
            ),
        ],
      ],
    );
  }
}

class _MyCourseCard extends StatelessWidget {
  final Repository repo;
  final Map<String, dynamic> course;
  const _MyCourseCard({required this.repo, required this.course});

  @override
  Widget build(BuildContext context) {
    final progress = CourseProgress.fromData(repo.data, course['id']);
    return InfoCard(
      leading: SizedBox(
        width: 48,
        height: 48,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress.percent / 100,
              backgroundColor: Brand.greenSoft,
              strokeWidth: 5,
            ),
            Text(
              '${progress.percent}%',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      title: '${course['title']}',
      body: progress.certificateReady
          ? 'Completed · certificate ready'
          : progress.total == 0
          ? 'Lessons are being prepared'
          : '${progress.completed} of ${progress.total} lessons completed',
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseScreen(repo: repo, course: course),
        ),
      ),
    );
  }
}

class _BrowseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final Map<String, dynamic>? request;
  final bool busy;
  final VoidCallback onRequest;
  const _BrowseCard({
    required this.course,
    required this.request,
    required this.busy,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final status = request?['status'];
    final note = '${request?['decision_note'] ?? ''}';
    return InfoCard(
      title: '${course['title']}',
      body: [
        [
          course['level'],
          if (course['duration_hours'] != null)
            '${course['duration_hours']} hours',
        ].where((v) => v != null && '$v'.isNotEmpty).join(' · '),
        '${course['summary'] ?? ''}',
      ].where((v) => v.isNotEmpty).join('\n'),
      action: status == 'pending'
          ? const Align(
              alignment: Alignment.centerLeft,
              child: StatusChip.warning('Request pending · waiting for review'),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (status == 'rejected')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Your request was declined.${note.isEmpty ? '' : ' $note'}',
                      style: const TextStyle(color: Brand.muted, fontSize: 13),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onRequest,
                  icon: const Icon(Icons.how_to_reg_outlined),
                  label: Text(
                    status == 'rejected' ? 'Request again' : 'Request to join',
                  ),
                ),
              ],
            ),
    );
  }
}
