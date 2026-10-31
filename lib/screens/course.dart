import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_config.dart';
import '../services/course_progress.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/media_view.dart';
import '../widgets/ui.dart';
import 'action_form.dart';
import 'content.dart';

class CourseScreen extends StatelessWidget {
  final Repository repo;
  final Map<String, dynamic> course;
  const CourseScreen({super.key, required this.repo, required this.course});

  bool same(Object? a, Object? b) => '$a' == '$b';

  List<Map<String, dynamic>> lessons() =>
      repo
          .rows('lessons')
          .where((l) => same(l['course_id'], course['id']))
          .toList()
        ..sort(
          (a, b) => ((a['sort_order'] ?? a['position'] ?? 0) as num).compareTo(
            (b['sort_order'] ?? b['position'] ?? 0) as num,
          ),
        );

  Map<String, dynamic> get serverProgress => repo
      .rows('course_progress')
      .firstWhere(
        (p) => same(p['course_id'], course['id']),
        orElse: () => <String, dynamic>{},
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) {
      final progress = CourseProgress.fromData(repo.data, course['id']);
      final resources = repo
          .rows('resources')
          .where((r) => same(r['course_id'], course['id']))
          .toList();
      final assignments = repo
          .rows('assignments')
          .where((a) => same(a['course_id'], course['id']))
          .toList();
      return DefaultTabController(
        length: 3,
        child: Scaffold(
          body: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverAppBar(
                pinned: true,
                expandedHeight: 230,
                foregroundColor: Colors.white,
                backgroundColor: Brand.greenDark,
                title: Text(
                  '${course['title']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                flexibleSpace: FlexibleSpaceBar(
                  collapseMode: CollapseMode.pin,
                  background: _CourseHeader(course: course, progress: progress),
                ),
                bottom: const TabBar(
                  labelColor: Colors.white,
                  unselectedLabelColor: Color(0xffcfe2d7),
                  indicatorColor: Brand.gold,
                  tabs: [
                    Tab(text: 'Lessons'),
                    Tab(text: 'Resources'),
                    Tab(text: 'Assignments'),
                  ],
                ),
              ),
            ],
            body: TabBarView(
              children: [
                _lessonsTab(context, progress),
                _resourcesTab(context, resources),
                _assignmentsTab(context, assignments, progress),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _lessonsTab(BuildContext context, CourseProgress progress) {
    final items = lessons();
    final done = {
      for (final p in repo.rows('lesson_progress')) '${p['lesson_id']}',
    };
    final tiles = <Widget>[];
    Object? module;
    for (final (index, lesson) in items.indexed) {
      if (lesson['module_title'] != null && lesson['module_title'] != module) {
        tiles.add(SectionTitle('${lesson['module_title']}'));
      }
      module = lesson['module_title'];
      tiles.add(
        _LessonTile(
          number: index + 1,
          lesson: lesson,
          completed: done.contains('${lesson['id']}'),
          next: same(lesson['id'], progress.nextLessonId),
          saved: repo.hasSavedFile('lessons', lesson['id']),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentScreen(
                repo: repo,
                type: 'lessons',
                id: lesson['id'],
                subtitle:
                    'Lesson ${index + 1} of ${items.length}${lesson['module_title'] == null ? '' : ' · ${lesson['module_title']}'}',
              ),
            ),
          ),
        ),
      );
    }
    return PageList(
      onRefresh: repo.sync,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.menu_book_outlined,
            title: 'No lessons yet',
            message:
                'Lessons in your learning language will appear here once they are published.',
          ),
        ...tiles,
      ],
    );
  }

  Widget _resourcesTab(
    BuildContext context,
    List<Map<String, dynamic>> resources,
  ) => PageList(
    onRefresh: repo.sync,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    children: [
      if (resources.isEmpty)
        const EmptyState(
          icon: Icons.folder_open_outlined,
          title: 'No resources yet',
        ),
      for (final resource in resources)
        InfoCard(
          leading: CircleAvatar(
            backgroundColor: Brand.greenSoft,
            child: Icon(
              resource['locked'] == true
                  ? Icons.lock_outline
                  : mediaIcon('${resource['media_type'] ?? 'document'}'),
              color: Brand.green,
            ),
          ),
          title: '${resource['title']}',
          body: '${resource['description'] ?? ''}',
          trailing: repo.hasSavedFile('resources', resource['id'])
              ? const Icon(
                  Icons.offline_pin,
                  color: Brand.green,
                  semanticLabel: 'Saved in the app',
                )
              : const Icon(Icons.chevron_right),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ContentScreen(
                repo: repo,
                type: 'resources',
                id: resource['id'],
              ),
            ),
          ),
        ),
    ],
  );

  Widget _assignmentsTab(
    BuildContext context,
    List<Map<String, dynamic>> assignments,
    CourseProgress progress,
  ) => PageList(
    onRefresh: repo.sync,
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
    children: [
      if (serverProgress['awaiting_assessments'] == true)
        const NoticeCard(
          icon: Icons.hourglass_top,
          warning: true,
          text:
              'Practical assignments in your learning language are being prepared. You can finish the course once they are published.',
        ),
      if (assignments.isEmpty && serverProgress['awaiting_assessments'] != true)
        const EmptyState(
          icon: Icons.assignment_outlined,
          title: 'No practical assignments',
        ),
      for (final assignment in assignments)
        _AssignmentCard(repo: repo, assignment: assignment),
      const SizedBox(height: 12),
      _CertificateCard(
        repo: repo,
        course: course,
        ready: progress.certificateReady,
      ),
    ],
  );
}

