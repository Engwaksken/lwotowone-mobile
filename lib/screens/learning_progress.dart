import 'package:flutter/material.dart';
import '../services/course_progress.dart';

class LearningProgressView extends StatelessWidget {
  final CourseProgress progress;
  const LearningProgressView({super.key, required this.progress});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Lesson progress: ${progress.percent}%'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.percent / 100,
          semanticsLabel: 'Lesson completion',
        ),
        const SizedBox(height: 8),
        Text(
          '${progress.completed} of ${progress.total} lessons completed · ${progress.passed} of ${progress.assignments} assignments passed',
        ),
        Text(
          progress.certificateReady
              ? 'Completion certificate ready'
              : progress.total == 0
              ? 'Lessons have not been downloaded yet.'
              : 'Complete the lessons and pass the practical assignments.',
        ),
        const Text(
          'Confirmed progress from your last synchronisation.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}
