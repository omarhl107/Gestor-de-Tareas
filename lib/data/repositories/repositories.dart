import 'package:sqflite/sqflite.dart';

import '../database/app_database.dart';
import '../models/models.dart';

class UserRepository {
  final Future<Database> _dbFuture;
  UserRepository({Future<Database>? db})
      : _dbFuture = db ?? AppDatabase.instance.database;

  Future<Database> get _db => _dbFuture;

  Future<int> create(User u) async {
    final db = await _db;
    return db.insert('users', u.toMap());
  }

  Future<User?> getById(int id) async {
    final db = await _db;
    final rows =
        await db.query('users', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<User?> getByEmail(String email) async {
    final db = await _db;
    final rows = await db.query('users',
        where: 'email = ?', whereArgs: [email.trim().toLowerCase()], limit: 1);
    if (rows.isEmpty) return null;
    return User.fromMap(rows.first);
  }

  Future<void> update(User u) async {
    final db = await _db;
    await db.update('users', u.toMap(), where: 'id = ?', whereArgs: [u.id]);
  }

  Future<void> setCurrentTrimester(int userId, int? trimesterId) async {
    final db = await _db;
    await db.update(
        'users', {'current_trimester_id': trimesterId},
        where: 'id = ?', whereArgs: [userId]);
  }
}

class TrimesterRepository {
  final Future<Database> _dbFuture;
  TrimesterRepository({Future<Database>? db})
      : _dbFuture = db ?? AppDatabase.instance.database;
  Future<Database> get _db => _dbFuture;

  Future<int> create(Trimester t) async {
    final db = await _db;
    return db.insert('trimesters', t.toMap());
  }

  Future<List<Trimester>> listByUser(int userId) async {
    final db = await _db;
    final rows = await db.query('trimesters',
        where: 'user_id = ?', whereArgs: [userId], orderBy: 'start_date DESC');
    return rows.map(Trimester.fromMap).toList();
  }

  Future<Trimester?> getById(int id) async {
    final db = await _db;
    final rows =
        await db.query('trimesters', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Trimester.fromMap(rows.first);
  }

  Future<void> update(Trimester t) async {
    final db = await _db;
    await db.update('trimesters', t.toMap(),
        where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('trimesters', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countSubjects(int trimesterId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM subjects WHERE trimester_id = ?',
        [trimesterId]);
    return (rows.first['c'] as int?) ?? 0;
  }
}

class SubjectRepository {
  final Future<Database> _dbFuture;
  SubjectRepository({Future<Database>? db})
      : _dbFuture = db ?? AppDatabase.instance.database;
  Future<Database> get _db => _dbFuture;

  Future<int> create(Subject s) async {
    final db = await _db;
    return db.insert('subjects', s.toMap());
  }

  Future<List<Subject>> listByTrimester(int trimesterId) async {
    final db = await _db;
    final rows = await db.query('subjects',
        where: 'trimester_id = ?',
        whereArgs: [trimesterId],
        orderBy: 'name ASC');
    return rows.map(Subject.fromMap).toList();
  }

  Future<List<Subject>> listByUserTrimesters(List<int> trimesterIds) async {
    if (trimesterIds.isEmpty) return [];
    final db = await _db;
    final ph = List.filled(trimesterIds.length, '?').join(',');
    final rows = await db.query('subjects',
        where: 'trimester_id IN ($ph)', whereArgs: trimesterIds);
    return rows.map(Subject.fromMap).toList();
  }

  Future<Subject?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('subjects', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Subject.fromMap(rows.first);
  }

  Future<void> update(Subject s) async {
    final db = await _db;
    await db.update('subjects', s.toMap(),
        where: 'id = ?', whereArgs: [s.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('subjects', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> countTasks(int subjectId) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM tasks WHERE subject_id = ?', [subjectId]);
    return (rows.first['c'] as int?) ?? 0;
  }
}

class TaskRepository {
  final Future<Database> _dbFuture;
  TaskRepository({Future<Database>? db})
      : _dbFuture = db ?? AppDatabase.instance.database;
  Future<Database> get _db => _dbFuture;

  Future<int> create(Task t) async {
    final db = await _db;
    return db.insert('tasks', t.toMap());
  }

  Future<Task?> getById(int id) async {
    final db = await _db;
    final rows = await db.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<void> update(Task t) async {
    final db = await _db;
    await db.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
  }

  Future<void> delete(int id) async {
    final db = await _db;
    await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> toggleCompleted(int id, bool completed) async {
    final db = await _db;
    await db.update(
      'tasks',
      {
        'is_completed': completed ? 1 : 0,
        'completed_at':
            completed ? DateTime.now().toIso8601String() : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Tareas no completadas del usuario ordenadas priority DESC, due ASC.
  Future<List<TaskWithSubject>> pendingWithSubject(int userId) async {
    final db = await _db;
    final rows = await db.rawQuery('''
SELECT t.*, s.name AS s_name, s.color_hex AS s_color, s.trimester_id AS s_trim
FROM tasks t LEFT JOIN subjects s ON s.id = t.subject_id
WHERE t.user_id = ? AND t.is_completed = 0
ORDER BY t.priority DESC, t.due_date ASC
''', [userId]);
    return rows.map((r) {
      final task = Task.fromMap(r);
      Subject? subj;
      if (r['s_name'] != null) {
        subj = Subject(
          id: task.subjectId,
          trimesterId: (r['s_trim'] as int?) ?? 0,
          name: r['s_name'] as String,
          colorHex: (r['s_color'] as String?) ?? '#3F51B5',
        );
      }
      return TaskWithSubject(task, subj);
    }).toList();
  }

  Future<List<TaskWithSubject>> completedWithSubject(
    int userId, {
    int? subjectId,
    int? trimesterId,
    DateTime? from,
    DateTime? to,
  }) async {
    final db = await _db;
    final where = <String>['t.user_id = ?', 't.is_completed = 1'];
    final args = <Object?>[userId];
    if (subjectId != null) {
      where.add('t.subject_id = ?');
      args.add(subjectId);
    }
    if (trimesterId != null) {
      where.add('s.trimester_id = ?');
      args.add(trimesterId);
    }
    if (from != null) {
      where.add('t.due_date >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      where.add('t.due_date <= ?');
      args.add(to.toIso8601String());
    }
    final rows = await db.rawQuery('''
SELECT t.*, s.name AS s_name, s.color_hex AS s_color, s.trimester_id AS s_trim
FROM tasks t LEFT JOIN subjects s ON s.id = t.subject_id
WHERE ${where.join(' AND ')}
ORDER BY t.completed_at DESC
''', args);
    return rows.map((r) {
      final task = Task.fromMap(r);
      Subject? subj;
      if (r['s_name'] != null) {
        subj = Subject(
          id: task.subjectId,
          trimesterId: (r['s_trim'] as int?) ?? 0,
          name: r['s_name'] as String,
          colorHex: (r['s_color'] as String?) ?? '#3F51B5',
        );
      }
      return TaskWithSubject(task, subj);
    }).toList();
  }
}
