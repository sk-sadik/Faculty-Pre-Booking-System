import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_names.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/widgets/empty_error_views.dart';
import '../../../appointments/domain/entities/appointment.dart';
import '../../../auth/domain/entities/app_user.dart';
import '../../../users/presentation/providers/users_providers.dart';
import '../providers/admin_providers.dart';

/// Admin console: analytics dashboard, user management, departments and
/// the demo-data seeder. Guarded to the admin role by the router.
class AdminHomeScreen extends ConsumerWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin console'),
          actions: [
            IconButton(
              tooltip: 'Profile',
              icon: const Icon(Icons.person_outline),
              onPressed: () => context.push(RouteNames.profile),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Dashboard', icon: Icon(Icons.dashboard_outlined)),
              Tab(text: 'Users', icon: Icon(Icons.group_outlined)),
              Tab(
                  text: 'Departments',
                  icon: Icon(Icons.account_tree_outlined)),
              Tab(text: 'Seed', icon: Icon(Icons.science_outlined)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DashboardTab(),
            _UsersTab(),
            _DepartmentsTab(),
            _SeedTab(),
          ],
        ),
      ),
    );
  }
}

// ---------- Dashboard ----------

class _DashboardTab extends ConsumerWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(usersByRoleProvider(UserRole.student));
    final faculty = ref.watch(usersByRoleProvider(UserRole.faculty));
    final appts = ref.watch(recentAppointmentsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(usersByRoleProvider(UserRole.student));
        ref.invalidate(usersByRoleProvider(UserRole.faculty));
        ref.invalidate(recentAppointmentsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              _CountCard(
                  label: 'Students',
                  value: students.valueOrNull?.length,
                  icon: Icons.school_outlined),
              const SizedBox(width: 8),
              _CountCard(
                  label: 'Faculty',
                  value: faculty.valueOrNull?.length,
                  icon: Icons.work_outline),
              const SizedBox(width: 8),
              _CountCard(
                  label: 'Appointments',
                  value: appts.valueOrNull?.length,
                  icon: Icons.event_note_outlined),
            ],
          ),
          const SizedBox(height: 16),
          Text('Appointments by status',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          appts.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: e.toString()),
            data: (items) {
              final counts = <AppointmentStatus, int>{};
              for (final a in items) {
                counts[a.status] = (counts[a.status] ?? 0) + 1;
              }
              final max = counts.values.fold<int>(
                  1, (m, v) => v > m ? v : m);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final s in AppointmentStatus.values)
                        _BarRow(
                            label: s.value,
                            count: counts[s] ?? 0,
                            max: max),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Text('Faculty by department',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          faculty.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => ErrorState(message: e.toString()),
            data: (items) {
              final counts = <String, int>{};
              for (final f in items) {
                final d = f.department ?? 'Other';
                counts[d] = (counts[d] ?? 0) + 1;
              }
              if (counts.isEmpty) {
                return const Card(
                    child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No faculty yet.')));
              }
              final entries = counts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final max =
                  entries.first.value == 0 ? 1 : entries.first.value;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final e in entries)
                        _BarRow(
                            label: e.key,
                            count: e.value,
                            max: max),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard(
      {required this.label, required this.value, required this.icon});
  final String label;
  final int? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Icon(icon,
                  color: Theme.of(context).colorScheme.primary,
                  semanticLabel: label),
              const SizedBox(height: 6),
              Text('${value ?? '…'}',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(label,
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple bar-chart row (label + proportional bar + count).
class _BarRow extends StatelessWidget {
  const _BarRow(
      {required this.label, required this.count, required this.max});
  final String label;
  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 96,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : count / max,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 28,
              child: Text('$count',
                  textAlign: TextAlign.end,
                  style:
                      const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

// ---------- Users ----------

class _UsersTab extends ConsumerStatefulWidget {
  const _UsersTab();

  @override
  ConsumerState<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends ConsumerState<_UsersTab> {
  UserRole _role = UserRole.student;

  Future<void> _confirmDelete(AppUser u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Remove user?'),
        content: Text(
            '${u.name} (${u.email}) will lose app access. Their Auth account must also be deleted in the Firebase console.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Keep')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(usersRepositoryProvider).deleteUserDoc(u.uid);
      if (mounted) context.showSnack('${u.name} removed.');
    } catch (e) {
      if (mounted) context.showSnack('Could not remove: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(usersByRoleProvider(_role));
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add user',
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add'),
        onPressed: () => showDialog(
          context: context,
          builder: (_) => _AddUserDialog(role: _role),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<UserRole>(
              segments: const [
                ButtonSegment(
                    value: UserRole.student, label: Text('Students')),
                ButtonSegment(
                    value: UserRole.faculty, label: Text('Faculty')),
              ],
              selected: {_role},
              onSelectionChanged: (s) =>
                  setState(() => _role = s.first),
            ),
          ),
          Expanded(
            child: users.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorState(
                  message: e.toString(),
                  onRetry: () => ref
                      .invalidate(usersByRoleProvider(_role))),
              data: (items) {
                if (items.isEmpty) {
                  return const EmptyState(
                      title: 'No users here',
                      subtitle:
                          'Add students or faculty with the button below.');
                }
                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, i) {
                    final u = items[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                            child: Text(u.name.isEmpty
                                ? '?'
                                : u.name[0].toUpperCase())),
                        title: Text(u.name),
                        subtitle: Text(
                            '${u.email}\n${u.department ?? ''}',
                            maxLines: 2),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Remove ${u.name}',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _confirmDelete(u),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddUserDialog extends ConsumerStatefulWidget {
  const _AddUserDialog({required this.role});
  final UserRole role;

  @override
  ConsumerState<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends ConsumerState<_AddUserDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _extra1 = TextEditingController(); // roll no / employee id
  final _extra2 = TextEditingController(); // cabin (faculty)
  String? _department;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _extra1.dispose();
    _extra2.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = ref.read(adminRepositoryProvider);
      final isStudent = widget.role == UserRole.student;
      await repo.createManagedUser(
        email: _email.text.trim(),
        password: _password.text,
        role: widget.role,
        name: _name.text.trim(),
        department: _department,
        rollNumber: isStudent ? _extra1.text.trim() : null,
        year: isStudent ? '1st' : null,
        employeeId: isStudent ? null : _extra1.text.trim(),
        cabinNumber: isStudent ? null : _extra2.text.trim(),
      );
      ref.invalidate(usersByRoleProvider(widget.role));
      if (mounted) {
        Navigator.of(context).pop();
        context.showSnack('Account created. Share the credentials.');
      }
    } catch (e) {
      if (!mounted) return;
      context.showSnack(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = ref.watch(departmentsProvider).valueOrNull;
    final isStudent = widget.role == UserRole.student;
    return AlertDialog(
      title: Text('Add ${isStudent ? 'student' : 'faculty'}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                  controller: _name,
                  decoration:
                      const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Required' : null),
              TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration:
                      const InputDecoration(labelText: 'Email'),
                  validator: (v) => v == null || !v.contains('@')
                      ? 'Enter a valid email'
                      : null),
              TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Temporary password (min 6)'),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Min 6 characters' : null),
              if (deps != null && deps.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _department,
                  decoration:
                      const InputDecoration(labelText: 'Department'),
                  items: deps
                      .map((d) => DropdownMenuItem(
                          value: d, child: Text(d)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _department = v),
                ),
              TextFormField(
                  controller: _extra1,
                  decoration: InputDecoration(
                      labelText: isStudent
                          ? 'Roll number'
                          : 'Employee ID')),
              if (!isStudent)
                TextFormField(
                    controller: _extra2,
                    decoration: const InputDecoration(
                        labelText: 'Cabin number')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Creating…' : 'Create')),
      ],
    );
  }
}

// ---------- Departments ----------

class _DepartmentsTab extends ConsumerWidget {
  const _DepartmentsTab();

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Add department'),
        content: TextField(
            controller: ctrl,
            autofocus: true,
            decoration: const InputDecoration(
                labelText: 'Name (e.g. Chemistry)')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(c).pop(ctrl.text.trim()),
              child: const Text('Add')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    try {
      await ref.read(adminRepositoryProvider).addDepartment(name);
      ref.invalidate(departmentEntriesProvider);
      ref.invalidate(departmentsProvider);
    } catch (e) {
      if (context.mounted) {
        context.showSnack('Could not add: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(departmentEntriesProvider);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add department',
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        onPressed: () => _add(context, ref),
      ),
      body: entries.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorState(
            message: e.toString(),
            onRetry: () =>
                ref.invalidate(departmentEntriesProvider)),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
                title: 'No departments',
                subtitle:
                    'Add departments — registration and directory pick them up live.');
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => Card(
              margin: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: ListTile(
                leading: const Icon(
                    Icons.account_tree_outlined),
                title: Text(items[i].name),
                trailing: IconButton(
                  tooltip: 'Delete ${items[i].name}',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    try {
                      await ref
                          .read(adminRepositoryProvider)
                          .deleteDepartment(items[i].id);
                      ref.invalidate(departmentEntriesProvider);
                      ref.invalidate(departmentsProvider);
                    } catch (e) {
                      if (context.mounted) {
                        context.showSnack('Could not delete: $e',
                            isError: true);
                      }
                    }
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------- Seed ----------

class _SeedTab extends ConsumerStatefulWidget {
  const _SeedTab();

  @override
  ConsumerState<_SeedTab> createState() => _SeedTabState();
}

class _SeedTabState extends ConsumerState<_SeedTab> {
  bool _busy = false;
  String? _done;

  Future<void> _seed() async {
    setState(() {
      _busy = true;
      _done = null;
    });
    try {
      final result = await ref.read(seedServiceProvider).seed();
      if (mounted) setState(() => _done = 'Seeded: $result');
    } catch (e) {
      if (!mounted) return;
      context.showSnack(
          e.toString().replaceFirst('Exception: ', ''),
          isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Demo data',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                SizedBox(height: 8),
                Text(
                    'Creates 2 faculty (aarav.sharma@ / meera.iyer@, password faculty123), '
                    '3 students (rohan@, sana@, dev@, password student123), '
                    'Mon–Fri availability, a blocked date and appointments in every status. '
                    'Runs once; guarded by a marker document.'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: const Icon(Icons.science_outlined),
          label: Text(_busy ? 'Seeding…' : 'Seed demo data'),
          onPressed: _busy ? null : _seed,
        ),
        if (_done != null) ...[
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_done!),
            ),
          ),
        ],
      ],
    );
  }
}
