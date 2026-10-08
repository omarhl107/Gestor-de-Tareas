import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../auth/presentation/auth_providers.dart';

/// Formulario nueva/editar tarea (bottom sheet o diálogo).
/// Filtra materias SOLO del cuatrimestre actual del usuario.
class TaskFormSheet extends ConsumerStatefulWidget {
  final Task? initial;
  const TaskFormSheet({super.key, this.initial});

  @override
  ConsumerState<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends ConsumerState<TaskFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  int? _subjectId;
  DateTime _due = DateTime.now().add(const Duration(days: 1));
  int _priority = 0;
  bool _saving = false;
  List<Subject> _subjects = [];
  bool _loadingSubjects = true;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _desc = TextEditingController(text: widget.initial?.description ?? '');
    _due = widget.initial?.dueDate ?? _due;
    _priority = widget.initial?.priority ?? 0;
    _subjectId = widget.initial?.subjectId;
    _load();
  }

  Future<void> _load() async {
    final user = ref.read(currentUserProvider);
    final trimId = user?.currentTrimesterId;
    if (trimId != null) {
      final list = await ref
          .read(subjectRepositoryProvider)
          .listByTrimester(trimId);
      if (!mounted) return;
      setState(() {
        _subjects = list;
        _loadingSubjects = false;
        if (_subjectId != null &&
            !_subjects.any((s) => s.id == _subjectId)) {
          _subjectId = null; // la materia inicial no es del trimestre actual
        }
      });
    } else {
      if (!mounted) return;
      setState(() => _loadingSubjects = false);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_due),
    );
    if (t == null) return;
    setState(() {
      _due = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectId == null) {
      showMsg(context, 'Selecciona una materia');
      return;
    }
    setState(() => _saving = true);
    try {
      final user = ref.read(currentUserProvider)!;
      final repo = ref.read(taskRepositoryProvider);
      if (widget.initial == null) {
        await repo.create(Task(
          userId: user.id!,
          subjectId: _subjectId!,
          title: _title.text.trim(),
          description:
              _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          dueDate: _due,
          priority: _priority,
        ));
      } else {
        final old = widget.initial!;
        await repo.update(old.copyWith(
          subjectId: _subjectId!,
          title: _title.text.trim(),
          description:
              _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          dueDate: _due,
          priority: _priority,
        ));
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showMsg(context, 'Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? 'Nueva tarea' : 'Editar tarea',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                decoration:
                    const InputDecoration(labelText: 'Título *'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El título es obligatorio'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _desc,
                maxLines: 3,
                decoration: const InputDecoration(
                    labelText: 'Descripción (opcional)'),
              ),
              const SizedBox(height: 12),
              if (_loadingSubjects)
                const Center(child: CircularProgressIndicator())
              else if (_subjects.isEmpty)
                const Text(
                    'No hay materias en tu cuatrimestre actual. Crea una primero en Materias.'),
              if (_subjects.isNotEmpty)
                DropdownButtonFormField<int>(
                  initialValue: _subjectId,
                  decoration:
                      const InputDecoration(labelText: 'Materia *'),
                  items: _subjects
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: Formatters.colorFromHex(
                                        s.colorHex),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(s.name),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _subjectId = v),
                  validator: (v) =>
                      v == null ? 'Selecciona una materia' : null,
                ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                    'Entrega: ${Formatters.dateTime(_due)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDateTime,
              ),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                      value: 0, label: Text('Común'), icon: Icon(Icons.flag_outlined)),
                  ButtonSegment(
                      value: 1,
                      label: Text('Prioritario'),
                      icon: Icon(Icons.flag)),
                ],
                selected: {_priority},
                onSelectionChanged: (s) =>
                    setState(() => _priority = s.first),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(widget.initial == null
                          ? 'Guardar'
                          : 'Actualizar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre el formulario; si no hay cuatrimestre actual pide crearlo antes.
Future<bool> openTaskForm(BuildContext context, WidgetRef ref,
    {Task? initial}) async {
  final user = ref.read(currentUserProvider);
  if (user?.currentTrimesterId == null && initial == null) {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Sin cuatrimestre actual'),
        content: const Text(
            'Necesitas crear o seleccionar un cuatrimestre actual antes de crear tareas. ¿Ir a Cuatrimestres?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Ahora no')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Ir')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      // Navegación manejada por el caller vía go_router normalmente.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ve a Cuatrimestres y marca uno como actual')));
    }
    if (go != true) return false;
    return false;
  }
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => TaskFormSheet(initial: initial),
  );
  return res ?? false;
}
