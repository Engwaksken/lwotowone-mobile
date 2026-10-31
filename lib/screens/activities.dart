import 'package:flutter/material.dart';

import '../services/earnings.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'action_form.dart';
import 'knowledge_game.dart';

/// The learner's activities beyond courses, opened from the Activities tab.
const activitySections = <String, (IconData, String)>{
  'Practice': (Icons.handyman_outlined, 'Log practical work'),
  'Mentorship': (Icons.groups_outlined, 'Book time with a mentor'),
  'Opportunities': (Icons.work_outline, 'Jobs and openings'),
  'Enterprise': (Icons.storefront_outlined, 'Your business and earnings'),
  'Events': (Icons.event_outlined, 'Trainings and meetups'),
  'Knowledge game': (Icons.quiz_outlined, 'Test what you know'),
};

class ActivitiesTab extends StatelessWidget {
  final Repository repo;
  const ActivitiesTab({super.key, required this.repo});

  String countFor(String section) => switch (section) {
    'Practice' => '${repo.rows('practice_logs').length} logged',
    'Mentorship' => '${repo.rows('slots').length} open sessions',
    'Opportunities' => '${repo.rows('opportunities').length} open',
    'Enterprise' => '${repo.rows('enterprises').length} enterprises',
    'Events' => '${repo.rows('events').length} upcoming',
    _ => 'Play now',
  };

  @override
  Widget build(BuildContext context) => PageList(
    onRefresh: repo.sync,
    children: [
      const Text(
        'Practise, connect and grow beyond your courses.',
        style: TextStyle(color: Brand.muted),
      ),
      const SizedBox(height: 14),
      LayoutBuilder(
        builder: (context, constraints) => GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth > 560 ? 3 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 196,
          ),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final entry in activitySections.entries)
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => entry.key == 'Knowledge game'
                          ? KnowledgeGameScreen(repo: repo)
                          : ActivityScreen(repo: repo, section: entry.key),
                    ),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Brand.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Brand.greenSoft,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(entry.value.$1, color: Brand.green),
                        ),
                        const Spacer(),
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          entry.value.$2,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Brand.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        StatusChip.neutral(countFor(entry.key)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );
}

class ActivityScreen extends StatefulWidget {
  final Repository repo;
  final String section;
  const ActivityScreen({super.key, required this.repo, required this.section});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String search = '';
  bool searchOpen = false;
  EarningsPeriod earningsPeriod = EarningsPeriod.all;
  String? enterpriseFilter;
  DateTimeRange? earningsRange;
  int earningsFilterRevision = 0;
  Repository get repo => widget.repo;
  String get section => widget.section;

  List<Map<String, dynamic>> list(String key) => repo
      .rows(key)
      .where(
        (r) =>
            search.isEmpty ||
            r.values.join(' ').toLowerCase().contains(search.toLowerCase()),
      )
      .toList();

  Map<String, String> options(String key) => {
    for (final r in repo.rows(key))
      r['id'].toString(): (r['title'] ?? r['name']).toString(),
  };

  String today() => DateTime.now().toIso8601String().substring(0, 10);

