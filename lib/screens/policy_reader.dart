import 'package:flutter/material.dart';

/// Shows a policy in a dialog; "I have read this" unlocks only once the
/// learner has scrolled to the end. Resolves to true when they accept.
Future<bool> showPolicyReader(
  BuildContext context, {
  required String title,
  required String body,
}) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PolicyReader(title: title, body: body),
  );
  return accepted ?? false;
}

class PolicyReader extends StatefulWidget {
  final String title, body;
  const PolicyReader({super.key, required this.title, required this.body});
  @override
  State<PolicyReader> createState() => _PolicyReaderState();
}

class _PolicyReaderState extends State<PolicyReader> {
  final scroll = ScrollController();
  bool reachedEnd = false;

  @override
  void initState() {
    super.initState();
    scroll.addListener(check);
    // Short documents that fit without scrolling count as read.
    WidgetsBinding.instance.addPostFrameCallback((_) => check());
  }

  void check() {
    if (reachedEnd || !scroll.hasClients) return;
    final position = scroll.position;
    if (position.pixels >= position.maxScrollExtent - 8) {
      setState(() => reachedEnd = true);
    }
  }

  @override
  void dispose() {
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
    content: SizedBox(
      width: 520,
      height: MediaQuery.sizeOf(context).height * .55,
      child: Scrollbar(
        controller: scroll,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.only(right: 12, bottom: 12),
          child: Text(widget.body, style: const TextStyle(height: 1.6)),
        ),
      ),
    ),
    actions: [
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Text(
          reachedEnd
              ? 'Thank you for reading.'
              : 'Scroll to the end to continue.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: reachedEnd ? () => Navigator.pop(context, true) : null,
        child: const Text('I have read this'),
      ),
    ],
  );
}
