import 'package:flutter/material.dart';

import '../services/repository.dart';

/// Completion bar shared by the overview, profile and learner profile form.
class ProfileProgressCard extends StatelessWidget {
  final int percent;
  final List<String> missing;
  final VoidCallback? onComplete;
  const ProfileProgressCard({
    super.key,
    required this.percent,
    this.missing = const [],
    this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final complete = percent >= 100;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complete
                        ? 'Profile complete'
                        : 'Complete your profile to unlock learning',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xff175742),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: percent / 100,
                minHeight: 10,
                color: const Color(0xff175742),
                backgroundColor: const Color(0xffe8f0eb),
                semanticsLabel: 'Profile completion',
                semanticsValue: '$percent%',
              ),
            ),
            if (!complete) ...[
              const SizedBox(height: 10),
              Text(
                'Courses, lessons, resources, events and opportunities open once your profile is complete.'
                '${missing.isEmpty ? '' : ' Still needed: ${missing.join(', ')}.'}',
              ),
              if (onComplete != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: onComplete,
                    child: const Text('Complete my profile'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class LearnerProfile extends StatefulWidget {
  final Repository repo;
  const LearnerProfile({super.key, required this.repo});
  @override
  State<LearnerProfile> createState() => _LearnerProfileState();
}

class _LearnerProfileState extends State<LearnerProfile> {
  static const genders = ['Female', 'Male', 'Other', 'Prefer not to say'];
  static const impairments = [
    'Physical',
    'Visual',
    'Hearing',
    'Speech',
    'Intellectual',
    'Psychosocial',
    'Multiple',
    'Other',
  ];
  static const educationLevels = [
    'No formal education',
    'Primary',
    'O-Level',
    'A-Level',
    'Certificate',
    'Diploma',
    "Bachelor's degree",
    'Postgraduate',
    'Other',
  ];
  final form = GlobalKey<FormState>();
  late final Map<String, dynamic> user;
  late final TextEditingController name, phone, location, age, employer, goal;
  String? course, gender, urbanRural, settlement, impairment, education;
  bool? refugee, pwd, employed;
  bool busy = false;
  String? error;

  Repository get repo => widget.repo;
  bool get coursePaid => user['learning_access_paid'] == true;
  bool get answered => user['profile_complete'] == true;

  @override
  void initState() {
    super.initState();
    user = Map<String, dynamic>.from(repo.data['user'] as Map? ?? {});
    String text(String key) => (user[key] ?? '').toString();
    name = TextEditingController(text: text('name'));
    phone = TextEditingController(text: text('phone'));
    location = TextEditingController(text: text('location'));
    age = TextEditingController(text: text('learner_age'));
    employer = TextEditingController(text: text('employer_name'));
    goal = TextEditingController(text: text('transformation_objective'));
    course = user['selected_course_id']?.toString();
    gender = genders.contains(user['gender']) ? user['gender'] : null;
    urbanRural = ['Urban', 'Rural'].contains(user['urban_rural'])
        ? user['urban_rural']
        : null;
    impairment = impairments.contains(user['impairment'])
        ? user['impairment']
        : null;
    education = educationLevels.contains(user['education_level'])
        ? user['education_level']
        : null;
    // Refugee and disability default to "no" on the server, so only trust
    // them once the profile has been saved.
    refugee = answered ? user['refugee'] == true : null;
    pwd = answered ? user['pwd'] == true : null;
    employed = user['employed'] == null ? null : user['employed'] == true;
    final current = repo
        .rows('settlements')
        .where((s) => s['name'] == user['settlement']);
    settlement = current.isEmpty ? null : current.first['id'].toString();
    for (final c in [name, phone, location, age, employer, goal]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [name, phone, location, age, employer, goal]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, String> get courses => {
    for (final c in repo.rows('courses')) c['id'].toString(): '${c['title']}',
  };

  int get percent {
    final steps = <bool>[
      name.text.trim().isNotEmpty,
      phone.text.trim().isNotEmpty,
      course != null,
      gender != null,
      int.tryParse(age.text.trim()) != null,
      location.text.trim().isNotEmpty,
      urbanRural != null,
      refugee != null && (refugee == false || settlement != null),
      pwd != null && (pwd == false || impairment != null),
      education != null,
      employed != null &&
          (employed == false || employer.text.trim().isNotEmpty),
    ];
    return (100 * steps.where((s) => s).length / steps.length).round();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) {
      setState(() => error = 'Please answer the highlighted questions.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await repo.profile({
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'selected_course_id': int.parse(course!),
        'gender': gender,
        'location': location.text.trim(),
        'urban_rural': urbanRural,
        'learner_age': int.parse(age.text.trim()),
        'refugee': refugee! ? '1' : '0',
        if (refugee!) 'settlement_id': int.parse(settlement!),
        'pwd': pwd! ? '1' : '0',
        if (pwd!) 'impairment': impairment,
        'education_level': education,
        'employed': employed! ? '1' : '0',
        if (employed!) 'employer_name': employer.text.trim(),
        'transformation_objective': goal.text.trim(),
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Learner profile saved.')));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String? required(String? v) =>
      v == null || v.trim().isEmpty ? 'This field is required' : null;

  Widget choice<T>(
    String label,
    T? value,
    Map<T, String> options,
    ValueChanged<T?> onChanged,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options.entries
          .map(
            (e) => DropdownMenuItem(
              value: e.key,
              child: Text(e.value, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => onChanged(v)),
      validator: (v) => v == null ? 'Choose an option' : null,
    ),
  );

  Widget text(
    TextEditingController c,
    String label, {
    TextInputType keyboard = TextInputType.text,
    String? Function(String?)? validator,
    int lines = 1,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: c,
      keyboardType: keyboard,
      maxLines: lines,
      decoration: InputDecoration(labelText: label),
      validator: validator,
    ),
  );

  Widget heading(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
    child: Text(label, style: Theme.of(context).textTheme.titleMedium),
  );

  @override
  Widget build(BuildContext context) {
    const yesNo = {true: 'Yes', false: 'No'};
    return Scaffold(
      appBar: AppBar(title: const Text('Learner profile')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ProfileProgressCard(percent: percent),
            heading('Personal and course'),
            text(name, 'Full name', validator: required),
            text(
              phone,
              'Phone number',
              keyboard: TextInputType.phone,
              validator: required,
            ),
            if (coursePaid)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Course selection',
                    helperText:
                        'Contact your administrator to change this course.',
                  ),
                  child: Text(courses[course] ?? 'Assigned course'),
                ),
              )
            else
              choice<String>(
                'Course selection',
                courses.containsKey(course) ? course : null,
                courses,
                (v) => course = v,
              ),
            choice<String>('Gender', gender, {
              for (final g in genders) g: g,
            }, (v) => gender = v),
            text(
              age,
              'Age',
              keyboard: TextInputType.number,
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return n == null || n < 10 || n > 100
                    ? 'Enter an age between 10 and 100'
                    : null;
              },
            ),
            heading('Background'),
            text(
              location,
              'Location (village, town or city)',
              validator: required,
            ),
            choice<String>('Urban or rural', urbanRural, const {
              'Urban': 'Urban',
              'Rural': 'Rural',
            }, (v) => urbanRural = v),
            choice<bool>(
              'Are you a refugee?',
              refugee,
              yesNo,
              (v) => refugee = v,
            ),
            if (refugee == true)
              choice<String>('Settlement', settlement, {
                for (final s in repo.rows('settlements'))
                  s['id'].toString(): '${s['name']}',
              }, (v) => settlement = v),
            choice<bool>(
              'Do you have a disability?',
              pwd,
              yesNo,
              (v) => pwd = v,
            ),
            if (pwd == true)
              choice<String>('Impairment type', impairment, {
                for (final i in impairments) i: i,
              }, (v) => impairment = v),
            choice<String>('Education level', education, {
              for (final level in educationLevels) level: level,
            }, (v) => education = v),
            heading('Employment and goals'),
            choice<bool>(
              'Are you currently employed?',
              employed,
              yesNo,
              (v) => employed = v,
            ),
            if (employed == true)
              text(employer, 'Employer name', validator: required),
            text(goal, 'What do you hope to achieve? (optional)', lines: 4),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            FilledButton(
              onPressed: busy ? null : save,
              child: Text(busy ? 'Saving…' : 'Save learner profile'),
            ),
            const SizedBox(height: 8),
            const Text(
              'An internet connection is needed to save your profile.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
