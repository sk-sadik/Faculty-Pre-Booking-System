import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/extensions.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../../admin/presentation/providers/admin_providers.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _roll = TextEditingController();
  final _empId = TextEditingController();
  final _designation = TextEditingController();
  final _cabin = TextEditingController();

  UserRole _role = UserRole.student;
  String? _department = AppConstants.departments.first;
  String? _year = AppConstants.years.first;
  bool _obscure = true;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _roll.dispose();
    _empId.dispose();
    _designation.dispose();
    _cabin.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authControllerProvider.notifier).signUp(
            RegisterParams(
              email: _email.text.trim(),
              password: _password.text,
              role: _role,
              name: _name.text.trim(),
              phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
              department: _department,
              rollNumber:
                  _role == UserRole.student ? _roll.text.trim() : null,
              year: _role == UserRole.student ? _year : null,
              employeeId:
                  _role == UserRole.faculty ? _empId.text.trim() : null,
              designation: _role == UserRole.faculty
                  ? _designation.text.trim()
                  : null,
              cabinNumber:
                  _role == UserRole.faculty ? _cabin.text.trim() : null,
            ),
          );
      // Router redirect lands the user on the right home. Nothing else needed.
    } catch (e) {
      debugPrint('Register submit failed: $e');
      if (!mounted) return;
      final msg = e is AuthFailure ? e.message : e.toString();
      context.showSnack(msg, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        title: Text('Create account', style: TextStyle(color: colorScheme.onSurface)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                color: colorScheme.surface,
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Semantics(
                          label: 'Select your role',
                          child: SegmentedButton<UserRole>(
                            segments: const [
                              ButtonSegment(
                                  value: UserRole.student,
                                  label: Text('Student'),
                                  icon: Icon(Icons.school_outlined)),
                              ButtonSegment(
                                  value: UserRole.faculty,
                                  label: Text('Faculty'),
                                  icon: Icon(Icons.person_outline)),
                            ],
                            selected: {_role},
                            onSelectionChanged: (s) =>
                                setState(() => _role = s.first),
                          ),
                        ),
                        const SizedBox(height: 16),
                        AppTextField(
                            label: 'Full name',
                            controller: _name,
                            prefixIcon: const Icon(Icons.person_outline),
                            validator: (v) =>
                                Validators.required(v, 'Name')),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Email',
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          prefixIcon: const Icon(Icons.email_outlined),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Password',
                          controller: _password,
                          obscureText: _obscure,
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip:
                                _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                          ),
                          validator: Validators.password,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Phone (optional)',
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          validator: Validators.phone,
                        ),
                        const SizedBox(height: 12),
                        _DepartmentField(
                          value: _department,
                          onChanged: (v) =>
                              setState(() => _department = v),
                        ),
                        const SizedBox(height: 12),
                        if (_role == UserRole.student) ...[
                          AppTextField(
                            label: 'Roll number',
                            controller: _roll,
                            prefixIcon: const Icon(Icons.badge_outlined),
                            validator: (v) =>
                                Validators.required(v, 'Roll number'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _year,
                            decoration:
                                const InputDecoration(labelText: 'Year'),
                            items: AppConstants.years
                                .map((y) => DropdownMenuItem(
                                    value: y, child: Text('${y} year')))
                                .toList(),
                            onChanged: (v) => setState(() => _year = v),
                          ),
                        ] else ...[
                          AppTextField(
                            label: 'Employee ID',
                            controller: _empId,
                            prefixIcon: const Icon(Icons.badge_outlined),
                            validator: (v) =>
                                Validators.required(v, 'Employee ID'),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Designation',
                            hint: 'e.g. Assistant Professor',
                            controller: _designation,
                            validator: (v) =>
                                Validators.required(v, 'Designation'),
                          ),
                          const SizedBox(height: 12),
                          AppTextField(
                            label: 'Cabin / room number',
                            hint: 'e.g. CS-204',
                            controller: _cabin,
                            prefixIcon:
                                const Icon(Icons.meeting_room_outlined),
                            validator: (v) =>
                                Validators.required(v, 'Cabin number'),
                          ),
                        ],
                        const SizedBox(height: 20),
                        PrimaryButton(
                            label: 'Create account',
                            isLoading: _busy,
                            onPressed: _submit),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Already have an account?'),
                            TextButton(
                              onPressed: () => context.pop(),
                              child: const Text('Sign in'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Admin accounts are assigned by an administrator and cannot self-register.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
}

/// Department picker fed by the admin-managed `departments` collection,
/// falling back to the static catalog while loading or on error.
class _DepartmentField extends ConsumerWidget {
  const _DepartmentField({required this.value, required this.onChanged});
  final String? value;
  final void Function(String?) onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(departmentsProvider).valueOrNull;
    final items = (live == null || live.isEmpty)
        ? AppConstants.departments
        : live;
    final effective =
        value != null && items.contains(value) ? value : items.first;
    return DropdownButtonFormField<String>(
      key: ValueKey(items.join('|')),
      initialValue: effective,
      decoration: const InputDecoration(labelText: 'Department'),
      items: items
          .map((d) => DropdownMenuItem(value: d, child: Text(d)))
          .toList(),
      onChanged: onChanged,
    );
  }
}
