import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tareas_uni/data/database/app_database.dart';
import 'package:tareas_uni/data/models/models.dart';
import 'package:tareas_uni/data/repositories/repositories.dart';

Future<void> main() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Auth: crear usuario + login (bcrypt)', () {
    test('hash y verify + unicidad de email', () async {
      final db = await AppDatabase.openInMemory();
      final users = UserRepository(db: Future.value(db));

      final hash = BCrypt.hashpw('secreto123', BCrypt.gensalt());
      final id = await users.create(User(
        email: 'alu@uni.edu',
        passwordHash: hash,
        name: 'Alu',
      ));
      expect(id, isNonZero);

      final fetched = await users.getByEmail('ALU@uni.edu');
      expect(fetched, isNotNull);
      expect(BCrypt.checkpw('secreto123', fetched!.passwordHash), isTrue);
      expect(BCrypt.checkpw('otra', fetched.passwordHash), isFalse);

      await db.close();
    });
  });

  group('CRUD cuatrimestre / materia / tarea', () {
    test('flujo completo + cascade', () async {
      final db = await AppDatabase.openInMemory();
      final users = UserRepository(db: Future.value(db));
      final trims = TrimesterRepository(db: Future.value(db));
      final subs = SubjectRepository(db: Future.value(db));
      final tasks = TaskRepository(db: Future.value(db));

      final uid = await users.create(User(
        email: 'a@a.com',
        passwordHash: BCrypt.hashpw('123456', BCrypt.gensalt()),
        name: 'A',
      ));

      // Cuatrimestre: crear, listar, actualizar, marcar actual
      final tid = await trims.create(Trimester(
        userId: uid,
        name: '2026-1',
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 4, 30),
      ));
      var list = await trims.listByUser(uid);
      expect(list.length, 1);
      await trims.update(Trimester(
          id: tid,
          userId: uid,
          name: '2026-1 edit',
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2026, 4, 30)));
      expect((await trims.getById(tid))!.name, '2026-1 edit');
      await users.setCurrentTrimester(uid, tid);
      expect((await users.getById(uid))!.currentTrimesterId, tid);

      // Materia: crear, listar, actualizar
      final sid = await subs.create(Subject(
          trimesterId: tid, name: 'Matemática', colorHex: '#FF0000'));
      expect((await subs.listByTrimester(tid)).length, 1);
      await subs.update(Subject(
          id: sid,
          trimesterId: tid,
          name: 'Matemática II',
          colorHex: '#00FF00',
          createdAt: DateTime.now()));
      expect((await subs.getById(sid))!.name, 'Matemática II');

      // Tarea: crear, leer, toggle, borrar
      final taskId = await tasks.create(Task(
        userId: uid,
        subjectId: sid,
        title: 'TP 1',
        dueDate: DateTime.now().add(const Duration(days: 1)),
        priority: 1,
      ));
      expect((await tasks.getById(taskId))!.title, 'TP 1');
      await tasks.toggleCompleted(taskId, true);
      expect((await tasks.getById(taskId))!.isCompleted, isTrue);
      await tasks.toggleCompleted(taskId, false);
      expect((await tasks.getById(taskId))!.isCompleted, isFalse);

      // Cascade: borrar cuatrimestre elimina materias y tareas
      await trims.delete(tid);
      expect(await subs.getById(sid), isNull);
      expect(await tasks.getById(taskId), isNull);

      await db.close();
    });
  });

  group('Filtro próximos 3 días', () {
    test('incluye hoy..hoy+3, excluye resto y completadas, ordena', () {
      final now = DateTime(2026, 3, 10, 12);
      Task mk(int? id, DateTime due, int prio, {bool done = false}) => Task(
          id: id,
          userId: 1,
          subjectId: 1,
          title: 't$id',
          dueDate: due,
          priority: prio,
          isCompleted: done);
      final tasks = [
        mk(1, DateTime(2026, 3, 10, 23), 0), // hoy común
        mk(2, DateTime(2026, 3, 11, 9), 1), // mañana prioritario
        mk(3, DateTime(2026, 3, 13, 23, 59), 0), // día +3 límite
        mk(4, DateTime(2026, 3, 14, 0, 1), 1), // fuera (+4)
        mk(5, DateTime(2026, 3, 9), 1), // ayer -> fuera
        mk(6, DateTime(2026, 3, 11), 1, done: true), // completada -> fuera
      ];
      final up = filterUpcoming3Days(tasks, now);
      expect(up.map((t) => t.id).toList(), [2, 1, 3]);

      final rest = filterPendingRest(tasks, now);
      expect(rest.map((t) => t.id).toList(), [5, 4]);
    });
  });
}
