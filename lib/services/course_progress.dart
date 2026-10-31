class CourseProgress {
  final int completed, total, passed, assignments;
  final dynamic nextLessonId;
  const CourseProgress(
    this.completed,
    this.total,
    this.passed,
    this.assignments,
    this.nextLessonId,
  );
  int get percent => total == 0 ? 0 : (completed * 100 / total).floor();
  bool get certificateReady =>
      total > 0 && completed == total && passed == assignments;
  factory CourseProgress.fromData(Map<String, dynamic> data, dynamic courseId) {
    List<Map> rows(String key) =>
        (data[key] as List? ?? []).whereType<Map>().toList();
    bool same(dynamic a, dynamic b) => a.toString() == b.toString();
    final lessons =
        rows('lessons').where((l) => same(l['course_id'], courseId)).toList()
          ..sort(
            (a, b) => ((a['sort_order'] ?? a['position'] ?? 0) as num)
                .compareTo((b['sort_order'] ?? b['position'] ?? 0) as num),
          );
    final completed = rows(
      'lesson_progress',
    ).map((p) => p['lesson_id'].toString()).toSet();
    final assignments = rows(
      'assignments',
    ).where((a) => same(a['course_id'], courseId)).toList();
    final passed = rows('submissions')
        .where((s) => s['status'] == 'passed')
        .map((s) => s['assignment_id'].toString())
        .toSet();
    final remaining = lessons
        .where((l) => !completed.contains(l['id'].toString()))
        .toList();
    return CourseProgress(
      lessons.length - remaining.length,
      lessons.length,
      assignments.where((a) => passed.contains(a['id'].toString())).length,
      assignments.length,
      remaining.isEmpty ? null : remaining.first['id'],
    );
  }
}
