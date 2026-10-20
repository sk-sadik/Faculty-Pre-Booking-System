import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../appointments/presentation/providers/slot_providers.dart';
import '../../../users/presentation/providers/users_providers.dart';

/// Searchable faculty directory with department + "available today" filters.
class FacultyDirectoryScreen extends ConsumerStatefulWidget {
  const FacultyDirectoryScreen({super.key});

  @override
  ConsumerState<FacultyDirectoryScreen> createState() =>
      _FacultyDirectoryScreenState();
}

class _FacultyDirectoryScreenState
    extends ConsumerState<FacultyDirectoryScreen> {
  final _search = TextEditingController();
  String _query = '';
  String _department = 'All';
  bool _availableTodayOnly = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final faculty = ref.watch(facultyDirectoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Find faculty')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SearchBar(
              controller: _search,
              hintText: 'Search by name',
              leading: const Icon(Icons.search),
              trailing: _query.isEmpty
                  ? null
                  : [
                      IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      )
                    ],
              onChanged: (v) =>
                  setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: _DepartmentFilter(
                    value: _department,
                    onChanged: (v) =>
                        setState(() => _department = v ?? 'All'),
                  ),
                ),
                const SizedBox(width: 12),
                FilterChip(
                  label: const Text('Available today'),
                  avatar: const Icon(Icons.bolt_outlined, size: 18),
                  selected: _availableTodayOnly,
                  onSelected: (v) =>
                      setState(() => _availableTodayOnly = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: faculty.when(
              loading: () => const SkeletonList(),
              error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () =>
                      ref.invalidate(facultyDirectoryProvider)),
              data: (all) {
                var items = all;
                if (_department != 'All') {
                  items = items
                      .where((f) => f.department == _department)
                      .toList();
                }
                if (_query.isNotEmpty) {
                  items = items
                      .where((f) =>
                          f.name.toLowerCase().contains(_query))
                      .toList();
                }
                if (_availableTodayOnly) {
                  items = items.where((f) {
                    final avail = ref
                        .watch(facultyAvailableTodayProvider(f.uid))
                        .valueOrNull;
                    // Show rows still loading; they resolve live.
                    return avail ?? true;
                  }).toList();
                }
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No faculty found',
                    subtitle:
                        'Try a different name, department or filter.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(facultyDirectoryProvider),
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) =>
                        _FacultyRow(faculty: items[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FacultyRow extends ConsumerWidget {  const _FacultyRow({required this.faculty});
  final AppUser faculty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final avail =
        ref.watch(facultyAvailableTodayProvider(faculty.uid)).valueOrNull;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: faculty.photoUrl != null
              ? NetworkImage(faculty.photoUrl!)
              : null,
          child: faculty.photoUrl == null
              ? Text(faculty.name.isEmpty
                  ? '?'
                  : faculty.name[0].toUpperCase())
              : null,
        ),
        title: Text(faculty.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
            '${faculty.designation ?? 'Faculty'} · ${faculty.department ?? ''}\nCabin ${faculty.cabinNumber ?? '—'}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avail == true)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Today',
                    style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () =>
            context.push(RouteNames.facultyDetail(faculty.uid)),
      ),
    );
  }
}

/// Department filter fed by the admin-managed collection with 'All' on
/// top, falling back to the static catalog while loading or on error.
class _DepartmentFilter extends ConsumerWidget {
  const _DepartmentFilter({required this.value, required this.onChanged});
  final String value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(departmentsProvider).valueOrNull;
    final base = (live == null || live.isEmpty)
        ? AppConstants.departments
        : live;
    final items = ['All', ...base];
    return DropdownButtonFormField<String>(
      key: ValueKey(items.join('|')),
      initialValue: items.contains(value) ? value : 'All',
      decoration: const InputDecoration(labelText: 'Department'),
      items: items
          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
