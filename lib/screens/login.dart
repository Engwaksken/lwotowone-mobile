import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/repository.dart';

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
  String? error;
  @override
  void dispose() {
    for (final c in [name, email, password, confirm, phone, district]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) return;
    if (register && !consent) {
      setState(
        () => error = 'Please read and accept the terms and privacy notice.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.repo.authenticate({
        'email': email.text.trim(),
        'password': password.text,
        if (register) ...{
          'name': name.text.trim(),
          'phone': phone.text.trim(),
          'district': district.text.trim(),
          'password_confirmation': confirm.text,
          'consent': 1,
        },
      }, register: register);
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
                const Icon(Icons.eco, size: 64, color: Color(0xff175742)),
                const SizedBox(height: 16),
                Text(
                  'LWOTOWONE',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
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
                  CheckboxListTile(
                    value: consent,
                    onChanged: (v) => setState(() => consent = v ?? false),
                    title: const Text(
                      'I agree to the terms and have read the privacy notice.',
                    ),
                  ),
                  Wrap(
                    children: [
                      TextButton(
                        onPressed: () => openPage('/pages/terms'),
                        child: const Text('Read terms'),
                      ),
                      TextButton(
                        onPressed: () => openPage('/pages/privacy'),
                        child: const Text('Privacy notice'),
                      ),
                    ],
                  ),
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
                        }),
                  child: Text(
                    register
                        ? 'Already have an account? Sign in'
                        : 'New here? Create an account',
                  ),
                ),
                if (!register)
                  TextButton(
                    onPressed: () => openPage('/forgot-password'),
                    child: const Text('Forgot password?'),
                  ),
                const SizedBox(height: 12),
                const Text(
                  'Internet is needed to sign in and download learning content. You can read downloaded lessons offline.',
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
  Future<void> openPage(String path) async {
    final uri = Uri.parse(
      Repository.base.replaceFirst(RegExp(r'/api/?$'), '') + path,
    );
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
