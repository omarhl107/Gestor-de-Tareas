// Modelos de dominio (código en inglés, textos UI en español).
// Tablas: users, trimesters, subjects, tasks.

class User {
  final int? id;
  final String email;
  final String passwordHash;
  final String name;
  final String? profileImagePath;
  final int? currentTrimesterId;
  final DateTime createdAt;

  User({
    this.id,
    required this.email,
    required this.passwordHash,
    required this.name,
    this.profileImagePath,
    this.currentTrimesterId,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'email': email,
        'password_hash': passwordHash,
        'name': name,
        'profile_image_path': profileImagePath,
        'current_trimester_id': currentTrimesterId,
        'created_at': createdAt.toIso8601String(),
      };

  factory User.fromMap(Map<String, Object?> m) => User(
        id: m['id'] as int?,
        email: m['email'] as String,
        passwordHash: m['password_hash'] as String,
        name: m['name'] as String,
        profileImagePath: m['profile_image_path'] as String?,
        currentTrimesterId: m['current_trimester_id'] as int?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  User copyWith({
    int? id,
    String? email,
    String? passwordHash,
    String? name,
    String? profileImagePath,
    int? currentTrimesterId,
    DateTime? createdAt,
  }) =>
      User(
        id: id ?? this.id,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        name: name ?? this.name,
        profileImagePath: profileImagePath ?? this.profileImagePath,
        currentTrimesterId: currentTrimesterId ?? this.currentTrimesterId,
        createdAt: createdAt ?? this.createdAt,
      );
}

class Trimester {
  final int? id;
  final int userId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;

  Trimester({
    this.id,
    required this.userId,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
      };

  factory Trimester.fromMap(Map<String, Object?> m) => Trimester(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        name: m['name'] as String,
        startDate: DateTime.parse(m['start_date'] as String),
        endDate: DateTime.parse(m['end_date'] as String),
      );
}

class Subject {
  final int? id;
  final int trimesterId;
  final String name;
  final String colorHex;
  final DateTime createdAt;

  Subject({
    this.id,
    required this.trimesterId,
    required this.name,
    required this.colorHex,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, Object?> toMap() => {
        'id': id,
        'trimester_id': trimesterId,
        'name': name,
        'color_hex': colorHex,
        'created_at': createdAt.toIso8601String(),
      };

  factory Subject.fromMap(Map<String, Object?> m) => Subject(
        id: m['id'] as int?,
        trimesterId: m['trimester_id'] as int,
        name: m['name'] as String,
        colorHex: m['color_hex'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class Task {
  /// priority: 0 = común, 1 = prioritario
  final int? id;
  final int userId;
  final int subjectId;
  final String title;
  final String? description;
  final DateTime dueDate;
  final int priority;
  final bool isCompleted;
  final DateTime? completedAt;
  final DateTime createdAt;

  Task({
    this.id,
    required this.userId,
    required this.subjectId,
    required this.title,
    this.description,
    required this.dueDate,
    this.priority = 0,
    this.isCompleted = false,
    this.completedAt,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPriority => priority == 1;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'subject_id': subjectId,
        'title': title,
        'description': description,
        'due_date': dueDate.toIso8601String(),
        'priority': priority,
        'is_completed': isCompleted ? 1 : 0,
        'completed_at': completedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Task.fromMap(Map<String, Object?> m) => Task(
        id: m['id'] as int?,
        userId: m['user_id'] as int,
        subjectId: m['subject_id'] as int,
        title: m['title'] as String,
        description: m['description'] as String?,
        dueDate: DateTime.parse(m['due_date'] as String),
        priority: (m['priority'] as int?) ?? 0,
        isCompleted: ((m['is_completed'] as int?) ?? 0) == 1,
        completedAt: m['completed_at'] == null
            ? null
            : DateTime.parse(m['completed_at'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Task copyWith({
    int? id,
    int? userId,
    int? subjectId,
    String? title,
    String? description,
    DateTime? dueDate,
    int? priority,
    bool? isCompleted,
    DateTime? completedAt,
    DateTime? createdAt,
  }) =>
      Task(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        subjectId: subjectId ?? this.subjectId,
        title: title ?? this.title,
        description: description ?? this.description,
        dueDate: dueDate ?? this.dueDate,
        priority: priority ?? this.priority,
        isCompleted: isCompleted ?? this.isCompleted,
        completedAt: completedAt ?? this.completedAt,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Vista enriquecida tarea + materia para la UI.
class TaskWithSubject {
  final Task task;
  final Subject? subject;
  TaskWithSubject(this.task, this.subject);
}

/// Filtro de "próximos 3 días": pursamente local, testeable sin BD.
/// Incluye tareas no completadas con dueDate entre [now (inicio del día)]
/// y [now + 3 días (fin del día)], ordenadas por priority DESC, dueDate ASC.
List<Task> filterUpcoming3Days(List<Task> tasks, DateTime now) {
  final start = DateTime(now.year, now.month, now.day);
  final end = start.add(const Duration(days: 3, hours: 23, minutes: 59, seconds: 59));
  final out = tasks.where((t) {
    if (t.isCompleted) return false;
    return !t.dueDate.isBefore(start) && !t.dueDate.isAfter(end);
  }).toList();
  out.sort((a, b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return a.dueDate.compareTo(b.dueDate);
  });
  return out;
}

/// Resto de pendientes (no completadas y NO en próximos 3 días).
List<Task> filterPendingRest(List<Task> tasks, DateTime now) {
  final upcoming = filterUpcoming3Days(tasks, now).map((t) => t.id).toSet();
  final out = tasks
      .where((t) => !t.isCompleted && !upcoming.contains(t.id))
      .toList();
  out.sort((a, b) {
    final p = b.priority.compareTo(a.priority);
    if (p != 0) return p;
    return a.dueDate.compareTo(b.dueDate);
  });
  return out;
}
