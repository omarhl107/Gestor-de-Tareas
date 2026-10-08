import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../home/presentation/widgets.dart';

final trimestersProvider =
    FutureProvider.autoDispose<List<Trimester>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null) return [];
  return ref.watch(trimesterRepositoryProvider).listByUser(user!.id!);
});

class TrimestersScreen extends ConsumerWidget {
  const TrimestersScreen({super.key});

  Future<void> _upsert(BuildContext context, WidgetRef ref,
      {Trimester? initial}) async {
    final user = ref.read(currentUserProvider)!;
    final name = TextEditingController(text: initial?.name ?? '');
    DateTime start = initial?.startDate ?? DateTime.now();
    DateTime end = initial?.endDate ??
        DateTime.now().add(const Duration(days: 120));
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) {
        return StatefulBuilder(builder: (c, setS) {
          return AlertDialog(
            title: Text(
                initial == null ? 'Nuevo cuatrimestre' : 'Editar cuatrimestre'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Nombre (ej: 2026-1)')),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Inicio: ${Formatters.date(start)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: c,
                        initialDate: start,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (d != null) setS(() => start = d);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Fin: ${Formatters.date(end)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: c,
                        initialDate: end,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100));
                    if (d != null) setS(() => end = d);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.of(c).pop(false),
                  child: const Text('Cancelar')),
              FilledButton(
                  onPressed: () => Navigator.of(c).pop(true),
                  child: const Text('Guardar')),
            ],
          );
        });
      },
    );
    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty) {
      showMsg(context, 'El nombre es obligatorio');
      return;
    }
    final repo = ref.read(trimesterRepositoryProvider);
    if (initial == null) {
      await repo.create(Trimester(
          userId: user.id!,
          name: name.text.trim(),
          startDate: start,
          endDate: end));
    } else {
      await repo.update(Trimester(
          id: initial.id,
          userId: initial.userId,
          name: name.text.trim(),
          startDate: start,
          endDate: end));
    }
    ref.invalidate(trimestersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(trimestersProvider);
    final user = ref.watch(currentUserProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cuatrimestres')),
      drawer: const AppDrawer(current: '/trimesters'),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _upsert(context, ref),
        child: const Icon(Icons.add),
      ),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) {
            return EmptyState(
              message: 'No tienes cuatrimestres.\nCrea el primero para empezar.',
              actionLabel: 'Crear cuatrimestre',
              onAction: () => _upsert(context, ref),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(trimestersProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (c, i) {
                final t = items[i];
                final isActive = user?.currentTrimesterId == t.id;
                return Card(
                  child: ListTile(
                    title: Row(
                      children: [
                        Expanded(child: Text(t.name)),
                        if (isActive)
                          const Chip(
                            label: Text('Actual'),
                            avatar: Icon(Icons.check, size: 16),
                          ),
                      ],
                    ),
                    subtitle: Text(
                        '${Formatters.date(t.startDate)} – ${Formatters.date(t.endDate)}'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        if (v == 'actual') {
                          await ref
                              .read(userRepositoryProvider)
                              .setCurrentTrimester(user!.id!, t.id);
                          await ref
                              .read(sessionProvider.notifier)
                              .refreshUser();
                          ref.invalidate(trimestersProvider);
                        } else if (v == 'edit') {
                          _upsert(context, ref, initial: t);
                        } else if (v == 'del') {
                          final n = await ref
                              .read(trimesterRepositoryProvider)
                              .countSubjects(t.id!);
                          if (!context.mounted) return;
                          final ok = await confirmDialog(
                            context,
                            title: 'Eliminar cuatrimestre',
                            message: n > 0
                                ? 'Tiene $n materia(s) asociada(s) que también se eliminarán (en cascada) junto con sus tareas. ¿Continuar?'
                                : '¿Eliminar "${t.name}"?',
                          );
                          if (ok) {
                            // Si era el actual, limpiarlo primero.
                            if (isActive) {
                              await ref
                                  .read(userRepositoryProvider)
                                  .setCurrentTrimester(user!.id!, null);
                              await ref
                                  .read(sessionProvider.notifier)
                                  .refreshUser();
                            }
                            await ref
                                .read(trimesterRepositoryProvider)
                                .delete(t.id!);
                            ref.invalidate(trimestersProvider);
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'actual',
                            child: Text('Marcar como actual')),
                        PopupMenuItem(
                            value: 'edit', child: Text('Editar')),
                        PopupMenuItem(
                            value: 'del', child: Text('Eliminar')),
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
}
