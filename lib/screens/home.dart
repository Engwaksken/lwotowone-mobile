import 'package:flutter/material.dart';

import '../services/course_progress.dart';
import '../services/repository.dart';
import '../theme.dart';
import '../widgets/ui.dart';
import 'activities.dart';
import 'course.dart';
import 'courses.dart';
import 'inbox.dart';
import 'learner_profile.dart';
import 'profile_tab.dart';

/// The signed-in learner's app: Home, Courses, Activities, Inbox and Profile.
class Home extends StatefulWidget {
  final Repository repo;
  const Home({super.key, required this.repo});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int tab = 0;
  Repository get repo => widget.repo;

  static const titles = [
    'Home',
    'My courses',
    'Activities',
    'Inbox',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => repo.sync());
  }

  bool get profileLocked =>
      (repo.data['user'] as Map?)?['profile_complete'] == false;

  int get unread =>
      repo.rows('notifications').where((n) => n['read_at'] == null).length;

  void open(int index) => setState(() => tab = index);

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: repo,
    builder: (context, _) {
      final inboxCount = unread + repo.pending.length;
      final pages = [
        HomeTab(repo: repo, openTab: open),
        profileLocked ? _ProfileGate(repo: repo) : CoursesTab(repo: repo),
        profileLocked ? _ProfileGate(repo: repo) : ActivitiesTab(repo: repo),
        InboxTab(repo: repo),
        ProfileTab(repo: repo),
      ];
      return Scaffold(
        appBar: tab == 0
            ? null
            : AppBar(
                title: Text(titles[tab]),
                actions: [_SyncButton(repo: repo)],
              ),
        body: SafeArea(
          top: tab == 0,
          child: Column(
            children: [
              _SyncBanner(repo: repo),
              Expanded(
                child: IndexedStack(index: tab, children: pages),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: open,
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            const NavigationDestination(
              icon: Icon(Icons.school_outlined),
              selectedIcon: Icon(Icons.school),
              label: 'Courses',
            ),
            const NavigationDestination(
              icon: Icon(Icons.widgets_outlined),
              selectedIcon: Icon(Icons.widgets),
              label: 'Activities',
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: inboxCount > 0,
                label: Text('$inboxCount'),
                child: const Icon(Icons.mail_outline),
              ),
              selectedIcon: Badge(
                isLabelVisible: inboxCount > 0,
                label: Text('$inboxCount'),
                child: const Icon(Icons.mail),
              ),
              label: 'Inbox',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      );
    },
  );
}

class _SyncButton extends StatelessWidget {
  final Repository repo;
  const _SyncButton({required this.repo});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Synchronise',
    onPressed: repo.busy ? null : repo.sync,
    icon: repo.busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.sync),
  );
}

class _SyncBanner extends StatelessWidget {
  final Repository repo;
  const _SyncBanner({required this.repo});

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: const Duration(milliseconds: 300),
    child: repo.message == null
        ? const SizedBox.shrink(key: ValueKey('no-sync-message'))
        : Material(
            key: ValueKey(repo.message),
            color: repo.online ? Brand.greenSoft : Brand.warningSoft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
  );
}

class _ProfileGate extends StatelessWidget {
  final Repository repo;
  const _ProfileGate({required this.repo});

  @override
  Widget build(BuildContext context) {
    final access = repo.data['access'] as Map? ?? const {};
    return PageList(
      onRefresh: repo.sync,
      children: [
        ProfileProgressCard(
          percent: (access['profile_percent'] as num?)?.toInt() ?? 0,
          missing: [
            for (final item in access['profile_missing'] as List? ?? const [])
              '$item',
          ],
          onComplete: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LearnerProfile(repo: repo)),
          ),
        ),
        const Text('This section opens once your learner profile is complete.'),
      ],
    );
  }
}

class HomeTab extends StatelessWidget {
  final Repository repo;
  final void Function(int tab) openTab;
  const HomeTab({super.key, required this.repo, required this.openTab});

  String greeting() {
    final hour = DateTime.now().hour;
    return hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');
  }

