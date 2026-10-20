import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../appointments/domain/slot_generator.dart';
import '../../../appointments/presentation/providers/slot_providers.dart';
import '../../../availability/domain/entities/availability.dart';
import '../../../availability/presentation/providers/availability_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

/// Faculty profile + cabin + weekly availability + date/slot picker.
/// Selecting a slot continues to the booking form (Phase D booking flow).
class FacultyDetailScreen extends ConsumerStatefulWidget {
  const FacultyDetailScreen({super.key, required this.facultyId});
  final String facultyId;

  @override
  ConsumerState<FacultyDetailScreen> createState() =>
      _FacultyDetailScreenState();
}

class _FacultyDetailScreenState
    extends ConsumerState<FacultyDetailScreen> {
  late DateTime _day;
  TimeSlot? _slot;

  @override
  void initState() {
    super.initState();
    _day = DateTime.now();
  }

  List<DateTime> get _days => List.generate(
      14, (i) => DateTime.now().add(Duration(days: i)));

  @override
  Widget build(BuildContext context) {
    final faculty = ref.watch(userDocProvider(widget.facultyId));
    final rules = ref.watch(facultyRulesProvider(widget.facultyId));
    final key = dateKey(_day);
    final slots =
        ref.watch(freeSlotsProvider((facultyId: widget.facultyId, dateKey: key)));

    return Scaffold(
      appBar: AppBar(title: const Text('Faculty')),
      body: faculty.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(userDocProvider(widget.facultyId))),
        data: (user) {
          if (user == null) {
            return const EmptyState(
                title: 'Faculty not found',
                subtitle: 'This profile may have been removed.');
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _ProfileHeader(facultyId: widget.facultyId),
              _WeeklySummary(rules: rules),
              _DateStrip(
                days: _days,
                selected: _day,
                onPick: (d) => setState(() {
                  _day = d;
                  _slot = null;
                }),
              ),
              _SlotGrid(
                slots: slots,
                selected: _slot,
                onPick: (s) => setState(() => _slot = s),
                facultyId: widget.facultyId,
                dateKeyValue: key,
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: FilledButton(
                  onPressed: _slot == null
                      ? null
                      : () {
                          final s = _slot!;
                          context.push(RouteNames.bookingForm(
                            widget.facultyId,
                            date: key,
                            start: formatHm(s.startMinutes),
                            end: formatHm(s.endMinutes),
                          ));
                        },
                  child: Text(_slot == null
                      ? 'Select a time slot'
                      : 'Continue with ${_slot!.label}'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.facultyId});
  final String facultyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userDocProvider(facultyId)).valueOrNull;
    final avail =
        ref.watch(facultyAvailableTodayProvider(facultyId)).valueOrNull;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundImage: user?.photoUrl != null
                  ? NetworkImage(user!.photoUrl!)
                  : null,
              child: user?.photoUrl == null
                  ? Text(
                      user?.name.isEmpty != false
                          ? '?'
                          : user!.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 28))
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.name ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  Text(
                      '${user?.designation ?? 'Faculty'} · ${user?.department ?? ''}'),
                  Text('Cabin ${user?.cabinNumber ?? '—'}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  if (avail == true)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Available today',
                          style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklySummary extends StatelessWidget {
  const _WeeklySummary({required this.rules});
  final AsyncValue<List<AvailabilityRule>> rules;

  @override
  Widget build(BuildContext context) {
    return rules.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (all) {
        final weekly =
            all.where((r) => !r.isOneOff && r.isActive).toList();
        if (weekly.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Weekly hours not published yet.'),
          );
        }
        final byDay = <int, List<String>>{};
        for (final r in weekly) {
          (byDay[r.dayOfWeek ?? 1] ??= [])
              .add('${r.startTime}–${r.endTime}');
        }
        final days = byDay.keys.toList()..sort();
        return Card(
          margin:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Weekly hours',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                for (final d in days)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                        '${_weekdayNames[d - 1]}: ${byDay[d]!.join(', ')}'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip(
      {required this.days, required this.selected, required this.onPick});
  final List<DateTime> days;
  final DateTime selected;
  final void Function(DateTime) onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Pick a date',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 76,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: days.length,
            itemBuilder: (context, i) {
              final d = days[i];
              final sel = isSameDay(d, selected);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(DateFormat('EEE').format(d),
                          style: const TextStyle(fontSize: 11)),
                      Text('${d.day}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                      Text(DateFormat('MMM').format(d),
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                  selected: sel,
                  showCheckmark: false,
                  onSelected: (_) => onPick(d),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SlotGrid extends ConsumerWidget {
  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.onPick,
    required this.facultyId,
    required this.dateKeyValue,
  });
  final AsyncValue<List<TimeSlot>> slots;
  final TimeSlot? selected;
  final void Function(TimeSlot) onPick;
  final String facultyId;
  final String dateKeyValue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Free slots',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ),
        slots.when(
          loading: () => const Center(
              child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator())),
          error: (e, _) => ErrorState(
              message: e.toString(),
              onRetry: () => ref.invalidate(freeSlotsProvider(
                  (facultyId: facultyId, dateKey: dateKeyValue)))),
          data: (items) {
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                    'No free slots this day (blocked, full or past hours). Try another date.'),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final s in items)
                    ChoiceChip(
                      label: Text(s.label),
                      selected:
                          selected?.startMinutes == s.startMinutes,
                      onSelected: (_) => onPick(s),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
