import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';
import '../services/repository.dart';
import 'action_form.dart';
import 'learning_progress.dart';
import '../services/course_progress.dart';
import '../services/api_config.dart';

class CourseScreen extends StatelessWidget {
  final Repository repo;
  final Map<String, dynamic> course;
  const CourseScreen({super.key, required this.repo, required this.course});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) {
      final progress = CourseProgress.fromData(repo.data, course['id']);
      final lessons =
          repo
              .rows('lessons')
              .where((l) => l['course_id'] == course['id'])
              .toList()
            ..sort(
              (a, b) => (a['position'] as int).compareTo(b['position'] as int),
            );
      return Scaffold(
        appBar: AppBar(title: Text(course['title'])),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(course['summary'] ?? ''),
            LearningProgressView(progress: progress),
            const SizedBox(height: 20),
            Text('Lessons', style: Theme.of(context).textTheme.titleLarge),
            if (lessons.isEmpty)
              const Text('No downloaded lessons. Synchronise after enrolment.'),
            for (final l in lessons)
              Card(
                child: ExpansionTile(
                  key: PageStorageKey('lesson-${l['id']}'),
                  initiallyExpanded: l['id'] == progress.nextLessonId,
                  title: Text(l['title']),
                  leading: Icon(
                    repo
                            .rows('lesson_progress')
                            .any((p) => p['lesson_id'] == l['id'])
                        ? Icons.check_circle
                        : Icons.menu_book,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectableText(l['body'] ?? ''),
                          if (l['video_url'] != null)
                            TextButton(
                              onPressed: () => launchUrl(
                                Uri.parse(l['video_url']),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: const Text(
                                'Watch video (uses internet data)',
                              ),
                            ),
                          FilledButton(
                            onPressed:
                                repo.busy ||
                                    repo
                                        .rows('lesson_progress')
                                        .any((p) => p['lesson_id'] == l['id'])
                                ? null
                                : () => run(
                                    context,
                                    () => repo.act('complete', {
                                      'lesson_id': l['id'],
                                    }, offlineAllowed: true),
                                  ),
                            child: Text(
                              repo
                                      .rows('lesson_progress')
                                      .any((p) => p['lesson_id'] == l['id'])
                                  ? 'Completed'
                                  : 'Mark complete',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Text('Resources', style: Theme.of(context).textTheme.titleLarge),
            for (final r
                in repo
                    .rows('resources')
                    .where((r) => r['course_id'] == course['id']))
              ListTile(
                title: Text(r['title']),
                subtitle: Text(r['description'] ?? ''),
                trailing: const Icon(Icons.download),
                onTap: () => run(context, () async {
                  final file = await repo.downloadResource(r['id']);
                  final result = await OpenFilex.open(file.path);
                  if (result.type != ResultType.done) {
                    throw ApiFailure(result.message, 0);
                  }
                }),
              ),
            const SizedBox(height: 20),
            Text(
              'Practical assignments',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final a
                in repo
                    .rows('assignments')
                    .where((a) => a['course_id'] == course['id']))
              assignment(context, a),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: !progress.certificateReady
                  ? null
                  : () => run(context, () async {
                      final error = ApiConfig.validate(repo.baseUrl);
                      if (error != null) throw ApiFailure(error, 0);
                      final opened = await launchUrl(
                        Uri.parse(
                          '${repo.baseUrl.replaceFirst(RegExp(r'/api$'), '')}/certificates/${course['id']}',
                        ),
                        mode: LaunchMode.externalApplication,
                      );
                      if (!opened) {
                        throw ApiFailure(
                          'Could not open the certificate page.',
                          0,
                        );
                      }
                    }),
              child: const Text(
                'Completion certificate (web sign-in required)',
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget assignment(BuildContext context, Map<String, dynamic> a) {
    final matches = repo
        .rows('submissions')
        .where((s) => s['assignment_id'] == a['id']);
    final submission = matches.isEmpty ? null : matches.first;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(a['title'], style: Theme.of(context).textTheme.titleMedium),
            Text(a['instructions']),
            Text(
              'Pass mark: ${a['pass_mark']}% · Due: ${a['due_at'] ?? 'No deadline'}',
            ),
            if (submission != null) ...[
              Text(
                'Status: ${submission['status']} · Score: ${submission['score'] ?? 'Awaiting review'}',
              ),
              Text(submission['feedback'] ?? ''),
            ],
            if (submission == null || submission['status'] == 'returned')
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActionForm(
                      title: 'Submit practical work',
                      action: 'submit',
                      repo: repo,
                      fixed: {'assignment_id': a['id']},
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
                child: const Text('Submit written evidence'),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> run(BuildContext context, Future<void> Function() work) async {
    try {
      await work();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }
}
