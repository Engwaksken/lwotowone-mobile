import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Shows an error from [work] as a snack bar instead of letting it escape.
Future<void> runGuarded(
  BuildContext context,
  Future<void> Function() work,
) async {
  try {
    await work();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), duration: const Duration(seconds: 4)),
  );
}

/// Page body: centred, width-limited and pull-to-refresh.
class PageList extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  const PageList({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
    return onRefresh == null
        ? list
        : RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// A small number-and-label tile.
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  const StatTile(this.label, this.value, this.icon, {super.key, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Brand.line),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Brand.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: Brand.green, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Brand.ink,
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Brand.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Lays stat tiles out two or three per row depending on width.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;
  final int maxColumns;
  const StatGrid(this.tiles, {super.key, this.maxColumns = 3});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (tiles.isEmpty) return const SizedBox.shrink();
      const spacing = 10.0;
      final fit = constraints.maxWidth >= 520
          ? maxColumns
          : math.min(2, maxColumns);
      final columns = math.min(tiles.length, fit);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles)
              SizedBox(width: width, height: 70, child: tile),
          ],
        ),
      );
    },
  );
}

/// Title, body text and optional actions in a card.
class InfoCard extends StatelessWidget {
  final String title;
  final String body;
  final Widget? leading;
  final Widget? trailing;
  final Widget? action;
  final VoidCallback? onTap;
  const InfoCard({
    super.key,
    required this.title,
    this.body = '',
    this.leading,
    this.trailing,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (body.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          body.trim(),
                          style: const TextStyle(
                            color: Brand.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
            if (action != null) ...[const SizedBox(height: 12), action!],
          ],
        ),
      ),
    ),
  );
}

class StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;
  const StatusChip(
    this.label, {
    super.key,
    this.color = Brand.green,
    this.background = Brand.greenSoft,
    this.icon,
  });

  const StatusChip.warning(
    this.label, {
    super.key,
    this.icon = Icons.hourglass_top,
  }) : color = const Color(0xff7a5300),
       background = Brand.warningSoft;

  const StatusChip.neutral(this.label, {super.key, this.icon})
    : color = Brand.muted,
      background = const Color(0xffeef1ee);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
    child: Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: Brand.greenSoft,
          child: Icon(icon, color: Brand.green, size: 28),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.muted),
          ),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ],
    ),
  );
}

/// A soft coloured notice, for things the learner should know or act on.
class NoticeCard extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;
  final bool warning;
  const NoticeCard({
    super.key,
    required this.icon,
    required this.text,
    this.action,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: warning ? Brand.warningSoft : Brand.greenSoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Icon(icon, color: warning ? const Color(0xff7a5300) : Brand.green),
        const SizedBox(width: 12),
        Expanded(child: Text(text)),
        if (action != null) ...[const SizedBox(width: 8), action!],
      ],
    ),
  );
}

/// Asks for an optional short message before sending a request. Returns null when cancelled.
Future<String?> askForMessage(
  BuildContext context, {
  required String title,
  required String label,
  required String confirm,
  String? explanation,
}) => showDialog<String>(
  context: context,
  builder: (context) => _MessageDialog(
    title: title,
    label: label,
    confirm: confirm,
    explanation: explanation,
  ),
);

class _MessageDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirm;
  final String? explanation;
  const _MessageDialog({
    required this.title,
    required this.label,
    required this.confirm,
    this.explanation,
  });

  @override
  State<_MessageDialog> createState() => _MessageDialogState();
}

class _MessageDialogState extends State<_MessageDialog> {
  final controller = TextEditingController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.explanation != null) ...[
            Text(widget.explanation!),
            const SizedBox(height: 12),
          ],
          TextField(
            controller: controller,
            maxLength: 1000,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(labelText: widget.label),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, controller.text.trim()),
        child: Text(widget.confirm),
      ),
    ],
  );
}

String formatBytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

String shortDate(Object? value) {
  final parsed = DateTime.tryParse('${value ?? ''}');
  if (parsed == null) return '${value ?? ''}';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final local = parsed.toLocal();
  return '${local.day} ${months[local.month - 1]} ${local.year}';
}