  List<Map<String, dynamic>> enrolledCourses() {
    final enrolled = {
      for (final e in repo.rows('enrolments')) '${e['course_id']}',
    };
    return repo
        .rows('courses')
        .where((c) => enrolled.contains('${c['id']}'))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = repo.data['user'] as Map? ?? const {};
    final access = repo.data['access'] as Map? ?? const {};
    final name = '${user['name'] ?? ''}'.trim();
    final firstName = name.isEmpty ? '' : name.split(' ').first;
    final courses = enrolledCourses();
    final current = courses
        .map(
          (c) => (
            course: c,
            progress: CourseProgress.fromData(repo.data, c['id']),
          ),
        )
        .where((c) => c.progress.nextLessonId != null)
        .firstOrNull;
    final certificates = courses
        .where(
          (c) => CourseProgress.fromData(repo.data, c['id']).certificateReady,
        )
        .length;
    final approvedDownloads = repo
        .rows('download_requests')
        .where((r) => r['state'] == 'approved')
        .length;
    final pendingRequests =
        repo
            .rows('download_requests')
            .where((r) => r['state'] == 'pending')
            .length +
        repo
            .rows('enrollment_requests')
            .where((r) => r['status'] == 'pending')
            .length;
    final unread = repo
        .rows('notifications')
        .where((n) => n['read_at'] == null)
        .length;
    final upcoming = repo
        .rows('event_registrations')
        .where((r) => r['status'] == 'registered')
        .firstOrNull;
    final profileLocked = user['profile_complete'] == false;
    return PageList(
      onRefresh: repo.sync,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting(), style: const TextStyle(color: Brand.muted)),
                  Text(
                    firstName.isEmpty ? 'Welcome back' : firstName,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Inbox',
              onPressed: () => openTab(3),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.notifications_none),
              ),
            ),
            _SyncButton(repo: repo),
          ],
        ),
        const SizedBox(height: 14),
        if (profileLocked)
          ProfileProgressCard(
            percent: (access['profile_percent'] as num?)?.toInt() ?? 0,
            missing: [
              for (final item in access['profile_missing'] as List? ?? const [])
                '$item',
            ],
            onComplete: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LearnerProfile(repo: repo)),
            ),
          ),
        _ContinueCard(
          repo: repo,
          course: current?.course ?? courses.firstOrNull,
          progress:
              current?.progress ??
              (courses.isEmpty
                  ? null
                  : CourseProgress.fromData(repo.data, courses.first['id'])),
          onBrowse: () => openTab(1),
        ),
        const SizedBox(height: 14),
        StatGrid([
          StatTile(
            'My courses',
            '${courses.length}',
            Icons.school_outlined,
            onTap: () => openTab(1),
          ),
          StatTile(
            'Lessons done',
            '${repo.rows('lesson_progress').length}',
            Icons.task_alt,
          ),
          StatTile(
            'Certificates',
            '$certificates',
            Icons.workspace_premium_outlined,
          ),
        ]),
        const SectionTitle('For you'),
        if (approvedDownloads > 0)
          NoticeCard(
            icon: Icons.download_done,
            text:
                '$approvedDownloads approved ${approvedDownloads == 1 ? 'download is' : 'downloads are'} ready to save in the app.',
            action: TextButton(
              onPressed: () => openTab(4),
              child: const Text('View'),
            ),
          ),
        if (pendingRequests > 0)
          NoticeCard(
            icon: Icons.hourglass_top,
            warning: true,
            text:
                '$pendingRequests ${pendingRequests == 1 ? 'request is' : 'requests are'} waiting for approval.',
            action: TextButton(
              onPressed: () => openTab(4),
              child: const Text('View'),
            ),
          ),
        if (repo.pending.isNotEmpty)
          NoticeCard(
            icon: Icons.sync_problem,
            warning: true,
            text:
                '${repo.pending.length} saved ${repo.pending.length == 1 ? 'item is' : 'items are'} waiting to synchronise.',
            action: TextButton(
              onPressed: () => openTab(3),
              child: const Text('Review'),
            ),
          ),
        if (upcoming != null)
          NoticeCard(
            icon: Icons.event_available,
            text:
                'You are registered for ${upcoming['event_title'] ?? 'an event'}.',
          ),
        if (approvedDownloads == 0 &&
            pendingRequests == 0 &&
            repo.pending.isEmpty &&
            upcoming == null)
          const Text(
            'You are all caught up.',
            style: TextStyle(color: Brand.muted),
          ),
        if (repo.rows('announcements').isNotEmpty) ...[
          const SectionTitle('Announcements'),
          for (final a in repo.rows('announcements').take(5))
            InfoCard(
              leading: const CircleAvatar(
                backgroundColor: Brand.goldSoft,
                child: Icon(Icons.campaign_outlined, color: Color(0xff8a6400)),
              ),
              title: '${a['title']}',
              body: '${a['body'] ?? ''}',
            ),
        ],
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final Repository repo;
  final Map<String, dynamic>? course;
  final CourseProgress? progress;
  final VoidCallback onBrowse;
  const _ContinueCard({
    required this.repo,
    required this.course,
    required this.progress,
    required this.onBrowse,
  });

  @override
  Widget build(BuildContext context) {
    final current = course;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: Brand.heroGradient,
        borderRadius: BorderRadius.circular(20),
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
            current == null ? 'START LEARNING' : 'CONTINUE LEARNING',
            style: const TextStyle(
              color: Brand.gold,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            current == null ? 'Find a course to join' : '${current['title']}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (current != null && progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress!.percent / 100,
                minHeight: 8,
                backgroundColor: Colors.white24,
                color: Brand.gold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progress!.total == 0
                  ? 'Lessons are being prepared'
                  : '${progress!.completed} of ${progress!.total} lessons · ${progress!.percent}%',
              style: const TextStyle(color: Color(0xffd7e6dd), fontSize: 12),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Brand.gold,
              foregroundColor: Brand.greenDark,
            ),
            onPressed: current == null
                ? onBrowse
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseScreen(repo: repo, course: current),
                    ),
                  ),
            child: Text(current == null ? 'Browse courses' : 'Continue'),
          ),
        ],
      ),
    );
  }
}
