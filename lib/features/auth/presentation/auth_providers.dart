import 'package:bcrypt/bcrypt.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/database/app_database.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';

// ---------- Infraestructura ----------

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final databaseProvider = FutureProvider<Database>((ref) async {
  return AppDatabase.instance.database;
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final trimesterRepositoryProvider = Provider<TrimesterRepository>((ref) {
  return TrimesterRepository();
});

final subjectRepositoryProvider = Provider<SubjectRepository>((ref) {
  return SubjectRepository();
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

// ---------- Sesión ----------

/// Persistencia de sesión con respaldo.
///
/// `flutter_secure_storage` puede no estar disponible en escritorio
/// (p. ej. Windows sin Developer Mode: los plugins no compilan sus
/// symlinks y lanzan MissingPluginException). Para que el login/registro
/// nunca se quede colgado, se intenta el almacenamiento seguro y, si
/// falla, se usa SharedPreferences como respaldo. Todo es best-effort:
/// ningún error de persistencia debe impedir entrar a la app.
class SessionStore {
  final FlutterSecureStorage secure;
  SessionStore(this.secure);

  Future<void> save(int userId, {required bool rememberMe}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefsKeyRememberMe, rememberMe);
      if (rememberMe) {
        // Respaldo en prefs por si el secure storage no funciona.
        await prefs.setInt(AppConstants.prefsKeySessionUserId, userId);
      } else {
        await prefs.remove(AppConstants.prefsKeySessionUserId);
      }
    } catch (_) {
      // best-effort: ignorar
    }
    try {
      if (rememberMe) {
        await secure.write(
            key: AppConstants.secureKeyUserId, value: '$userId');
      } else {
        await secure.delete(key: AppConstants.secureKeyUserId);
      }
    } catch (_) {
      // best-effort: el respaldo en prefs ya cubre este caso
    }
  }

  /// Devuelve el userId guardado o null. Nunca lanza.
  Future<int?> read({required bool rememberMe}) async {
    if (!rememberMe) return null;
    try {
      final idStr = await secure.read(key: AppConstants.secureKeyUserId);
      final id = int.tryParse(idStr ?? '');
      if (id != null) return id;
    } catch (_) {
      // caemos al respaldo en prefs
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(AppConstants.prefsKeySessionUserId);
    } catch (_) {
      return null;
    }
  }

  Future<bool> wantsRemember() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(AppConstants.prefsKeyRememberMe) ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(AppConstants.prefsKeyRememberMe, false);
      await prefs.remove(AppConstants.prefsKeySessionUserId);
    } catch (_) {}
    try {
      await secure.delete(key: AppConstants.secureKeyUserId);
    } catch (_) {}
  }
}

final sessionStoreProvider = Provider<SessionStore>((ref) {
  return SessionStore(ref.read(secureStorageProvider));
});

/// Estado de sesión: usuario logueado o null.
class SessionController extends StateNotifier<AsyncValue<User?>> {
  final Ref ref;
  SessionController(this.ref) : super(const AsyncValue.loading()) {
    restore();
  }

  Future<void> restore() async {
    state = const AsyncValue.loading();
    try {
      final store = ref.read(sessionStoreProvider);
      final remember = await store.wantsRemember();
      // Si no quiso recordar sesión, no restauramos nada persistido.
      if (!remember) {
        // Limpieza defensiva por si quedó algo viejo.
        await store.clear();
        state = const AsyncValue.data(null);
        return;
      }
      final id = await store.read(rememberMe: true);
      if (id == null) {
        state = const AsyncValue.data(null);
        return;
      }
      final user = await ref.read(userRepositoryProvider).getById(id);
      // Validar que el usuario aún exista en BD.
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<String?> login(String email, String password,
      {required bool rememberMe}) async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.getByEmail(email);
      if (user == null) return 'No existe una cuenta con ese email.';
      bool ok;
      try {
        ok = BCrypt.checkpw(password, user.passwordHash);
      } catch (e) {
        return 'No se pudo verificar la contraseña ($e).';
      }
      if (!ok) return 'Contraseña incorrecta.';
      await ref
          .read(sessionStoreProvider)
          .save(user.id!, rememberMe: rememberMe);
      state = AsyncValue.data(user);
      return null;
    } catch (e) {
      return 'No se pudo iniciar sesión: $e';
    }
  }

  /// Registra y crea cuatrimestre por defecto "Cuatrimestre actual" (seed).
  /// Nunca lanza: devuelve el mensaje de error si algo falla.
  Future<String?> register(
      String name, String email, String password) async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final existing = await repo.getByEmail(email);
      if (existing != null) return 'Ese email ya está registrado.';
      final hash = BCrypt.hashpw(password, BCrypt.gensalt());
      final now = DateTime.now();
      final id = await repo.create(User(
        email: email.trim().toLowerCase(),
        passwordHash: hash,
        name: name.trim(),
        createdAt: now,
      ));
      // Seed: cuatrimestre por defecto.
      final trimRepo = ref.read(trimesterRepositoryProvider);
      final trimId = await trimRepo.create(Trimester(
        userId: id,
        name: 'Cuatrimestre actual',
        startDate: DateTime(now.year, now.month, 1),
        endDate: DateTime(now.year, now.month + 4, 1)
            .subtract(const Duration(days: 1)),
      ));
      await repo.setCurrentTrimester(id, trimId);
      final user = await repo.getById(id);
      await ref.read(sessionStoreProvider).save(id, rememberMe: true);
      state = AsyncValue.data(user);
      return null;
    } catch (e) {
      return 'No se pudo crear la cuenta: $e';
    }
  }

  Future<void> logout() async {
    try {
      await ref.read(sessionStoreProvider).clear();
    } catch (_) {}
    state = const AsyncValue.data(null);
  }

  /// Refresca el usuario desde BD (tras editar perfil o trimestre actual).
  Future<void> refreshUser() async {
    final current = state.valueOrNull;
    if (current?.id == null) return;
    final fresh = await ref.read(userRepositoryProvider).getById(current!.id!);
    state = AsyncValue.data(fresh);
  }
}

final sessionProvider =
    StateNotifierProvider<SessionController, AsyncValue<User?>>((ref) {
  return SessionController(ref);
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(sessionProvider).valueOrNull;
});
