import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../trimesters/presentation/trimesters_screen.dart';
import '../../home/presentation/widgets.dart';

final selectedTrimesterIdProvider = StateProvider<int?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.currentTrimesterId;
});

final subjectsProvider =
    FutureProvider.autoDispose<List<Subject>>((ref) async {
  final trimId = ref.watch(selectedTrimesterIdProvider);
  if (trimId == null) return [];
  return ref.watch(subjectRepositoryProvider).listByTrimester(trimId);
});

class SubjectsScreen extends ConsumerWidget {
  const SubjectsScreen({super.key});

  Future<void> _upsert(BuildContext context, WidgetRef ref,
      {required int trimesterId, Subject? initial}) async {
    final name = TextEditingController(text: initial?.name ?? '');
    Color color = initial != null
        ? Formatters.colorFromHex(initial.colorHex)
        : Colors.indigo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(builder: (c, setS) {
        return AlertDialog(
          title: Text(initial == null ? 'Nueva materia' : 'Editar materia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                  controller: name,
                  decoration:
                      const InputDecoration(labelText: 'Nombre *')),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Color: '),
                  GestureDetector(
                    onTap: () async {
                      Color tmp = color;
                      final picked = await showDialog<Color>(
                        context: c,
                        builder: (c2) => AlertDialog(
                          title: const Text('Elige un color'),
                          content: SingleChildScrollView(
                            child: BlockPicker(
                              pickerColor: tmp,
                              onColorChanged: (cc) => tmp = cc,
                            ),
                          ),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.of(c2).pop(null),
                                child: const Text('Cancelar')),
                            FilledButton(
                                onPressed: () =>
                                    Navigator.of(c2).pop(tmp),
                                child: const Text('Elegir')),
                          ],
                        ),
                      );
                      if (picked != null) setS(() => color = picked);
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all()),
                    ),
                  ),
                ],
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
      }),
    );
    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty) {
      showMsg(context, 'El nombre es obligatorio');
      return;
    }
    final repo = ref.read(subjectRepositoryProvider);
    if (initial == null) {
      await repo.create(Subject(
        trimesterId: trimesterId,
        name: name.text.trim(),
        colorHex: Formatters.colorToHex(color),
      ));
    } else {
      await repo.update(Subject(
        id: initial.id,
        trimesterId: initial.trimesterId,
        name: name.text.trim(),
        colorHex: Formatters.colorToHex(color),
        createdAt: initial.createdAt,
      ));
    }
    ref.invalidate(subjectsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trims = ref.watch(trimestersProvider);
    final selId = ref.watch(selectedTrimesterIdProvider);
    final subjects = ref.watch(subjectsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Materias')),
      drawer: const AppDrawer(current: '/subjects'),
      floatingActionButton: selId == null
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  _upsert(context, ref, trimesterId: selId),
              child: const Icon(Icons.add),
            ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: trims.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (items) {
                if (items.isEmpty) {
                  return const Text(
                      'Primero crea un cuatrimestre para ver sus materias.');
                }
                return DropdownButtonFormField<int>(
                  initialValue: items.any((t) => t.id == selId)
                      ? selId
                      : null,
                  decoration: const InputDecoration(
                      labelText: 'Cuatrimestre'),
                  items: items
                      .map((t) => DropdownMenuItem(
                          value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) => ref
                      .read(selectedTrimesterIdProvider.notifier)
                      .state = v,
                );
              },
            ),
          ),
          Expanded(
            child: selId == null
                ? const Center(
                    child: Text('Selecciona un cuatrimestre arriba.'))
                : subjects.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (items) {
                      if (items.isEmpty) {
                        return EmptyState(
                          message:
                              'Sin materias en este cuatrimestre.',
                          actionLabel: 'Crear materia',
                          onAction: () => _upsert(context, ref,
                              trimesterId: selId),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async =>
                            ref.invalidate(subjectsProvider),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          itemBuilder: (c, i) {
                            final s = items[i];
                            final color =
                                Formatters.colorFromHex(s.colorHex);
                            return Card(
                              child: ListTile(
                                leading: CircleAvatar(
                                    backgroundColor: color,
                                    child: Text(s.name.isNotEmpty
                                        ? s.name[0].toUpperCase()
                                        : '?')),
                                title: Text(s.name),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (v) async {
                                    if (v == 'edit') {
                                      _upsert(context, ref,
                                          trimesterId: selId,
                                          initial: s);
                                    } else if (v == 'del') {
                                      final n = await ref
                                          .read(subjectRepositoryProvider)
                                          .countTasks(s.id!);
                                      if (!context.mounted) return;
                                      final ok = await confirmDialog(
                                        context,
                                        title: 'Eliminar materia',
                                        message: n > 0
                                            ? 'Tiene $n tarea(s) que también se eliminarán (en cascada). ¿Continuar?'
                                            : '¿Eliminar "${s.name}"?',
                                      );
                                      if (ok) {
                                        await ref
                                            .read(subjectRepositoryProvider)
                                            .delete(s.id!);
                                        ref.invalidate(subjectsProvider);
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Editar')),
                                    PopupMenuItem(
                                        value: 'del',
                                        child: Text('Eliminar')),
                                  ],
                                ),
                              ),
                            );
                          },
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
