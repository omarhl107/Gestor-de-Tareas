import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../trimesters/presentation/trimesters_screen.dart';
import '../../home/presentation/widgets.dart';

class HistoryFilter {
  final int? subjectId;
  final int? trimesterId;
  final DateTime? from;
  final DateTime? to;
  const HistoryFilter({this.subjectId, this.trimesterId, this.from, this.to});
}

final historyFilterProvider =
    StateProvider<HistoryFilter>((ref) => const HistoryFilter());

final historyProvider =
    FutureProvider.autoDispose<List<TaskWithSubject>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user?.id == null) return [];
  final f = ref.watch(historyFilterProvider);
  return ref.watch(taskRepositoryProvider).completedWithSubject(
        user!.id!,
        subjectId: f.subjectId,
        trimesterId: f.trimesterId,
        from: f.from,
        to: f.to,
      );
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyProvider);
    final filter = ref.watch(historyFilterProvider);
    final trims = ref.watch(trimestersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        actions: [
          if (filter.subjectId != null ||
              filter.trimesterId != null ||
              filter.from != null ||
              filter.to != null)
            IconButton(
              tooltip: 'Limpiar filtros',
              icon: const Icon(Icons.filter_alt_off),
              onPressed: () => ref
                  .read(historyFilterProvider.notifier)
                  .state = const HistoryFilter(),
            ),
        ],
      ),
      drawer: const AppDrawer(current: '/history'),
      body: Column(
        children: [
          _FiltersBar(ref: ref, trims: trims, filter: filter),
          Expanded(
            child: history.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (items) {
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Sin tareas completadas con esos filtros.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(historyProvider),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (c, i) {
                      final it = items[i];
                      final t = it.task;
                      final onTime = t.completedAt == null
                          ? true
                          : !t.completedAt!.isAfter(t.dueDate);
                      final color = it.subject != null
                          ? Formatters.colorFromHex(
                              it.subject!.colorHex)
                          : Colors.grey;
                      return Card(
                        child: ListTile(
                          leading: Icon(
                            onTime
                                ? Icons.check_circle
                                : Icons.warning,
                            color: onTime ? Colors.green : Colors.orange,
                          ),
                          title: Text(t.title),
                          subtitle: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              if (it.subject != null)
                                Text(it.subject!.name,
                                    style: TextStyle(
                                        color: color,
                                        fontWeight: FontWeight.w600)),
                              Text(
                                  'Entrega: ${Formatters.dateTime(t.dueDate)}'),
                              Text(
                                  'Completada: ${t.completedAt != null ? Formatters.dateTime(t.completedAt!) : '—'}'),
                              Text(
                                onTime
                                    ? 'Entregada a tiempo'
                                    : 'Entregada fuera de plazo',
                                style: TextStyle(
                                  color: onTime
                                      ? Colors.green
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'uncheck') {
                                await ref
                                    .read(taskRepositoryProvider)
                                    .toggleCompleted(t.id!, false);
                                ref.invalidate(historyProvider);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'uncheck',
                                child:
                                    Text('Desmarcar completada'),
                              ),
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

class _FiltersBar extends ConsumerWidget {
  final WidgetRef ref;
  final AsyncValue<List<Trimester>> trims;
  final HistoryFilter filter;
  const _FiltersBar(
      {required this.ref, required this.trims, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Filtro por cuatrimestre
          trims.when(
            loading: () => const Chip(label: Text('Cuatrimestres...')),
            error: (_, __) => const SizedBox.shrink(),
            data: (items) {
              return DropdownMenu<int?>(
                initialSelection: filter.trimesterId,
                label: const Text('Cuatrimestre'),
                dropdownMenuEntries: [
                  const DropdownMenuEntry<int?>(
                      value: null, label: 'Todos'),
                  for (final t in items)
                    DropdownMenuEntry<int?>(value: t.id, label: t.name),
                ],
                onSelected: (v) => ref
                    .read(historyFilterProvider.notifier)
                    .state = HistoryFilter(
                  subjectId: null, // al cambiar trimestre se resetea materia
                  trimesterId: v,
                  from: filter.from,
                  to: filter.to,
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Filtro por materia (según cuatrimestre o todas del usuario)
          _SubjectFilter(filter: filter),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 16),
            label: Text(filter.from == null && filter.to == null
                ? 'Fechas'
                : '${filter.from != null ? Formatters.date(filter.from!) : '…'} – ${filter.to != null ? Formatters.date(filter.to!) : '…'}'),
            onPressed: () async {
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                initialDateRange: filter.from != null && filter.to != null
                    ? DateTimeRange(start: filter.from!, end: filter.to!)
                    : null,
              );
              if (range != null) {
                ref.read(historyFilterProvider.notifier).state =
                    HistoryFilter(
                  subjectId: filter.subjectId,
                  trimesterId: filter.trimesterId,
                  from: range.start,
                  to: range.end
                      .add(const Duration(hours: 23, minutes: 59)),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _SubjectFilter extends ConsumerWidget {
  final HistoryFilter filter;
  const _SubjectFilter({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trims = ref.watch(trimestersProvider);
    return FutureBuilder<List<Subject>>(
      future: () async {
        final repo = ref.read(subjectRepositoryProvider);
        if (filter.trimesterId != null) {
          return repo.listByTrimester(filter.trimesterId!);
        }
        final ts = trims.valueOrNull ?? [];
        return repo.listByUserTrimesters(
            ts.map((t) => t.id!).toList());
      }(),
      builder: (c, snap) {
        final items = snap.data ?? [];
        return DropdownMenu<int?>(
          initialSelection: filter.subjectId,
          label: const Text('Materia'),
          dropdownMenuEntries: [
            const DropdownMenuEntry<int?>(value: null, label: 'Todas'),
            for (final s in items)
              DropdownMenuEntry<int?>(value: s.id, label: s.name),
          ],
          onSelected: (v) => ref
              .read(historyFilterProvider.notifier)
              .state = HistoryFilter(
            subjectId: v,
            trimesterId: filter.trimesterId,
            from: filter.from,
            to: filter.to,
          ),
        );
      },
    );
  }
}
