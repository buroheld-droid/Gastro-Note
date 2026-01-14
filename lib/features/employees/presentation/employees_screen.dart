import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/repository_providers.dart';
import '../domain/employee.dart';
import '../providers/employees_provider.dart';

class EmployeesScreen extends ConsumerStatefulWidget {
  const EmployeesScreen({super.key, required this.restaurantId});
  final String restaurantId;

  @override
  ConsumerState<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends ConsumerState<EmployeesScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final employeesAsync = ref.watch(employeesProvider(widget.restaurantId));

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Mitarbeiter', style: theme.textTheme.headlineSmall),
              const Spacer(),
              FilledButton.icon(
                onPressed: _onCreateEmployee,
                icon: const Icon(Icons.add),
                label: const Text('Neuer Mitarbeiter'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: employeesAsync.when(
              data: (employees) {
                if (employees.isEmpty) {
                  return const Center(child: Text('Keine Mitarbeiter'));
                }
                return ListView.separated(
                  itemCount: employees.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _EmployeeTile(employee: employees[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Fehler: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateEmployee() async {
    final created = await showDialog<Employee?>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmployeeFormDialog(restaurantId: widget.restaurantId),
    );
    if (created != null && mounted) {
      ref.read(invalidateEmployeesProvider)();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mitarbeiter "${created.fullName}" erstellt')),
      );
    }
  }
}

class _EmployeeTile extends ConsumerWidget {
  const _EmployeeTile({required this.employee});
  final Employee employee;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(employee.fullName, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Chip(
                        label: Text(employee.role.label),
                        backgroundColor: _getRoleColor(employee.role),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(employee.status.label),
                        backgroundColor: _getStatusColor(employee.status),
                        labelStyle: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  if (employee.email != null) ...[
                    const SizedBox(height: 4),
                    Text(employee.email!, style: theme.textTheme.bodySmall),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final updated = await showDialog<Employee?>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => _EmployeeFormDialog(employee: employee),
                );
                if (updated != null) {
                  ref.read(invalidateEmployeesProvider)();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Mitarbeiter "${updated.fullName}" aktualisiert',
                      ),
                    ),
                  );
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _onDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mitarbeiter löschen?'),
        content: Text(
          '"${employee.fullName}" wird ausgeblendet (Soft-Delete).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      final repo = ref.read(employeesRepositoryProvider);
      await repo.delete(employee.id);
      ref.read(invalidateEmployeesProvider)();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Mitarbeiter gelöscht')));
    }
  }

  Color _getRoleColor(EmployeeRole role) {
    return switch (role) {
      EmployeeRole.owner => Colors.purple,
      EmployeeRole.manager => Colors.blue,
      EmployeeRole.waiter => Colors.green,
      EmployeeRole.bartender => Colors.orange,
      EmployeeRole.chef => Colors.red,
    };
  }

  Color _getStatusColor(EmployeeStatus status) {
    return switch (status) {
      EmployeeStatus.active => Colors.green,
      EmployeeStatus.inactive => Colors.grey,
      EmployeeStatus.onLeave => Colors.amber,
    };
  }
}

class _EmployeeFormDialog extends ConsumerStatefulWidget {
  const _EmployeeFormDialog({this.employee, this.restaurantId});
  final Employee? employee;
  final String? restaurantId;

  @override
  ConsumerState<_EmployeeFormDialog> createState() =>
      _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends ConsumerState<_EmployeeFormDialog> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _employeeNumberCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _notesCtrl;

  EmployeeRole _role = EmployeeRole.waiter;
  EmployeeStatus _status = EmployeeStatus.active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _firstNameCtrl = TextEditingController(text: e?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: e?.lastName ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _employeeNumberCtrl = TextEditingController(text: e?.employeeNumber ?? '');
    _pinCtrl = TextEditingController(text: e?.pinCode ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');
    _role = e?.role ?? EmployeeRole.waiter;
    _status = e?.status ?? EmployeeStatus.active;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _employeeNumberCtrl.dispose();
    _pinCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employee == null
                      ? 'Neuer Mitarbeiter'
                      : 'Mitarbeiter bearbeiten',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameCtrl,
                        decoration: const InputDecoration(labelText: 'Vorname'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nachname',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _employeeNumberCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Personalnummer',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'E-Mail'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        decoration: const InputDecoration(labelText: 'Telefon'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _pinCtrl,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: 'PIN-Code (optional)',
                    helperText: 'Für schnellen Login am Terminal',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<EmployeeRole>(
                        value: _role,
                        items: EmployeeRole.values
                            .map(
                              (r) => DropdownMenuItem(
                                value: r,
                                child: Text(r.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _role = v ?? EmployeeRole.waiter),
                        decoration: const InputDecoration(labelText: 'Rolle'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<EmployeeStatus>(
                        value: _status,
                        items: EmployeeStatus.values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(s.label),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(
                          () => _status = v ?? EmployeeStatus.active,
                        ),
                        decoration: const InputDecoration(labelText: 'Status'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notizen',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Abbrechen'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _saving ? null : _onSave,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSave() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final employeeNumber = _employeeNumberCtrl.text.trim();

    if (firstName.isEmpty || lastName.isEmpty || employeeNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Vorname, Nachname und Personalnummer eingeben'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = ref.read(employeesRepositoryProvider);
      Employee result;

      if (widget.employee == null) {
        result = await repo.create(
          Employee(
            id: 'temp',
            restaurantId: widget.restaurantId ?? '',
            employeeNumber: employeeNumber,
            firstName: firstName,
            lastName: lastName,
            email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text.trim(),
            pinCode: _pinCtrl.text.isEmpty ? null : _pinCtrl.text.trim(),
            role: _role,
            status: _status,
            notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      } else {
        final e = widget.employee!;
        result = await repo.update(
          Employee(
            id: e.id,
            restaurantId: e.restaurantId,
            employeeNumber: employeeNumber,
            firstName: firstName,
            lastName: lastName,
            email: _emailCtrl.text.isEmpty ? null : _emailCtrl.text.trim(),
            phone: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text.trim(),
            pinCode: _pinCtrl.text.isEmpty ? null : _pinCtrl.text.trim(),
            role: _role,
            status: _status,
            notes: _notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim(),
            createdAt: e.createdAt,
            updatedAt: DateTime.now(),
            deletedAt: e.deletedAt,
          ),
        );
      }

      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
