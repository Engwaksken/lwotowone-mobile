import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/repository.dart';
import 'policy_reader.dart';

class Login extends StatefulWidget {
  final Repository repo;
  const Login({super.key, required this.repo});
  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      phone = TextEditingController(),
      district = TextEditingController();
  bool register = false, busy = false, hidden = true, consent = false;
  String language = 'en';
  String? error, successMessage;
  final read = {'terms': false, 'privacy': false};
  Map<String, Map<String, String>>? policyDocs;

  String? get nextUnread =>
      read.entries.where((e) => !e.value).map((e) => e.key).firstOrNull;

  /// Opens a policy; after accepting one, the next unread one opens so the
  /// learner reads both before agreeing.
  Future<void> readPolicy(String key) async {
    policyDocs ??= await widget.repo.policies();
    if (!mounted) return;
    final doc = policyDocs![key]!;
    final accepted = await showPolicyReader(
      context,
      title: doc['title']!,
      body: doc['body']!,
    );
    if (!mounted || !accepted) return;
    setState(() => read[key] = true);
    final next = nextUnread;
    if (next != null) {
      await readPolicy(next);
    } else {
      setState(() => consent = true);
    }
  }

  @override
  void dispose() {
    for (final c in [name, email, password, confirm, phone, district]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (register && nextUnread != null) {
      await readPolicy(nextUnread!);
      if (nextUnread != null) {
        if (mounted) {
          setState(
            () => error =
                'Please read the terms of use and privacy notice to continue.',
          );
        }
        return;
      }
    }
    if (register && !consent) {
      setState(
        () => error = 'Please agree to the terms of use and privacy notice.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      successMessage = null;
    });
    try {
      final wasRegistering = register;
      final response = await widget.repo.authenticate({
        'email': email.text.trim(),
        'password': password.text,
        if (register) ...{
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'district': district.text.trim(),
          'preferred_language': language,
          'password_confirmation': confirm.text,
          'consent': 1,
          'terms_read': 1,
          'privacy_read': 1,
        },
      }, register: wasRegistering);
      if (wasRegistering && response != null && mounted) {
        setState(() {
          register = false;
          successMessage = response;
          password.clear();
          confirm.clear();
          consent = false;
          read.updateAll((_, _) => false);
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Image.asset(
                    'assets/brand/logo.png',
                    width: 136,
                    height: 136,
                    fit: BoxFit.contain,
                    semanticLabel: 'Lwotowone Enterprises Limited',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Learn to Earn. Earn to Grow.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                Text(
                  register ? 'Create your participant account' : 'Welcome back',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (successMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xffe8f2ec),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      successMessage!,
                      style: const TextStyle(color: Color(0xff175742)),
                    ),
                  ),
                if (register) ...[
                  field(name, 'Full name'),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: const InputDecoration(labelText: 'Email address'),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter your email address'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        hidden ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => hidden = !hidden),
                    ),
                  ),
                  validator: (v) => v == null || v.isEmpty
                      ? 'Enter your password'
                      : register && v.length < 12
                      ? 'Use at least 12 characters'
                      : null,
                ),
                const SizedBox(height: 14),
                if (register) ...[
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                    ),
                    validator: (v) =>
                        v != password.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 14),
                  field(phone, 'Phone (optional)', required: false),
                  const SizedBox(height: 14),
                  field(district, 'District (optional)', required: false),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: language,
                    decoration: const InputDecoration(
                      labelText: 'Learning language',
                      helperText:
                          'You see lessons and course content in this language.',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'en', child: Text('English')),
                      DropdownMenuItem(value: 'lg', child: Text('Luganda')),
                    ],
                    onChanged: (value) =>
                        setState(() => language = value ?? 'en'),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Before you create your account, read both documents to the end.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  for (final key in read.keys)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        read[key]!
                            ? Icons.check_circle
                            : Icons.description_outlined,
                        color: read[key]! ? const Color(0xff175742) : null,
                      ),
                      title: Text(
                        key == 'terms' ? 'Terms of use' : 'Privacy notice',
                      ),
                      subtitle: Text(read[key]! ? 'Read' : 'Not read yet'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: busy ? null : () => readPolicy(key),
                    ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: (v) {
                      if (v == true && nextUnread != null) {
                        readPolicy(nextUnread!);
                        return;
                      }
                      setState(() => consent = v ?? false);
                    },
                    title: const Text(
                      'I have read and agree to the terms of use and the privacy notice.',
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Please wait…'
                        : register
                        ? 'Create account'
                        : 'Sign in',
                  ),
                ),
                TextButton(
                  onPressed: busy
                      ? null
                      : () => setState(() {
                          register = !register;
                          error = null;
                          successMessage = null;
                        }),
                  child: Text(
                    register
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
                if (!register)
                  TextButton(
                    onPressed: openForgotPassword,
                    child: const Text('Forgot password?'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Internet is needed to sign in and to watch or read lessons. Lessons saved through an approved download open offline.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget field(TextEditingController c, String label, {bool required = true}) =>
      TextFormField(
        controller: c,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) => v == null || v.trim().isEmpty
                  ? 'This field is required'
                  : null
            : null,
      );
  Future<void> openForgotPassword() async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.https('www.lwotowone.com', '/forgot-password'),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      // Show a useful fallback if the device cannot open the reset page.
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not open the password reset page. Please try again.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}
