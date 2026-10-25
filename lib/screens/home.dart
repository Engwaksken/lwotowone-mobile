import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/repository.dart';
import '../services/earnings.dart';
import '../services/course_progress.dart';
import 'learning_progress.dart';
import 'action_form.dart';
import 'course.dart';
import 'learner_profile.dart';
import 'knowledge_game.dart';

class Home extends StatefulWidget {
  final Repository repo;
  const Home({super.key, required this.repo});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  String section = 'Overview', search = '';
  bool searchOpen = false;
  static const searchableSections = {
    'Learn',
    'Practice',
    'Mentorship',
    'Opportunities',
    'Enterprise',
    'Events',
    'Notifications',
  };
  EarningsPeriod earningsPeriod = EarningsPeriod.all;
  String? enterpriseFilter;
  DateTimeRange? earningsRange;
  int earningsFilterRevision = 0;
  Repository get repo => widget.repo;
  final sections = const {
    'Overview': Icons.dashboard,
    'Learn': Icons.school,
    'Practice': Icons.handyman,
    'Knowledge game': Icons.quiz_outlined,
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

  static const profileGated = {
    'Learn',
    'Practice',
    'Mentorship',
    'Opportunities',
    'Enterprise',
    'Events',
  };
  Map get access => repo.data['access'] as Map? ?? const {};
  // Older cached snapshots have no profile flag; only lock when the server says so.
  bool get profileLocked =>
      (repo.data['user'] as Map?)?['profile_complete'] == false;
  int get profilePercent =>
      (access['profile_percent'] as num?)?.toInt() ?? (profileLocked ? 0 : 100);
  List<String> get profileMissing => [
    for (final item in access['profile_missing'] as List? ?? const [])
      item.toString(),
  ];
  void openLearnerProfile() => Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => LearnerProfile(repo: repo)),
  );
  Widget profileProgress() => ProfileProgressCard(
    percent: profilePercent,
    missing: profileMissing,
    onComplete: openLearnerProfile,
  );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void selectSection(String value) {
    setState(() {
      section = value;
      search = '';
      searchOpen = false;
    });
    Navigator.pop(context);
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
        title: searchOpen
            ? TextField(
                key: ValueKey('search-$section'),
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration.collapsed(
                  hintText: 'Search $section',
                ),
                onChanged: (value) => setState(() => search = value),
              )
            : Text(section == 'Overview' ? 'Lwotowone' : section),
        actions: [
          if (searchableSections.contains(section))
            IconButton(
              tooltip: searchOpen ? 'Close search' : 'Search',
              onPressed: () => setState(() {
                searchOpen = !searchOpen;
                if (!searchOpen) search = '';
              }),
              icon: Icon(searchOpen ? Icons.close : Icons.search),
            ),
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
        width: (MediaQuery.sizeOf(context).width * .86)
            .clamp(280, 360)
            .toDouble(),
        child: SafeArea(
          child: Column(
            children: [
              drawerHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  children: [
                    drawerItem('Overview'),
                    drawerGroup('LEARN & GROW', [
                      'Learn',
                      'Practice',
                      'Mentorship',
                      'Opportunities',
                    ]),
                    drawerGroup('BUSINESS & COMMUNITY', [
                      'Enterprise',
                      'Events',
                      'Knowledge game',
                      'Notifications',
                    ]),
                    drawerGroup('ACCOUNT', ['Pending', 'Profile']),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 4,
                ),
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () {
                  Navigator.pop(context);
                  signOut();
                },
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: repo.message == null
                ? const SizedBox.shrink(key: ValueKey('no-sync-message'))
                : Material(
                    key: ValueKey(repo.message),
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
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: repo.sync,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 960),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: content(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar:
          ['Overview', 'Learn', 'Mentorship', 'Enterprise'].contains(section)
          ? NavigationBar(
              selectedIndex: [
                'Overview',
                'Learn',
                'Mentorship',
                'Enterprise',
              ].indexOf(section),
              onDestinationSelected: (i) => setState(() {
                section = ['Overview', 'Learn', 'Mentorship', 'Enterprise'][i];
                search = '';
                searchOpen = false;
              }),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.dashboard),
                  label: 'Home',
                ),
                NavigationDestination(icon: Icon(Icons.school), label: 'Learn'),
                NavigationDestination(
                  icon: Icon(Icons.groups),
                  label: 'Mentor',
                ),
                NavigationDestination(icon: Icon(Icons.store), label: 'Earn'),
              ],
            )
          : null,
    ),
  );

  Widget drawerHeader() {
    final user = repo.data['user'] as Map? ?? {};
    final name = (user['name'] ?? 'Participant').toString();
    final email = (user['email'] ?? '').toString();
    final photoUrl = (user['profile_photo_url'] ?? '').toString();
    final initial = name.isEmpty ? 'L' : name.characters.first.toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xff174f3d), Color(0xff0e382c)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xffe5c16a),
                foregroundColor: const Color(0xff163c30),
                child: photoUrl.isEmpty
                    ? Text(
                        initial,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      )
                    : ClipOval(
                        child: Image.network(
                          photoUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          headers: {'Authorization': 'Bearer ${repo.token}'},
                          errorBuilder: (_, _, _) =>
                              Center(child: Text(initial)),
                        ),
                      ),
              ),
              const SizedBox(width: 11),
              const Expanded(
                child: Text(
                  'LWOTOWONE',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (email.isNotEmpty)
            Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xffd7e6dd), fontSize: 13),
            ),
          const SizedBox(height: 9),
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    repo.online ? Icons.cloud_done : Icons.cloud_off,
                    size: 15,
                    color: const Color(0xffe5c16a),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    repo.online ? 'Online and synced' : 'Offline-ready',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget drawerGroup(String title, List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.05,
          ),
        ),
      ),
      for (final item in items) drawerItem(item),
    ],
  );

  Widget drawerItem(String item) => Padding(
    padding: EdgeInsets.zero,
    child: ListTile(
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
      minLeadingWidth: 32,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14),
      selected: section == item,
      selectedTileColor: const Color(0xffe7f0e9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      leading: Icon(sections[item]),
      title: Text(
        item == 'Pending' ? 'Pending (${repo.pending.length})' : item,
        style: TextStyle(
          fontWeight: section == item ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      trailing: item == 'Pending' && repo.pending.isNotEmpty
          ? Badge(label: Text('${repo.pending.length}'))
          : profileLocked && profileGated.contains(item)
          ? const Icon(Icons.lock_outline, size: 16, semanticLabel: 'Locked')
          : null,
      onTap: () => selectSection(item),
    ),
  );

  List<Widget> content() {
    if (profileLocked && profileGated.contains(section)) {
      return [
        profileProgress(),
        const Text('This section opens once your learner profile is complete.'),
      ];
    }
    switch (section) {
      case 'Overview':
        final learnerName =
            (repo.data['user'] as Map?)?['name']?.toString().trim() ?? '';
        return [
          if (profileLocked) profileProgress(),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xff174f3d), Color(0xff246b4e)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24174f3d),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LEARNER DASHBOARD',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .76),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  learnerName.isEmpty
                      ? 'Welcome back'
                      : 'Welcome, $learnerName',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          repo.online ? Icons.cloud_done : Icons.cloud_off,
                          size: 16,
                          color: const Color(0xffffd878),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          repo.online ? 'Synced' : 'Offline ready',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          metricCards([
            dashboardStat(
              'Courses',
              repo.rows('enrolments').length.toString(),
              Icons.menu_book_outlined,
            ),
            dashboardStat(
              'Lessons done',
              repo.rows('lesson_progress').length.toString(),
              Icons.task_alt,
            ),
            dashboardStat(
              'My enterprises',
              repo.rows('enterprises').length.toString(),
              Icons.storefront_outlined,
            ),
            dashboardStat(
              'Pending sync',
              repo.pending.length.toString(),
              Icons.sync_problem,
            ),
          ]),
          const SizedBox(height: 24),
          heading('Explore'),
          LayoutBuilder(
            builder: (context, constraints) => GridView.count(
              crossAxisCount: constraints.maxWidth > 620 ? 3 : 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: constraints.maxWidth > 620 ? 3 : 2.5,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final key in [
                  'Learn',
                  'Practice',
                  'Knowledge game',
                  'Mentorship',
                  'Opportunities',
                  'Enterprise',
                  'Events',
                ])
                  quickAction(key),
              ],
            ),
          ),
          if (repo.rows('announcements').isNotEmpty) heading('Updates'),
          ...repo.rows('announcements').map((r) => card(r['title'], r['body'])),
        ];
      case 'Learn':
        final courses = list('courses').map((c) {
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
                                () => repo.act('enrol', {'course_id': c['id']}),
                              ),
                  child: Text(
                    enrolled ? 'Open downloaded lessons' : 'Enrol (online)',
                  ),
                ),
              ],
            ),
          );
        }).toList();
        return [
          metricCards([
            dashboardStat(
              'Available courses',
              repo.rows('courses').length.toString(),
              Icons.menu_book_outlined,
            ),
            dashboardStat(
              'My courses',
              repo.rows('enrolments').length.toString(),
              Icons.school_outlined,
            ),
            dashboardStat(
              'Lessons done',
              repo.rows('lesson_progress').length.toString(),
              Icons.task_alt,
            ),
          ]),
          ...emptyAware('courses', courses),
        ];
      case 'Practice':
        final practiceLogs = repo.rows('practice_logs');
        final minutesPracticed = practiceLogs.fold<num>(
          0,
          (total, row) => total + (num.tryParse('${row['minutes']}') ?? 0),
        );
        return [
          metricCards([
            dashboardStat(
              'Activities',
              practiceLogs.length.toString(),
              Icons.handyman_outlined,
            ),
            dashboardStat(
              'Hours logged',
              (minutesPracticed / 60).toStringAsFixed(1),
              Icons.schedule_outlined,
            ),
          ]),
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
      case 'Knowledge game':
        return [
          card(
            'Farming & poultry quiz',
            'Play a short knowledge challenge, check your score and learn from each answer.',
            button: FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => KnowledgeGameScreen(repo: repo),
                ),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play knowledge game'),
            ),
          ),
        ];
      case 'Mentorship':
        return [
          metricCards([
            dashboardStat(
              'Mentors',
              repo.rows('mentors').length.toString(),
              Icons.groups_outlined,
            ),
            dashboardStat(
              'Sessions',
              repo.rows('slots').length.toString(),
              Icons.event_available_outlined,
            ),
            dashboardStat(
              'My requests',
              repo.rows('bookings').length.toString(),
              Icons.chat_bubble_outline,
            ),
          ]),
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
          metricCards([
            dashboardStat(
              'Open opportunities',
              repo.rows('opportunities').length.toString(),
              Icons.work_outline,
            ),
            dashboardStat(
              'My applications',
              repo.rows('applications').length.toString(),
              Icons.assignment_outlined,
            ),
          ]),
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
          metricCards([
            dashboardStat(
              'Income UGX',
              earnings.income.toStringAsFixed(0),
              Icons.trending_up,
            ),
            dashboardStat(
              'Expenses UGX',
              earnings.expense.toStringAsFixed(0),
              Icons.trending_down,
            ),
            dashboardStat(
              'Net UGX',
              earnings.net.toStringAsFixed(0),
              Icons.account_balance_wallet_outlined,
            ),
          ]),
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
          metricCards([
            dashboardStat(
              'Upcoming events',
              repo.rows('events').length.toString(),
              Icons.event_outlined,
            ),
            dashboardStat(
              'My registrations',
              repo
                  .rows('event_registrations')
                  .where(
                    (registration) => registration['status'] == 'registered',
                  )
                  .length
                  .toString(),
              Icons.event_available_outlined,
            ),
          ]),
          ...list('events').map((event) {
            final registrations = repo
                .rows('event_registrations')
                .where((r) => r['event_id'] == event['id']);
            final registration = registrations.isEmpty
                ? null
                : registrations.first;
            final amount =
                num.tryParse('${event['payment_amount'] ?? ''}') ?? 0;
            final fee = amount <= 0
                ? 'Free'
                : event['fee_due'] == true
                ? 'Fee: ${amount.toStringAsFixed(2)} ${event['currency'] ?? ''}'
                      .trim()
                : 'Free during the free access period';
            return card(
              event['title'],
              '${event['starts_at']} · ${event['location']}\n$fee\n${event['description']}',
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
        final notices = list('notifications')
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
            .toList();
        final unread = repo
            .rows('notifications')
            .where((notice) => notice['read_at'] == null)
            .length;
        return [
          metricCards([
            dashboardStat(
              'Unread',
              unread.toString(),
              Icons.mark_email_unread_outlined,
            ),
            dashboardStat(
              'All notices',
              repo.rows('notifications').length.toString(),
              Icons.notifications_none,
            ),
          ]),
          ...emptyAware('notifications', notices),
        ];
      case 'Pending':
        return [
          metricCards([
            dashboardStat(
              'Pending items',
              repo.pending.length.toString(),
              Icons.sync_problem,
            ),
            dashboardStat(
              'Need attention',
              repo.pending
                  .where((item) => item['error'] != null)
                  .length
                  .toString(),
              Icons.warning_amber_outlined,
            ),
          ]),
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
          metricCards([
            dashboardStat(
              'Profile complete',
              '$profilePercent%',
              Icons.account_circle_outlined,
            ),
            dashboardStat(
              'Pending sync',
              repo.pending.length.toString(),
              Icons.sync_problem,
            ),
          ]),
          if (access.containsKey('profile_percent'))
            ProfileProgressCard(
              percent: profilePercent,
              missing: profileMissing,
            ),
          card(
            u['name'] ?? 'Participant',
            [
              u['email'],
              u['phone'],
              u['location'] ?? u['district'],
            ].where((v) => v != null && '$v'.isNotEmpty).join('\n'),
          ),
          FilledButton.icon(
            onPressed: openLearnerProfile,
            icon: const Icon(Icons.assignment_ind),
            label: Text(
              profileLocked
                  ? 'Complete learner profile'
                  : 'Edit learner profile',
            ),
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
  Widget metricCards(List<Widget> cards) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = 10.0;
      final columns = constraints.maxWidth > 620
          ? math.min(cards.length, 4)
          : 2;
      final width = math.min(
        240.0,
        (constraints.maxWidth - spacing * (columns - 1)) / columns,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards)
              SizedBox(width: width, height: 68, child: card),
          ],
        ),
      );
    },
  );
  Widget dashboardStat(String title, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xffdce5df)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xff175742), size: 20),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: const Color(0xff163c30),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium,
        ),
      ],
    ),
  );

  Widget quickAction(String title) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() {
        section = title;
        search = '';
        searchOpen = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xffdce5df)),
        ),
        child: Row(
          children: [
            Icon(sections[title], color: const Color(0xff175742), size: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
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
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
    await run(() => repo.logout());
  }
}