  Future<void> run(Future<void> Function() action) =>
      runGuarded(context, action);

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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: searchOpen
            ? TextField(
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration.collapsed(
                  hintText: 'Search $section',
                ),
                onChanged: (value) => setState(() => search = value),
              )
            : Text(section),
        actions: [
          IconButton(
            tooltip: searchOpen ? 'Close search' : 'Search',
            onPressed: () => setState(() {
              searchOpen = !searchOpen;
              if (!searchOpen) search = '';
            }),
            icon: Icon(searchOpen ? Icons.close : Icons.search),
          ),
        ],
      ),
      body: PageList(onRefresh: repo.sync, children: content()),
    ),
  );

  List<Widget> content() => switch (section) {
    'Practice' => practice(),
    'Mentorship' => mentorship(),
    'Opportunities' => opportunities(),
    'Enterprise' => enterprise(),
    'Events' => events(),
    _ => const [],
  };

  List<Widget> practice() {
    final logs = repo.rows('practice_logs');
    final minutes = logs.fold<num>(
      0,
      (total, row) => total + (num.tryParse('${row['minutes']}') ?? 0),
    );
    final shown = list('practice_logs');
    return [
      StatGrid([
        StatTile('Activities', '${logs.length}', Icons.handyman_outlined),
        StatTile(
          'Hours logged',
          (minutes / 60).toStringAsFixed(1),
          Icons.schedule_outlined,
        ),
        StatTile(
          'Verified',
          '${logs.where((l) => l['status'] == 'verified').length}',
          Icons.verified_outlined,
        ),
      ]),
      const SizedBox(height: 12),
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
          FormFieldSpec('practised_on', 'Date (YYYY-MM-DD)', value: today()),
        ], offline: true),
        icon: const Icon(Icons.add),
        label: const Text('Add practical log'),
      ),
      const SectionTitle('My activity'),
      if (shown.isEmpty)
        const EmptyState(
          icon: Icons.handyman_outlined,
          title: 'No practical logs yet',
        ),
      for (final r in shown)
        InfoCard(
          title: '${r['title']}',
          body:
              '${r['body']}${(r['feedback'] ?? '').toString().isEmpty ? '' : '\n\nFeedback: ${r['feedback']}'}',
          action: Wrap(
            spacing: 8,
            children: [
              r['status'] == 'verified'
                  ? const StatusChip('Verified', icon: Icons.verified)
                  : StatusChip.neutral('${r['status']}'),
              StatusChip.neutral('${r['minutes']} min'),
              StatusChip.neutral(shortDate(r['practised_on'])),
            ],
          ),
        ),
    ];
  }

  List<Widget> mentorship() => [
    StatGrid([
      StatTile(
        'Mentors',
        '${repo.rows('mentors').length}',
        Icons.groups_outlined,
      ),
      StatTile(
        'Open sessions',
        '${repo.rows('slots').length}',
        Icons.event_available_outlined,
      ),
      StatTile(
        'My requests',
        '${repo.rows('bookings').length}',
        Icons.chat_bubble_outline,
      ),
    ]),
    const SectionTitle('Available sessions'),
    if (list('slots').isEmpty)
      const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No open sessions right now',
      ),
    for (final s in list('slots'))
      InfoCard(
        title: '${s['title']}',
        body:
            '${shortDate(s['starts_at'])} · ${s['mode']}\n${s['location'] ?? ''}',
        action: FilledButton(
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
          child: const Text('Request session (online)'),
        ),
      ),
    const SectionTitle('My requests'),
    if (list('bookings').isEmpty)
      const Text(
        'No session requests yet.',
        style: TextStyle(color: Brand.muted),
      ),
    for (final b in list('bookings'))
      InfoCard(
        title: '${b['session_title'] ?? 'Session request #${b['id']}'}',
        body:
            '${b['mentor_name'] ?? ''} · ${b['mode'] ?? ''} · ${shortDate(b['starts_at'])}\n${b['goal']}\n${b['notes'] ?? ''}',
        trailing: StatusChip.neutral('${b['status']}'),
        action: ['requested', 'confirmed'].contains(b['status'])
            ? Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => run(
                    () => repo.act('cancel-booking', {'booking_id': b['id']}),
                  ),
                  child: const Text('Cancel request'),
                ),
              )
            : null,
      ),
    const SectionTitle('Mentors'),
    for (final m in list('mentors'))
      InfoCard(
        leading: CircleAvatar(
          backgroundColor: Brand.greenSoft,
          child: Text('${m['name']}'.characters.first),
        ),
        title: '${m['name']}',
        body: '${m['expertise'] ?? ''}\n${m['bio'] ?? ''}',
      ),
  ];

  List<Widget> opportunities() => [
    StatGrid([
      StatTile(
        'Open opportunities',
        '${repo.rows('opportunities').length}',
        Icons.work_outline,
      ),
      StatTile(
        'My applications',
        '${repo.rows('applications').length}',
        Icons.assignment_outlined,
      ),
    ]),
    const SectionTitle('Open opportunities'),
    if (list('opportunities').isEmpty)
      const EmptyState(
        icon: Icons.work_off_outlined,
        title: 'No open opportunities',
      ),
    for (final o in list('opportunities'))
      Builder(
        builder: (context) {
          final applications = repo
              .rows('applications')
              .where((a) => a['opportunity_id'] == o['id']);
          return InfoCard(
            title: '${o['title']}',
            body:
                '${o['type']} · ${o['organisation']} · ${o['location']}\nDeadline: ${shortDate(o['deadline'])}\n${o['description']}',
            action: applications.isEmpty
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
                : Align(
                    alignment: Alignment.centerLeft,
                    child: StatusChip(
                      'Application: ${applications.first['status']}',
                    ),
                  ),
          );
        },
      ),
    const SectionTitle('Application history'),
    if (list('applications').isEmpty)
      const Text('No applications yet.', style: TextStyle(color: Brand.muted)),
    for (final a in list('applications'))
      InfoCard(
        title: 'Opportunity #${a['opportunity_id']}',
        body: '${a['feedback'] ?? ''}',
        trailing: StatusChip.neutral('${a['status']}'),
      ),
  ];

  List<Widget> enterprise() {
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
      StatGrid([
        StatTile(
          'Income UGX',
          earnings.income.toStringAsFixed(0),
          Icons.trending_up,
        ),
        StatTile(
          'Expenses UGX',
          earnings.expense.toStringAsFixed(0),
          Icons.trending_down,
        ),
        StatTile(
          'Net UGX',
          earnings.net.toStringAsFixed(0),
          Icons.account_balance_wallet_outlined,
        ),
      ]),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<EarningsPeriod>(
              key: ValueKey('$earningsPeriod-$earningsFilterRevision'),
              initialValue: earningsPeriod,
              isExpanded: true,
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
          ),
          const SizedBox(width: 10),
          Expanded(
            child: DropdownButtonFormField<String>(
              key: ValueKey(enterpriseFilter ?? 'all-enterprises'),
              initialValue: enterpriseFilter ?? '',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Enterprise'),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('All enterprises'),
                ),
                for (final e in repo.rows('enterprises'))
                  DropdownMenuItem(
                    value: e['id'].toString(),
                    child: Text('${e['title']}'),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => enterpriseFilter = value == '' ? null : value),
            ),
          ),
        ],
      ),
      if (earningsPeriod == EarningsPeriod.custom && earningsRange != null)
        TextButton(
          onPressed: selectDates,
          child: Text(
            '${shortDate(earningsRange!.start.toIso8601String())} to ${shortDate(earningsRange!.end.toIso8601String())}',
          ),
        ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
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
                  FormFieldSpec('stage', 'Stage', options: stages),
                ]),
            icon: const Icon(Icons.add),
            label: const Text('Add enterprise'),
          ),
          if (repo.rows('enterprises').isNotEmpty)
            OutlinedButton.icon(
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
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('Record income or expense'),
            ),
        ],
      ),
      const SectionTitle('My enterprises'),
      if (list('enterprises').isEmpty)
        const Text('No enterprises yet.', style: TextStyle(color: Brand.muted)),
      for (final e in list('enterprises'))
        InfoCard(
          title: '${e['title']}',
          body: '${e['idea']}\n${e['business_plan'] ?? ''}',
          trailing: StatusChip.neutral('${e['stage']}'),
          action: Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => form(
                'Edit enterprise',
                'update-enterprise',
                [
                  FormFieldSpec('title', 'Enterprise name', value: e['title']),
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
                    options: stages,
                  ),
                ],
                fixed: {'enterprise_id': e['id']},
              ),
              child: const Text('Edit enterprise'),
            ),
          ),
        ),
      const SectionTitle('Transaction history'),
      const Text(
        'Totals use the reporting period and enterprise filters. Search filters transaction descriptions.',
        style: TextStyle(color: Brand.muted, fontSize: 12),
      ),
      const SizedBox(height: 8),
      if (history.isEmpty) const Text('No transactions match these filters.'),
      for (final t in history)
        Card(
          child: ListTile(
            leading: Icon(
              t['type'] == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
              color: t['type'] == 'income' ? Brand.green : Brand.danger,
            ),
            title: Text('${t['description']}'),
            subtitle: Text('${shortDate(t['occurred_on'])} · ${t['type']}'),
            trailing: Text(
              'UGX ${t['amount']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      const SizedBox(height: 8),
      const Text(
        'Records only. No money is transferred through this app.',
        style: TextStyle(color: Brand.muted, fontSize: 12),
      ),
    ];
  }

  static const stages = {
    'idea': 'Idea',
    'planning': 'Planning',
    'operating': 'Operating',
    'growing': 'Growing',
  };

  List<Widget> events() => [
    StatGrid([
      StatTile(
        'Upcoming events',
        '${repo.rows('events').length}',
        Icons.event_outlined,
      ),
      StatTile(
        'My registrations',
        '${repo.rows('event_registrations').where((r) => r['status'] == 'registered').length}',
        Icons.event_available_outlined,
      ),
    ]),
    const SectionTitle('Upcoming events'),
    if (list('events').isEmpty)
      const EmptyState(
        icon: Icons.event_busy_outlined,
        title: 'No upcoming events',
      ),
    for (final event in list('events'))
      Builder(
        builder: (context) {
          final registrations = repo
              .rows('event_registrations')
              .where((r) => r['event_id'] == event['id']);
          final registration = registrations.isEmpty
              ? null
              : registrations.first;
          final amount = num.tryParse('${event['payment_amount'] ?? ''}') ?? 0;
          final fee = amount <= 0
              ? 'Free'
              : event['fee_due'] == true
              ? 'Fee: ${amount.toStringAsFixed(2)} ${event['currency'] ?? ''}'
                    .trim()
              : 'Free during the free access period';
          return InfoCard(
            title: '${event['title']}',
            body:
                '${event['starts_at']} · ${event['location']}\n$fee\n${event['description']}',
            action: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (registration != null)
                  StatusChip('Registration: ${registration['status']}'),
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
        },
      ),
    const SectionTitle('My event history'),
    if (repo.rows('event_registrations').isEmpty)
      const Text(
        'No event registrations yet.',
        style: TextStyle(color: Brand.muted),
      ),
    for (final r in repo.rows('event_registrations'))
      InfoCard(
        title: '${r['event_title'] ?? 'Event #${r['event_id']}'}',
        trailing: StatusChip.neutral('${r['status']}'),
        action:
            r['can_cancel'] == true &&
                !repo.rows('events').any((e) => e['id'] == r['event_id'])
            ? TextButton(
                onPressed: repo.busy ? null : () => cancelEvent(r),
                child: const Text('Cancel registration'),
              )
            : null,
      ),
  ];

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
}