class _CourseHeader extends StatelessWidget {
  final Map<String, dynamic> course;
  final CourseProgress progress;
  const _CourseHeader({required this.course, required this.progress});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(gradient: Brand.heroGradient),
    padding: EdgeInsets.fromLTRB(
      20,
      MediaQuery.paddingOf(context).top + 60,
      20,
      60,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          [
                course['level'],
                if (course['duration_hours'] != null)
                  '${course['duration_hours']} hours',
              ]
              .where((v) => v != null && '$v'.isNotEmpty)
              .join(' · ')
              .toUpperCase(),
          style: const TextStyle(
            color: Brand.gold,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress.percent / 100,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  color: Brand.gold,
                  semanticsLabel: 'Lesson completion',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${progress.percent}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '${progress.completed} of ${progress.total} lessons · ${progress.passed} of ${progress.assignments} assignments passed',
          style: const TextStyle(color: Color(0xffd7e6dd), fontSize: 12),
        ),
      ],
    ),
  );
}

class _LessonTile extends StatelessWidget {
  final int number;
  final Map<String, dynamic> lesson;
  final bool completed;
  final bool next;
  final bool saved;
  final VoidCallback onTap;
  const _LessonTile({
    required this.number,
    required this.lesson,
    required this.completed,
    required this.next,
    required this.saved,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final locked = lesson['locked'] == true;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: next ? Brand.green : Brand.line,
          width: next ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: locked ? null : onTap,
        leading: CircleAvatar(
          backgroundColor: completed
              ? Brand.green
              : (locked ? const Color(0xffeef1ee) : Brand.greenSoft),
          foregroundColor: completed ? Colors.white : Brand.green,
          child: completed
              ? const Icon(Icons.check, size: 20)
              : locked
              ? const Icon(Icons.lock_outline, size: 18, color: Brand.muted)
              : Text(
                  '$number',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
        ),
        title: Text(
          '${lesson['title'] ?? 'Lesson $number'}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          locked
              ? 'Locked'
              : next
              ? 'Up next'
              : completed
              ? 'Completed'
              : '${lesson['media_type'] ?? 'Lesson'}'.replaceFirstMapped(
                  RegExp(r'^.'),
                  (m) => m[0]!.toUpperCase(),
                ),
        ),
        trailing: saved
            ? const Icon(
                Icons.offline_pin,
                color: Brand.green,
                semanticLabel: 'Saved in the app',
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Repository repo;
  final Map<String, dynamic> assignment;
  const _AssignmentCard({required this.repo, required this.assignment});

  @override
  Widget build(BuildContext context) {
    final matches = repo
        .rows('submissions')
        .where((s) => '${s['assignment_id']}' == '${assignment['id']}');
    final submission = matches.isEmpty ? null : matches.first;
    final status = '${submission?['status'] ?? ''}';
    return InfoCard(
      title: '${assignment['title']}',
      body: '${assignment['instructions'] ?? ''}',
      action: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              StatusChip.neutral('Pass mark ${assignment['pass_mark']}%'),
              StatusChip.neutral(
                assignment['due_at'] == null
                    ? 'No deadline'
                    : 'Due ${shortDate(assignment['due_at'])}',
              ),
              if (submission != null)
                status == 'passed'
                    ? StatusChip(
                        'Passed · ${submission['score'] ?? ''}%',
                        icon: Icons.check_circle,
                      )
                    : StatusChip.warning(
                        status == 'submitted'
                            ? 'Awaiting review'
                            : '${status[0].toUpperCase()}${status.substring(1)}',
                      ),
            ],
          ),
          if ((submission?['feedback'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Feedback: ${submission!['feedback']}'),
          ],
          if (submission == null ||
              status == 'returned' ||
              status == 'failed') ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActionForm(
                    title: 'Submit practical work',
                    action: 'submit',
                    repo: repo,
                    fixed: {'assignment_id': assignment['id']},
                    offlineAllowed: true,
                    fields: const [
                      FormFieldSpec(
                        'body',
                        'Describe your practical work',
                        multiline: true,
                      ),
                    ],
                  ),
                ),
              ),
              icon: const Icon(Icons.upload_outlined),
              label: Text(
                submission == null ? 'Submit written evidence' : 'Submit again',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  final Repository repo;
  final Map<String, dynamic> course;
  final bool ready;
  const _CertificateCard({
    required this.repo,
    required this.course,
    required this.ready,
  });

  @override
  Widget build(BuildContext context) => InfoCard(
    leading: const CircleAvatar(
      backgroundColor: Brand.goldSoft,
      child: Icon(Icons.workspace_premium, color: Color(0xff8a6400)),
    ),
    title: 'Completion certificate',
    body: ready
        ? 'You have completed this course. View your certificate on the website (sign-in required).'
        : 'Complete every lesson and pass the practical assignments to earn your certificate.',
    action: OutlinedButton(
      onPressed: !ready
          ? null
          : () => runGuarded(context, () async {
              final error = ApiConfig.validate(repo.baseUrl);
              if (error != null) throw ApiFailure(error, 0);
              final opened = await launchUrl(
                Uri.parse(
                  '${repo.baseUrl.replaceFirst(RegExp(r'/api$'), '')}/certificates/${course['id']}',
                ),
                mode: LaunchMode.externalApplication,
              );
              if (!opened) {
                throw ApiFailure('Could not open the certificate page.', 0);
              }
            }),
      child: const Text('Completion certificate (web sign-in required)'),
    ),
  );
}
