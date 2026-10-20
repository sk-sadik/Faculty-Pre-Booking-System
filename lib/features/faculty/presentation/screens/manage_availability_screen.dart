import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../availability/domain/entities/availability.dart';
import '../../../availability/presentation/providers/availability_providers.dart';
import 'rule_editor_sheet.dart';

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

String _ruleSummary(AvailabilityRule r) {
  final when = r.isOneOff
      ? (DateTime.tryParse(r.specificDate!) == null
          ? r.specificDate!
          : DateFormat('EEE, MMM d')
              .format(DateTime.parse(r.specificDate!)))
      : _weekdayNames[(r.dayOfWeek ?? 1) - 1];
  return '$when · ${r.startTime}–${r.endTime} · ${r.slotDuration}m';
}

/// Faculty availability manager: weekly recurring rules, one-off slots and
/// blocked dates. All lists are live Firestore streams.
class ManageAvailabilityScreen extends ConsumerWidget {
  const ManageAvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;
    if (uid == null) {
      return const Scaffold(
          body: Center(child: Text('Sign in to continue.')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Availability'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Weekly', icon: Icon(Icons.repeat_outlined)),
              Tab(text: 'One-off', icon: Icon(Icons.event_outlined)),
              Tab(text: 'Blocked', icon: Icon(Icons.block_outlined)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _RulesTab(facultyId: uid, oneOff: false),
            _RulesTab(facultyId: uid, oneOff: true),
            _BlockedTab(facultyId: uid),
          ],
        ),
      ),
    );
  }
}

class _RulesTab extends ConsumerWidget {
  const _RulesTab({required this.facultyId, required this.oneOff});
  final String facultyId;
  final bool oneOff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(facultyRulesProvider(facultyId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: oneOff ? 'Add one-off slot' : 'Add weekly slot',
        icon: const Icon(Icons.add),
        label: Text(oneOff ? 'One-off' : 'Weekly'),
        onPressed: () => showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (_) => RuleEditorSheet(
              facultyId: facultyId, oneOff: oneOff),
        ),
      ),
      body: rules.when(
      loading: () => const SkeletonList(),
      error: (e, _) => ErrorState(
          message: e.toString(),
          onRetry: () =>
              ref.invalidate(facultyRulesProvider(facultyId))),
      data: (all) {
        final items =
            all.where((r) => r.isOneOff == oneOff).toList();
        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(facultyRulesProvider(facultyId)),
          child: items.isEmpty
              ? ListView(children: [
                  EmptyState(
                    title: oneOff
                        ? 'No one-off slots'
                        : 'No weekly slots yet',
                    subtitle: oneOff
                        ? 'Add extra availability for a specific date.'
                        : 'Add your recurring weekly office hours.',
                  )
                ])
              : ListView.builder(
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return const SizedBox(height: 88);
                    }
                    final r = items[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          oneOff
                              ? Icons.event_outlined
                              : Icons.repeat_outlined,
                          semanticLabel: oneOff
                              ? 'One-off slot'
                              : 'Weekly slot',
                        ),
                        title: Text(_ruleSummary(r),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(r.isActive
                            ? 'Active — students can book'
                            : 'Paused — hidden from students'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(
                              value: r.isActive,
                              onChanged: (v) async {
                                try {
                                  await ref
                                      .read(
                                          availabilityRepositoryProvider)
                                      .toggleRule(r.id, v);
                                } catch (e) {
                                  if (context.mounted) {
                                    context.showSnack(
                                        'Could not update: $e',
                                        isError: true);
                                  }
                                }
                              },
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Slot options',
                              onSelected: (v) =>
                                  _onMenu(context, ref, v, r),
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit')),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete')),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
      ),
    );
  }

  Future<void> _onMenu(BuildContext context, WidgetRef ref, String v,
      AvailabilityRule r) async {
    final repo = ref.read(availabilityRepositoryProvider);
    if (v == 'edit') {
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (_) =>
            RuleEditorSheet(facultyId: facultyId, existing: r, oneOff: oneOff),
      );
    } else {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Delete slot?'),
          content: Text('${_ruleSummary(r)}\n\nStudents can no longer book it.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(false),
                child: const Text('Keep')),
            FilledButton(
                onPressed: () => Navigator.of(c).pop(true),
                child: const Text('Delete')),
          ],
        ),
      );
      if (ok == true) {
        try {
          await repo.deleteRule(r.id);
        } catch (e) {
          if (context.mounted) {
            context.showSnack('Could not delete: $e', isError: true);
          }
        }
      }
    }
  }
}

class _BlockedTab extends ConsumerStatefulWidget {
  const _BlockedTab({required this.facultyId});
  final String facultyId;

  @override
  ConsumerState<_BlockedTab> createState() => _BlockedTabState();
}

class _BlockedTabState extends ConsumerState<_BlockedTab> {
  Future<void> _add() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final reasonCtrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
            'Block ${DateFormat('EEE, MMM d').format(date)}?'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
              labelText: 'Reason (e.g. Conference)'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(c)
                  .pop(reasonCtrl.text.trim()),
              child: const Text('Block date')),
        ],
      ),
    );
    reasonCtrl.dispose();
    if (reason == null || reason.isEmpty || !mounted) return;
    try {
      await ref.read(availabilityRepositoryProvider).blockDate(
          widget.facultyId, dateKey(date), reason);
    } catch (e) {
      if (mounted) context.showSnack('Could not block: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocked =
        ref.watch(facultyBlockedDatesProvider(widget.facultyId));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Block a date',
        icon: const Icon(Icons.add),
        label: const Text('Block'),
        onPressed: _add,
      ),
      body: blocked.when(
        loading: () => const SkeletonList(),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () => ref.invalidate(
                facultyBlockedDatesProvider(widget.facultyId))),
        data: (items) {
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(
              facultyBlockedDatesProvider(widget.facultyId)),
          child: items.isEmpty
              ? ListView(children: const [
                  EmptyState(
                    title: 'No blocked dates',
                    subtitle:
                        'Block leave, conferences or holidays. Students will see no slots on these days.',
                  )
                ])
              : ListView.builder(
                  itemCount: items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == items.length) {
                      return const SizedBox(height: 88);
                    }
                    final b = items[i];
                    final label = DateTime.tryParse(b.date) == null
                        ? b.date
                        : DateFormat('EEE, MMM d, yyyy')
                            .format(DateTime.parse(b.date));
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: ListTile(
                        leading: const Icon(Icons.block_outlined,
                            semanticLabel: 'Blocked date'),
                        title: Text(label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                        subtitle: Text(b.reason),
                        trailing: IconButton(
                          tooltip: 'Unblock date',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(availabilityRepositoryProvider)
                              .unblockDate(b.id),
                        ),
                      ),
                    );
                  },
                ),
        );
        },
      ),
    );
  }
}
