import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../tasks/presentation/task_form.dart';
import 'widgets.dart';

/// Refresca la lista de pendientes del usuario.
final pendingTasksProvider =
    FutureProvider.autoDispose<List<TaskWithSubject>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null) return [];
  final repo = ref.watch(taskRepositoryProvider);
  return repo.pendingWithSubject(user!.id!);
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _newTask(BuildContext context, WidgetRef ref) async {
    final ok = await openTaskForm(context, ref);
    if (ok) ref.invalidate(pendingTasksProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final pending = ref.watch(pendingTasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Tareas'),
        actions: [
          IconButton(
            tooltip: 'Nueva tarea',
            icon: const Icon(Icons.add),
            onPressed: () => _newTask(context, ref),
          ),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: CircleAvatar(
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
          ),
        ],
      ),
      drawer: const AppDrawer(current: '/home'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _newTask(context, ref),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(pendingTasksProvider);
          await ref.read(pendingTasksProvider.future);
        },
        child: pending.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [Center(child: Text('Error: $e'))],
          ),
          data: (items) {
            if (items.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  EmptyState(
                    message:
                        'No tienes tareas pendientes.\n¡Crea tu primera tarea con el botón +!',
                    actionLabel: 'Nueva tarea',
                    onAction: () => _newTask(context, ref),
                  ),
                ],
              );
            }
            final now = DateTime.now();
            final allTasks = items.map((e) => e.task).toList();
            final upcoming = filterUpcoming3Days(allTasks, now);
            final upIds = upcoming.map((t) => t.id).toSet();
            final upItems =
                items.where((e) => upIds.contains(e.task.id)).toList();
            final restItems =
                items.where((e) => !upIds.contains(e.task.id)).toList();

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text('Próximos 3 días',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (upItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sin vencimientos en los próximos 3 días.'),
                  ),
                for (final it in upItems)
                  TaskCard(
                    item: it,
                    onToggle: () async {
                      await ref
                          .read(taskRepositoryProvider)
                          .toggleCompleted(it.task.id!, true);
                      ref.invalidate(pendingTasksProvider);
                    },
                    onEdit: () async {
                      final ok = await openTaskForm(context, ref,
                          initial: it.task);
                      if (ok) ref.invalidate(pendingTasksProvider);
                    },
                  ),
                const SizedBox(height: 16),
                const Text('Pendientes',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                if (restItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Sin más pendientes.'),
                  ),
                for (final it in restItems)
                  TaskCard(
                    item: it,
                    onToggle: () async {
                      await ref
                          .read(taskRepositoryProvider)
                          .toggleCompleted(it.task.id!, true);
                      ref.invalidate(pendingTasksProvider);
                    },
                    onEdit: () async {
                      final ok = await openTaskForm(context, ref,
                          initial: it.task);
                      if (ok) ref.invalidate(pendingTasksProvider);
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
