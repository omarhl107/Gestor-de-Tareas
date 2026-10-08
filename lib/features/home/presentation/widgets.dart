import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../auth/presentation/auth_providers.dart';

/// Drawer lateral con navegación + cerrar sesión con confirmación.
class AppDrawer extends ConsumerWidget {
  final String current;
  const AppDrawer({super.key, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(user?.name ?? ''),
              accountEmail: Text(user?.email ?? ''),
              currentAccountPicture: CircleAvatar(
                backgroundImage: user?.profileImagePath != null
                    ? FileImage(File(user!.profileImagePath!))
                    : null,
                child: user?.profileImagePath == null
                    ? Text((user?.name.isNotEmpty ?? false)
                        ? user!.name[0].toUpperCase()
                        : '?')
                    : null,
              ),
            ),
            _item(context, Icons.home, 'Inicio', '/home', current == '/home'),
            _item(context, Icons.calendar_month, 'Cuatrimestres',
                '/trimesters', current == '/trimesters'),
            _item(context, Icons.book, 'Materias', '/subjects',
                current == '/subjects'),
            _item(context, Icons.history, 'Historial', '/history',
                current == '/history'),
            _item(context, Icons.person, 'Perfil', '/profile',
                current == '/profile'),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Cerrar sesión'),
              onTap: () async {
                final ok = await confirmDialog(
                  context,
                  title: 'Cerrar sesión',
                  message: '¿Seguro que quieres cerrar sesión?',
                  confirmLabel: 'Cerrar sesión',
                );
                if (ok) {
                  await ref.read(sessionProvider.notifier).logout();
                  if (context.mounted) context.go('/login');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, String route,
      bool selected) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      selected: selected,
      selectedTileColor:
          Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      onTap: () {
        Navigator.of(context).pop();
        context.go(route);
      },
    );
  }
}

/// Card de tarea: título, materia con color, fecha/hora, chip prioridad.
/// Tap en checkbox -> toggle completada. Tap en card -> editar.
class TaskCard extends StatelessWidget {
  final TaskWithSubject item;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  const TaskCard(
      {super.key,
      required this.item,
      required this.onToggle,
      required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final task = item.task;
    final subj = item.subject;
    final color =
        subj != null ? Formatters.colorFromHex(subj.colorHex) : Colors.grey;
    return Card(
      child: InkWell(
        onTap: onEdit,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: color, width: 5)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ListTile(
            leading: Checkbox(
              value: task.isCompleted,
              onChanged: (_) => onToggle(),
            ),
            title: Text(task.title,
                style: TextStyle(
                    decoration:
                        task.isCompleted ? TextDecoration.lineThrough : null)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subj != null)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(subj.name,
                        style: TextStyle(
                            color: color, fontWeight: FontWeight.w600)),
                  ),
                Text(Formatters.dateTime(task.dueDate)),
              ],
            ),
            trailing: task.isPriority
                ? const Chip(
                    label: Text('Prioritario'),
                    avatar: Icon(Icons.flag, size: 16),
                  )
                : const Chip(label: Text('Común')),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío reutilizable.
class EmptyState extends StatelessWidget {
  final String message;
  final String actionLabel;
  final VoidCallback onAction;
  const EmptyState(
      {super.key,
      required this.message,
      required this.actionLabel,
      required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inbox_outlined, size: 72),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
