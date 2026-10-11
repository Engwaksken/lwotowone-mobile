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
                  title: Text(
                    l['title'] + (l['locked'] == true ? ' · Locked' : ''),
                  ),
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
                          if (l['locked'] == true)
                            const Text(
                              'Sync after course access is approved and preceding lessons are completed to unlock this lesson.',
                            )
                          else ...[
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
                            if (l['download_url'] != null &&
                                repo.hasCachedLearningFile(
                                  'lessons',
                                  l['id'].toString(),
                                ))
                              TextButton.icon(
                                onPressed: () => run(context, () async {
                                  final file = await repo.cachedLearningFile(
                                    'lessons',
                                    l['id'].toString(),
                                  );
                                  if (file == null) {
                                    throw ApiFailure(
                                      'Sync while connected to download this lesson file.',
                                      0,
                                    );
                                  }
                                  final result = await OpenFilex.open(
                                    file.path,
                                  );
                                  if (result.type != ResultType.done) {
                                    throw ApiFailure(result.message, 0);
                                  }
                                }),
                                icon: const Icon(Icons.offline_pin),
                                label: const Text(
                                  'Open downloaded lesson file',
                                ),
                              ),
                            FilledButton(
                              onPressed:
                                  l['locked'] == true ||
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
                title: Text(
                  r['title'] + (r['locked'] == true ? ' · Locked' : ''),
                ),
                subtitle: Text(
                  [
                    if ((r['description'] ?? '').toString().isNotEmpty)
                      r['description'].toString(),
                    if (r['locked'] != true &&
                        r['download_url'] != null &&
                        repo.hasCachedLearningFile(
                          'resources',
                          r['id'].toString(),
                        ))
                      'Downloaded for offline use',
                    if (r['locked'] != true &&
                        r['download_url'] != null &&
                        !repo.hasCachedLearningFile(
                          'resources',
                          r['id'].toString(),
                        ))
                      'Sync while connected to download for offline use',
                    if (r['locked'] != true && r['content_url'] != null)
                      'External content requires an internet connection',
                  ].join(' · '),
                ),
                trailing: Icon(
                  r['locked'] == true
                      ? Icons.lock_outline
                      : repo.hasCachedLearningFile(
                          'resources',
                          r['id'].toString(),
                        )
                      ? Icons.offline_pin
                      : Icons.download,
                ),
                onTap: r['locked'] == true
                    ? null
                    : () => run(context, () async {
                        final body = r['content_body']?.toString();
                        if (body != null && body.isNotEmpty) {
                          await showDialog<void>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(r['title']),
                              content: SingleChildScrollView(
                                child: SelectableText(body),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Close'),
                                ),
                              ],
                            ),
                          );
                        } else if (r['content_url'] != null) {
                          final opened = await launchUrl(
                            Uri.parse(r['content_url']),
                            mode: LaunchMode.externalApplication,
                          );
                          if (!opened) {
                            throw ApiFailure(
                              'Could not open the resource link.',
                              0,
                            );
                          }
                        } else if (r['download_url'] != null) {
                          final file = await repo.downloadResource(r['id']);
                          final result = await OpenFilex.open(file.path);
                          if (result.type != ResultType.done) {
                            throw ApiFailure(result.message, 0);
                          }
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
