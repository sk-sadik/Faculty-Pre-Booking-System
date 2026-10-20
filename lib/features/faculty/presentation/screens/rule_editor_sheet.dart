import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/time_utils.dart';
import '../../../availability/domain/entities/availability.dart';
import '../../../availability/domain/repositories/availability_repository.dart';
import '../../../availability/presentation/providers/availability_providers.dart';

const List<String> _weekdayNames = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun'
];

/// Bottom-sheet form for creating or editing an availability rule.
/// [oneOff] selects a calendar date; otherwise a weekday is picked.
class RuleEditorSheet extends ConsumerStatefulWidget {
  const RuleEditorSheet({
    super.key,
    required this.facultyId,
    this.existing,
    required this.oneOff,
  });

  final String facultyId;
  final AvailabilityRule? existing;
  final bool oneOff;

  @override
  ConsumerState<RuleEditorSheet> createState() => _RuleEditorSheetState();
}

class _RuleEditorSheetState extends ConsumerState<RuleEditorSheet> {
  late int _weekday;
  late DateTime _date;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late int _duration;
  bool _busy = false;

  static const _durations = [15, 20, 30, 45, 60];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _weekday = e?.dayOfWeek ?? DateTime.monday;
    _date = e?.specificDate != null
        ? (DateTime.tryParse(e!.specificDate!) ??
            DateTime.now().add(const Duration(days: 1)))
        : DateTime.now().add(const Duration(days: 1));
    TimeOfDay parse(String? hm, TimeOfDay fallback) {
      if (hm == null) return fallback;
      try {
        final m = parseHm(hm);
        return TimeOfDay(hour: m ~/ 60, minute: m % 60);
      } catch (_) {
        return fallback;
      }
    }

    _start = parse(e?.startTime, const TimeOfDay(hour: 9, minute: 0));
    _end = parse(e?.endTime, const TimeOfDay(hour: 11, minute: 0));
    _duration = e?.slotDuration ?? 30;
    if (!_durations.contains(_duration)) _duration = 30;
  }

  String _hm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    final startM = _start.hour * 60 + _start.minute;
    final endM = _end.hour * 60 + _end.minute;
    if (endM <= startM) {
      context.showSnack('End time must be after start time.',
          isError: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(availabilityRepositoryProvider);
      final input = AvailabilityInput(
        dayOfWeek: widget.oneOff ? null : _weekday,
        specificDate: widget.oneOff ? dateKey(_date) : null,
        startTime: _hm(_start),
        endTime: _hm(_end),
        slotDuration: _duration,
      );
      if (widget.existing == null) {
        await repo.addRule(widget.facultyId, input);
      } else {
        await repo.updateRule(widget.existing!.id, {
          if (!widget.oneOff) 'dayOfWeek': _weekday,
          if (widget.oneOff) 'specificDate': dateKey(_date),
          'startTime': _hm(_start),
          'endTime': _hm(_end),
          'slotDuration': _duration,
        });
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        context.showSnack('Could not save: $e', isError: true);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              widget.existing == null
                  ? (widget.oneOff ? 'Add one-off slot' : 'Add weekly slot')
                  : 'Edit slot',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            if (widget.oneOff)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(DateFormat('EEE, MMM d, yyyy').format(_date)),
                trailing: const Text('Change'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now()
                        .add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              )
            else
              Semantics(
                label: 'Day of week',
                child: Wrap(
                  spacing: 8,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    final selected = _weekday == day;
                    return ChoiceChip(
                      label: Text(_weekdayNames[i]),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _weekday = day),
                    );
                  }),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text('Start ${_hm(_start)}'),
                    onPressed: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text('End ${_hm(_end)}'),
                    onPressed: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(
                  labelText: 'Slot duration (minutes)'),
              items: _durations
                  .map((d) => DropdownMenuItem(
                      value: d, child: Text('$d min')))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _duration = v ?? 30),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white),
                    )
                  : Text(widget.existing == null ? 'Add slot' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
