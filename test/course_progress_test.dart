import 'package:flutter_test/flutter_test.dart';
import 'package:lwotowone_mobile/services/course_progress.dart';

void main() {
  final data = <String, dynamic>{
    'lessons': [
      {'id': 2, 'course_id': 1, 'position': 2},
      {'id': 1, 'course_id': 1, 'position': 1},
      {'id': 3, 'course_id': 99, 'position': 1},
    ],
    'lesson_progress': [
      {'lesson_id': 1},
      {'lesson_id': 1},
      {'lesson_id': 3},
    ],
    'assignments': [
      {'id': 1, 'course_id': 1},
      {'id': 2, 'course_id': 99},
    ],
    'submissions': [
      {'assignment_id': 1, 'status': 'submitted'},
      {'assignment_id': 2, 'status': 'passed'},
    ],
  };
  test('Progress ignores other courses and duplicate completion rows', () {
    final progress = CourseProgress.fromData(data, '1');
    expect(progress.percent, 50);
    expect(progress.completed, 1);
    expect(progress.nextLessonId, 2);
    expect(progress.passed, 0);
    expect(progress.assignments, 1);
    expect(progress.certificateReady, false);
  });
  test('All lessons and passed practical assignments are required', () {
    final complete = {
      ...data,
      'lesson_progress': [
        {'lesson_id': 1},
        {'lesson_id': 2},
      ],
    };
    expect(CourseProgress.fromData(complete, 1).certificateReady, false);
    complete['submissions'] = [
      {'assignment_id': 1, 'status': 'passed'},
    ];
    final progress = CourseProgress.fromData(complete, 1);
    expect(progress.percent, 100);
    expect(progress.nextLessonId, isNull);
    expect(progress.certificateReady, true);
  });
  test('Empty or undownloaded courses never show certificate readiness', () {
    final progress = CourseProgress.fromData({}, 1);
    expect(progress.percent, 0);
    expect(progress.certificateReady, false);
    expect(progress.nextLessonId, isNull);
  });
}
