import 'package:flutter/material.dart';
import '../services/repository.dart';

class FormFieldSpec {
  final String key, label;
  final bool required, multiline;
  final TextInputType keyboard;
  final Map<String, String>? options;
  final String? value;
  const FormFieldSpec(
    this.key,
    this.label, {
    this.required = true,
    this.multiline = false,
    this.keyboard = TextInputType.text,
    this.options,
    this.value,
  });
}

class ActionForm extends StatefulWidget {
  final String title, action;
  final Repository repo;
  final Map<String, dynamic> fixed;
  final List<FormFieldSpec> fields;
  final bool offlineAllowed;
  const ActionForm({
    super.key,
    required this.title,
    required this.action,
    required this.repo,
    this.fixed = const {},
    required this.fields,
    this.offlineAllowed = false,
  });
  @override
  State<ActionForm> createState() => _ActionFormState();
}

class _ActionFormState extends State<ActionForm> {
  final form = GlobalKey<FormState>();
  final Map<String, TextEditingController> controllers = {};
  final Map<String, String?> selections = {};
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    for (final f in widget.fields) {
      if (f.options == null) {
        controllers[f.key] = TextEditingController(text: f.value ?? '');
      } else {
        selections[f.key] = f.value;
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final payload = <String, dynamic>{...widget.fixed};
      for (final f in widget.fields) {
        payload[f.key] = f.options != null
            ? selections[f.key]
            : controllers[f.key]!.text.trim();
      }
      if (widget.action == 'profile') {
        await widget.repo.profile(payload);
      } else {
        await widget.repo.act(
          widget.action,
          payload,
          offlineAllowed: widget.offlineAllowed,
        );
      }
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.offlineAllowed && widget.repo.pending.isNotEmpty
                  ? 'Saved on this device. Synchronise to send.'
                  : 'Saved successfully.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: Form(
      key: form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.offlineAllowed)
            const Padding(
              padding: EdgeInsets.only(bottom: 20),
              child: Text(
                'Your work is saved locally and sent when you synchronise. Check the Pending screen for any server feedback.',
              ),
            ),
          for (final f in widget.fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: f.options != null
                  ? DropdownButtonFormField<String>(
                      initialValue: selections[f.key],
                      isExpanded: true,
                      decoration: InputDecoration(labelText: f.label),
                      items: f.options!.entries
                          .map(
                            (e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(
                                e.value,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => selections[f.key] = v,
                      validator: (v) =>
                          f.required && v == null ? 'Choose an option' : null,
                    )
                  : TextFormField(
                      controller: controllers[f.key],
                      maxLines: f.multiline ? 5 : 1,
                      keyboardType: f.keyboard,
                      decoration: InputDecoration(labelText: f.label),
                      validator: (v) =>
                          f.required && (v == null || v.trim().isEmpty)
                          ? 'This field is required'
                          : null,
                    ),
            ),
          if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          FilledButton(
            onPressed: busy ? null : submit,
            child: Text(busy ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    ),
  );
}
