import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../services/earnings.dart';
import '../services/course_progress.dart';
import 'learning_progress.dart';
import 'action_form.dart';
import 'course.dart';

class Home extends StatefulWidget {
  final Repository repo;
  const Home({super.key, required this.repo});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String section = 'Overview', search = '';
  EarningsPeriod earningsPeriod = EarningsPeriod.all;
  String? enterpriseFilter;
  DateTimeRange? earningsRange;
  int earningsFilterRevision = 0;
  Repository get repo => widget.repo;
  final sections = const {
    'Overview': Icons.dashboard,
    'Learn': Icons.school,
    'Practice': Icons.handyman,
    'Mentorship': Icons.groups,
    'Opportunities': Icons.work,
    'Enterprise': Icons.store,
    'Events': Icons.event,
    'Notifications': Icons.notifications,
    'Pending': Icons.sync,
    'Profile': Icons.person,
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      repo.sync();
    });
  }

  List<Map<String, dynamic>> list(String key) => repo
      .rows(key)
      .where(
        (r) =>
            search.isEmpty ||
            r.values.join(' ').toLowerCase().contains(search.toLowerCase()),
      )
      .toList();
  Future<void> run(Future<void> Function() action) async {
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  void form(
    String title,
    String action,
    List<FormFieldSpec> fields, {
    Map<String, dynamic> fixed = const {},
    bool offline = false,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionForm(
          title: title,
          action: action,
          repo: repo,
          fields: fields,
          fixed: fixed,
          offlineAllowed: offline,
        ),
      ),
    );
  }

  Map<String, String> options(String key) => {
    for (final r in repo.rows(key))
      r['id'].toString(): (r['title'] ?? r['name']).toString(),
  };
  String today() => DateTime.now().toIso8601String().substring(0, 10);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(section == 'Overview' ? 'Lwotowone' : section),
        actions: [
          IconButton(
            tooltip: 'Synchronise',
            onPressed: repo.busy ? null : repo.sync,
            icon: repo.busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            children: [
              const DrawerHeader(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.eco, size: 42),
                    Text(
                      'LWOTOWONE',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Learn → Practice → Create → Earn'),
                  ],
                ),
              ),
              for (final e in sections.entries)
                ListTile(
                  selected: section == e.key,
                  leading: Icon(e.value),
                  title: Text(
                    e.key == 'Pending'
                        ? 'Pending (${repo.pending.length})'
                        : e.key,
                  ),
                  onTap: () {
                    setState(() {
                      section = e.key;
                      search = '';
                    });
                    Navigator.pop(context);
                  },
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (repo.message != null)
            Material(
              color: repo.online
                  ? const Color(0xffe0f0e2)
                  : const Color(0xffffeed1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      repo.online ? Icons.cloud_done : Icons.cloud_off,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        repo.message!,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!['Overview', 'Profile', 'Pending'].contains(section))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                key: ValueKey(section),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search',
                ),
                onChanged: (v) => setState(() => search = v),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: repo.sync,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: content(),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex:
            ['Overview', 'Learn', 'Mentorship', 'Enterprise'].contains(section)
            ? ['Overview', 'Learn', 'Mentorship', 'Enterprise'].indexOf(section)
            : 0,
        onDestinationSelected: (i) => setState(() {
          section = ['Overview', 'Learn', 'Mentorship', 'Enterprise'][i];
          search = '';
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.school), label: 'Learn'),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Mentor'),
          NavigationDestination(icon: Icon(Icons.store), label: 'Earn'),
        ],
      ),
    ),
  );
  List<Widget> content() {
    switch (section) {
      case 'Overview':
        return [
          Text(
            'Hello, ${repo.data['user']?['name'] ?? 'learner'}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: const Color(0xff163c30),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Text(
            'Skills for Life. Enterprise for Livelihoods. Opportunities for Youth.',
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              stat('Courses', repo.rows('enrolments').length.toString()),
              stat(
                'Lessons completed',
                repo.rows('lesson_progress').length.toString(),
              ),
              stat(
                'Enterprise ideas',
                repo.rows('enterprises').length.toString(),
              ),
              stat('Pending sync', repo.pending.length.toString()),
            ],
          ),
          const SizedBox(height: 24),
          heading('Your next step'),
          for (final key in [
            'Learn',
            'Practice',
            'Mentorship',
            'Opportunities',
            'Enterprise',
          ])
            Card(
              child: ListTile(
                leading: Icon(sections[key]),
                title: Text(key),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => setState(() => section = key),
              ),
            ),
          heading('Announcements'),
          ...repo.rows('announcements').map((r) => card(r['title'], r['body'])),
          const SizedBox(height: 20),
          Text(
            'Last downloaded: ${repo.data['synced_at'] ?? 'Not yet synchronised'}',
            style: const TextStyle(fontSize: 12),
          ),
          const Text(
            'Synchronise while connected to save authorized lessons and course files for offline use. Streaming videos and external links still need internet.',
          ),
        ];
      case 'Learn':
        return emptyAware(
          'courses',
          list('courses').map((c) {
            final enrolled = repo
                .rows('enrolments')
                .any((e) => e['course_id'] == c['id']);
            return card(
              c['title'],
              '${c['level']} · ${c['duration_hours']} hours\n${c['summary']}',
              button: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (enrolled)
                    LearningProgressView(
                      progress: CourseProgress.fromData(repo.data, c['id']),
                    ),
                  FilledButton(
                    onPressed: repo.busy
                        ? null
                        : () => enrolled
                              ? Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CourseScreen(repo: repo, course: c),
                                  ),
                                )
                              : run(
                                  () =>
                                      repo.act('enrol', {'course_id': c['id']}),
                                ),
                    child: Text(
                      enrolled ? 'Open downloaded lessons' : 'Enrol (online)',
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      case 'Practice':
        return [
          FilledButton.icon(
            onPressed: () => form('Record practical activity', 'practice', [
              FormFieldSpec('skill_id', 'Skill', options: options('skills')),
              const FormFieldSpec('title', 'Activity title'),
              const FormFieldSpec(
                'body',
                'Describe your activity and learning',
                multiline: true,
              ),
              const FormFieldSpec(
                'minutes',
                'Minutes spent',
                keyboard: TextInputType.number,
              ),
              FormFieldSpec(
                'practised_on',
                'Date (YYYY-MM-DD)',
                value: today(),
              ),
            ], offline: true),
            icon: const Icon(Icons.add),
            label: const Text('Add practical log'),
          ),
          ...list('practice_logs').map(
            (r) => card(
              r['title'],
              '${r['status']} · ${r['minutes']} minutes · ${r['practised_on']}\n${r['body']}\n${r['feedback'] ?? ''}',
            ),
          ),
        ];
      case 'Mentorship':
        return [
          heading('Mentors'),
          ...list('mentors').map(
            (m) =>
                card(m['name'], '${m['expertise'] ?? ''}\n${m['bio'] ?? ''}'),
          ),
          heading('Available sessions'),
          ...list('slots').map(
            (s) => card(
              s['title'],
              '${s['starts_at']} · ${s['mode']}\n${s['location']}',
              button: FilledButton(
                onPressed: () => form(
                  'Request mentorship',
                  'book',
                  const [
                    FormFieldSpec(
                      'goal',
                      'What would you like help with?',
                      multiline: true,
                    ),
                  ],
                  fixed: {'slot_id': s['id']},
                ),
                child: const Text('Request (online)'),
              ),
            ),
          ),
          heading('My requests'),
          ...list('bookings').map(
            (b) => card(
              b['session_title'] ?? 'Session request #${b['id']}',
              '${b['status']} · ${b['starts_at'] ?? ''}\n${b['mentor_name'] ?? ''} · ${b['mode'] ?? ''}\n${b['location'] ?? ''}\n${b['goal']}\n${b['notes'] ?? ''}',
              button: ['requested', 'confirmed'].contains(b['status'])
                  ? TextButton(
                      onPressed: () => run(
                        () =>
                            repo.act('cancel-booking', {'booking_id': b['id']}),
                      ),
                      child: const Text('Cancel request'),
                    )
                  : null,
            ),
          ),
        ];
      case 'Opportunities':
        return [
          heading('Open opportunities'),
          ...list('opportunities').map((o) {
            final applications = repo
                .rows('applications')
                .where((a) => a['opportunity_id'] == o['id']);
            return card(
              o['title'],
              '${o['type']} · ${o['organisation']} · ${o['location']}\nDeadline: ${o['deadline']}\n${o['description']}',
              button: applications.isEmpty
                  ? FilledButton(
                      onPressed: () => form(
                        'Apply for opportunity',
                        'apply',
                        const [
                          FormFieldSpec(
                            'motivation',
                            'Why are you interested?',
                            multiline: true,
                          ),
                        ],
                        fixed: {'opportunity_id': o['id']},
                      ),
                      child: const Text('Apply (online)'),
                    )
                  : Text('Application: ${applications.first['status']}'),
            );
          }),
          heading('Application history'),
          ...list('applications').map(
            (a) => card(
              'Opportunity #${a['opportunity_id']}',
              '${a['status']}\n${a['feedback'] ?? ''}',
            ),
          ),
        ];
      case 'Enterprise':
        final earnings = Earnings.filter(
          repo.rows('transactions'),
          period: earningsPeriod,
          enterpriseId: enterpriseFilter,
          from: earningsRange?.start,
          to: earningsRange?.end,
        );
        final history = earnings.transactions.where(
          (t) =>
              search.isEmpty ||
              t['description'].toString().toLowerCase().contains(
                search.toLowerCase(),
              ),
        );
        return [
          DropdownButtonFormField<EarningsPeriod>(
            key: ValueKey('$earningsPeriod-$earningsFilterRevision'),
            initialValue: earningsPeriod,
            decoration: const InputDecoration(labelText: 'Reporting period'),
            items: EarningsPeriod.values
                .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              if (value == EarningsPeriod.custom) {
                await selectDates();
              } else {
                setState(() => earningsPeriod = value);
              }
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(enterpriseFilter ?? 'all-enterprises'),
            initialValue: enterpriseFilter ?? '',
            decoration: const InputDecoration(labelText: 'Enterprise'),
            items: [
              const DropdownMenuItem(value: '', child: Text('All enterprises')),
              for (final e in repo.rows('enterprises'))
                DropdownMenuItem(
                  value: e['id'].toString(),
                  child: Text(e['title']),
                ),
            ],
            onChanged: (value) =>
                setState(() => enterpriseFilter = value == '' ? null : value),
          ),
          if (earningsPeriod == EarningsPeriod.custom)
            TextButton(
              onPressed: selectDates,
              child: Text(
                '${earningsRange!.start.toIso8601String().substring(0, 10)} to ${earningsRange!.end.toIso8601String().substring(0, 10)}',
              ),
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              stat('Income UGX', earnings.income.toStringAsFixed(0)),
              stat('Expenses UGX', earnings.expense.toStringAsFixed(0)),
              stat('Net UGX', earnings.net.toStringAsFixed(0)),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () =>
                form('Create enterprise idea', 'enterprise', const [
                  FormFieldSpec('title', 'Enterprise name'),
                  FormFieldSpec('sector', 'Sector'),
                  FormFieldSpec('idea', 'Business idea', multiline: true),
                  FormFieldSpec(
                    'business_plan',
                    'Business plan (optional)',
                    multiline: true,
                    required: false,
                  ),
                  FormFieldSpec(
                    'stage',
                    'Stage',
                    options: {
                      'idea': 'Idea',
                      'planning': 'Planning',
                      'operating': 'Operating',
                      'growing': 'Growing',
                    },
                  ),
                ]),
            icon: const Icon(Icons.add),
            label: const Text('Add enterprise'),
          ),
          ...list('enterprises').map(
            (e) => card(
              e['title'],
              '${e['sector']} · ${e['stage']}\n${e['idea']}\n${e['business_plan'] ?? ''}',
              button: TextButton(
                onPressed: () => form(
                  'Edit enterprise',
                  'update-enterprise',
                  [
                    FormFieldSpec(
                      'title',
                      'Enterprise name',
                      value: e['title'],
                    ),
                    FormFieldSpec('sector', 'Sector', value: e['sector']),
                    FormFieldSpec(
                      'idea',
                      'Business idea',
                      multiline: true,
                      value: e['idea'],
                    ),
                    FormFieldSpec(
                      'business_plan',
                      'Business plan (optional)',
                      required: false,
                      multiline: true,
                      value: e['business_plan'],
                    ),
                    FormFieldSpec(
                      'stage',
                      'Stage',
                      value: e['stage'],
                      options: const {
                        'idea': 'Idea',
                        'planning': 'Planning',
                        'operating': 'Operating',
                        'growing': 'Growing',
                      },
                    ),
                  ],
                  fixed: {'enterprise_id': e['id']},
                ),
                child: const Text('Edit enterprise'),
              ),
            ),
          ),
          if (repo.rows('enterprises').isNotEmpty)
            OutlinedButton(
              onPressed: () => form('Record business transaction', 'income', [
                FormFieldSpec(
                  'enterprise_id',
                  'Enterprise',
                  options: options('enterprises'),
                ),
                const FormFieldSpec(
                  'type',
                  'Type',
                  options: {'income': 'Income', 'expense': 'Expense'},
                ),
                const FormFieldSpec(
                  'amount',
                  'Amount (UGX)',
                  keyboard: TextInputType.numberWithOptions(decimal: true),
                ),
                const FormFieldSpec('description', 'Description'),
                FormFieldSpec(
                  'occurred_on',
                  'Date (YYYY-MM-DD)',
                  value: today(),
                ),
              ], offline: true),
              child: const Text('Record income or expense'),
            ),
          const Text(
            'Totals use the reporting period and enterprise filters. Search filters transaction descriptions.',
          ),
          heading('Transaction history'),
          if (history.isEmpty)
            const Text('No transactions match these filters.'),
          ...history.map(
            (t) => card(
              t['description'],
              '${t['occurred_on']} · ${t['type']} · UGX ${t['amount']}',
            ),
          ),
          const Text('Records only. No money is transferred through this app.'),
        ];
      case 'Events':
        return [
          ...list('events').map((event) {
            final registrations = repo
                .rows('event_registrations')
                .where((r) => r['event_id'] == event['id']);
            final registration = registrations.isEmpty
                ? null
                : registrations.first;
            return card(
              event['title'],
              '${event['starts_at']} · ${event['location']}\n${event['description']}',
              button: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (registration != null)
                    Text('Registration: ${registration['status']}'),
                  if ((registration == null ||
                          registration['status'] == 'cancelled') &&
                      event['registration_open'] != false)
                    FilledButton(
                      onPressed: repo.busy
                          ? null
                          : () => run(
                              () => repo.act('register-event', {
                                'event_id': event['id'],
                              }),
                            ),
                      child: Text(
                        registration == null
                            ? 'Register (online)'
                            : 'Register again (online)',
                      ),
                    ),
                  if (event['registration_open'] == false)
                    const Text('Registration is closed.'),
                  if (registration?['can_cancel'] == true)
                    TextButton(
                      onPressed: repo.busy
                          ? null
                          : () => cancelEvent(registration!),
                      child: const Text('Cancel registration'),
                    ),
                ],
              ),
            );
          }),
          heading('My event history'),
          if (repo.rows('event_registrations').isEmpty)
            const Text('No event registrations yet.'),
          ...repo
              .rows('event_registrations')
              .map(
                (r) => card(
                  r['event_title'] ?? 'Event #${r['event_id']}',
                  r['status'],
                  button:
                      r['can_cancel'] == true &&
                          !repo
                              .rows('events')
                              .any((e) => e['id'] == r['event_id'])
                      ? TextButton(
                          onPressed: repo.busy ? null : () => cancelEvent(r),
                          child: const Text('Cancel registration'),
                        )
                      : null,
                ),
              ),
        ];
      case 'Notifications':
        return emptyAware(
          'notifications',
          list('notifications')
              .map(
                (n) => card(
                  n['data']['title'] ?? 'Notification',
                  n['data']['body'] ?? '',
                  button: n['read_at'] == null
                      ? TextButton(
                          onPressed: () => run(() => repo.readNotice(n['id'])),
                          child: const Text('Mark read'),
                        )
                      : const Text('Read'),
                ),
              )
              .toList(),
        );
      case 'Pending':
        return [
          const Text(
            'Work is kept on this device until accepted by the server. Validation failures remain visible below. Discarding removes only the pending device copy.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: repo.busy ? null : repo.sync,
            child: const Text('Synchronise now'),
          ),
          if (repo.pending.isEmpty)
            const Padding(
              padding: EdgeInsets.all(30),
              child: Text('No pending work.'),
            ),
          for (final p in repo.pending)
            card(
              p['action'],
              'Created: ${p['created_at']}\n${p['error'] ?? 'Waiting to synchronise'}',
              button: Wrap(
                children: [
                  if (p['error'] != null)
                    TextButton(
                      onPressed: () => run(() => repo.retry(p['id'])),
                      child: const Text('Retry'),
                    ),
                  TextButton(
                    onPressed: () => discard(p['id']),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            ),
        ];
      case 'Profile':
        final u = repo.data['user'] as Map? ?? {};
        return [
          card(
            u['name'] ?? 'Participant',
            '${u['email'] ?? ''}\n${u['phone'] ?? ''}\n${u['district'] ?? ''}',
          ),
          FilledButton(
            onPressed: () => form('Edit profile', 'profile', [
              FormFieldSpec('name', 'Full name', value: u['name']),
              FormFieldSpec(
                'phone',
                'Phone',
                required: false,
                value: u['phone'],
              ),
              FormFieldSpec(
                'district',
                'District',
                required: false,
                value: u['district'],
              ),
            ]),
            child: const Text('Edit profile'),
          ),
          const SizedBox(height: 20),
          OutlinedButton(onPressed: signOut, child: const Text('Sign out')),
          const Text(
            'Synchronise your pending work before signing out. Sign out requires internet to revoke your session.',
          ),
        ];
      default:
        return [];
    }
  }

  Future<void> cancelEvent(Map<String, dynamic> registration) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel event registration?'),
        content: const Text(
          'Your place will become available to another learner. You can register again if there is space before the event starts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep registration'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel registration'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await run(
        () => repo.act('cancel-event', {'registration_id': registration['id']}),
      );
    }
  }

  Future<void> selectDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      initialDateRange: earningsRange,
    );
    if (mounted) {
      setState(() {
        earningsFilterRevision++;
        if (range != null) {
          earningsRange = range;
          earningsPeriod = EarningsPeriod.custom;
        }
      });
    }
  }

  Widget heading(String title) => Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Text(title, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget stat(String title, String value) => Container(
    width: 150,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: const Border(
        left: BorderSide(color: Color(0xffdfb452), width: 4),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
        Text(title),
      ],
    ),
  );
  Widget card(String title, String body, {Widget? button}) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SelectableText(body),
          if (button != null) ...[const SizedBox(height: 12), button],
        ],
      ),
    ),
  );
  List<Widget> emptyAware(String key, List<Widget> widgets) => widgets.isEmpty
      ? [
          const Padding(
            padding: EdgeInsets.all(30),
            child: Text('No downloaded items. Synchronise to get updates.'),
          ),
        ]
      : widgets;
  Future<void> discard(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard pending work?'),
        content: const Text('This removes the unsent device copy.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok == true) await run(() => repo.discard(id));
  }

  Future<void> signOut() async {
    if (repo.pending.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Synchronise or review and discard pending work first.',
            ),
          ),
        );
      }
      return;
    }
    await run(() => repo.logout());
  }
}
