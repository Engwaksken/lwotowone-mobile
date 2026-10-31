import 'package:flutter/material.dart';

import '../services/repository.dart';

class KnowledgeGameScreen extends StatefulWidget {
  final Repository repo;
  const KnowledgeGameScreen({super.key, required this.repo});

  @override
  State<KnowledgeGameScreen> createState() => _KnowledgeGameScreenState();
}

class _KnowledgeGameScreenState extends State<KnowledgeGameScreen> {
  List<Map<String, dynamic>> topics = [];
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? quiz;
  Map<String, dynamic>? result;
  final Map<String, String> answers = {};
  String selectedTopic = 'farming';
  int questionIndex = 0;
  bool loading = true;
  bool busy = false;
  String? error;

  Repository get repo => widget.repo;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final response = await Future.wait([
        repo.request('GET', '/knowledge-game/topics'),
        repo.request('GET', '/knowledge-game/history'),
      ]);
      if (!mounted) return;
      setState(() {
        topics = (response[0]['topics'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        history = (response[1]['attempts'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        if (!topics.any((topic) => topic['id'] == selectedTopic) &&
            topics.isNotEmpty) {
          selectedTopic = topics.first['id'].toString();
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> startQuiz() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await repo.request('POST', '/knowledge-game/attempts', {
        'topic': selectedTopic,
      });
      if (!mounted) return;
      setState(() {
        quiz = response;
        result = null;
        answers.clear();
        questionIndex = 0;
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> nextQuestion() async {
    final questions = quiz?['questions'] as List? ?? [];
    if (questions.isEmpty) return;
    final question = questions[questionIndex] as Map;
    if (!answers.containsKey(question['id'].toString())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose an answer to continue.'),
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }
    if (questionIndex < questions.length - 1) {
      setState(() => questionIndex++);
      return;
    }
    await submitQuiz();
  }

  Future<void> submitQuiz() async {
    final attemptId = quiz?['attempt_id'];
    if (attemptId == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final response = await repo.request(
        'POST',
        '/knowledge-game/attempts/$attemptId/submit',
        {'answers': answers},
      );
      if (!mounted) return;
      setState(() {
        result = response;
        quiz = null;
      });
      await refreshHistory();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> refreshHistory() async {
    try {
      final response = await repo.request('GET', '/knowledge-game/history');
      if (mounted) {
        setState(() {
          history = (response['attempts'] as List? ?? [])
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        });
      }
    } catch (_) {
      // A saved result remains visible even if history refresh is unavailable.
    }
  }

  String topicTitle(String id) =>
      topics
          .where((topic) => topic['id'] == id)
          .map((topic) => topic['title'].toString())
          .firstOrNull ??
      (id == 'poultry' ? 'Poultry' : 'Farming');

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Knowledge game')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (error != null) ...[
                  MaterialBanner(
                    content: Text(error!),
                    leading: const Icon(Icons.info_outline),
                    actions: [
                      TextButton(onPressed: load, child: const Text('Retry')),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (quiz != null) _quizContent(),
                if (quiz == null && result != null) _resultContent(),
                if (quiz == null && result == null) _topicContent(),
              ],
            ),
          ),
  );

  Widget _topicContent() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xff174f3d), Color(0xff246b4e)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lightbulb_outline, color: Color(0xffffd878), size: 28),
            SizedBox(height: 10),
            Text(
              'Learn as you play',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'Answer five questions and get explanations for every answer.',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      Text('Choose a topic', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      for (final topic in topics)
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: busy
                ? null
                : () => setState(() => selectedTopic = topic['id'].toString()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    topic['id'] == 'poultry'
                        ? Icons.egg_alt_outlined
                        : Icons.agriculture_outlined,
                    color: const Color(0xff175742),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          topic['title'].toString(),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${topic['question_count']} questions in the bank',
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selectedTopic == topic['id']
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selectedTopic == topic['id']
                        ? const Color(0xff175742)
                        : Colors.grey,
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: busy || topics.isEmpty ? null : startQuiz,
        icon: busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.play_arrow),
        label: Text(busy ? 'Starting…' : 'Start quiz'),
      ),
      const SizedBox(height: 8),
      Text(
        'A connection is needed to load questions and save your score.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (history.isNotEmpty) ...[
        const SizedBox(height: 24),
        Text('Recent scores', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final attempt in history.take(5))
          Card(
            child: ListTile(
              leading: const Icon(Icons.emoji_events_outlined),
              title: Text(attempt['topic_title'].toString()),
              subtitle: Text('${attempt['completed_at']}'),
              trailing: Text(
                '${attempt['score']}/${attempt['total_questions']}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
      ],
    ],
  );

  Widget _quizContent() {
    final questions = quiz!['questions'] as List;
    final question = Map<String, dynamic>.from(questions[questionIndex] as Map);
    final options = Map<String, dynamic>.from(question['options'] as Map);
    final questionId = question['id'].toString();
    final selected = answers[questionId];
    final total = questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${topicTitle(quiz!['topic'].toString())} · Question ${questionIndex + 1} of $total',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: const Color(0xff175742),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(value: (questionIndex + 1) / total),
        ),
        const SizedBox(height: 20),
        Text(
          question['question'].toString(),
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final entry in options.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: selected == entry.key
                  ? const Color(0xffe8f2ec)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy
                    ? null
                    : () => setState(() => answers[questionId] = entry.key),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected == entry.key
                          ? const Color(0xff175742)
                          : const Color(0xffdce5df),
                      width: selected == entry.key ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: selected == entry.key
                            ? const Color(0xff175742)
                            : const Color(0xffe8f0eb),
                        foregroundColor: selected == entry.key
                            ? Colors.white
                            : const Color(0xff175742),
                        child: Text(entry.key.toString().toUpperCase()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(entry.value.toString())),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: busy ? null : nextQuestion,
          child: Text(
            busy
                ? 'Checking answers…'
                : questionIndex == total - 1
                ? 'Finish quiz'
                : 'Next question',
          ),
        ),
      ],
    );
  }

  Widget _resultContent() {
    final score = result!['score'] as int;
    final total = result!['total_questions'] as int;
    final questions = result!['questions'] as List? ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          color: const Color(0xffe8f2ec),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const Icon(
                  Icons.emoji_events_outlined,
                  color: Color(0xff175742),
                  size: 42,
                ),
                const SizedBox(height: 8),
                Text(
                  '$score / $total',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: const Color(0xff175742),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text('${result!['percentage']}% correct'),
                const SizedBox(height: 4),
                Text('${topicTitle(result!['topic'].toString())} quiz'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Review answers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (var i = 0; i < questions.length; i++)
          _reviewCard(i + 1, Map<String, dynamic>.from(questions[i] as Map)),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => setState(() {
            result = null;
            error = null;
          }),
          icon: const Icon(Icons.replay),
          label: const Text('Play again'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Back to dashboard'),
        ),
      ],
    );
  }

  Widget _reviewCard(int number, Map<String, dynamic> question) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${question['question']}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            question['correct'] == true
                ? 'Your answer: ${question['selected_answer']}'
                : 'Your answer: ${question['selected_answer']}\nCorrect answer: ${question['correct_answer']}',
            style: TextStyle(
              color: question['correct'] == true
                  ? const Color(0xff175742)
                  : Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: 6),
          Text(question['explanation'].toString()),
        ],
      ),
    ),
  );
}
