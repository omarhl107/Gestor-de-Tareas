# Tareas Uni — Gestión de tareas universitarias (100% offline)

App móvil en Flutter para gestionar tareas por materia y cuatrimestre, con
almacenamiento 100% local (SQLite), sin backend ni APIs externas.

## Stack

- Flutter 3.35 / Dart 3.9
- State management: **flutter_riverpod**
- BD local: **sqflite** (+ **sqflite_common_ffi** en Windows/Linux/macOS) con DAOs en `lib/data/repositories/`
  > Decisión: el enunciado pedía "Drift o sqflite + DAOs". Se eligió **sqflite**
  > para priorizar que la app compile y corra sin el paso de codegen
  > (`build_runner`). El esquema y los CASCADE son los mismos pedidos.
- Auth local: hash con **bcrypt**, sesión en **flutter_secure_storage**,
  flag "recordar sesión" en **shared_preferences**
- Routing: **go_router** — imagen: **image_picker** + copia a directorio de la app
  (**path_provider**) — fechas: **intl** (`es`, `dd/MM/yyyy`) — color:
  **flutter_colorpicker**

## Estructura

```
lib/
  main.dart
  core/theme/ router/ constants/ utils/
  data/database/ (app_database.dart, schema v1 + PRAGMA foreign_keys=ON)
  data/models/ (User, Trimester, Subject, Task + filtros purs)
  data/repositories/ (User/Trimester/Subject/Task repositories)
  features/
    auth/presentation/ (splash, login, register, auth_providers/session)
    home/presentation/ (home_screen + widgets TaskCard/Drawer/EmptyState)
    tasks/presentation/ (task_form: bottom sheet nueva/editar)
    trimesters/ subjects/ history/ profile/
test/app_test.dart (auth, CRUD + cascade, filtro 3 días)
```

## Modelo (SQLite, `PRAGMA foreign_keys = ON`)

- **users**(id, email UNIQUE, password_hash, name, profile_image_path?,
  current_trimester_id? → trimesters, created_at)
- **trimesters**(id, user_id → users CASCADE, name, start_date, end_date)
- **subjects**(id, trimester_id → trimesters CASCADE, name, color_hex, created_at)
- **tasks**(id, user_id → users CASCADE, subject_id → subjects CASCADE,
  title, description?, due_date, priority 0/1, is_completed 0/1,
  completed_at?, created_at)

## Cómo correr

```bash
flutter pub get
flutter run            # Android / Windows / iOS
```

Tests:

```bash
flutter test
```

## Notas de comportamiento

- Al registrarse se crea el seed **"Cuatrimestre actual"** y se marca como actual.
- Home: sección "Próximos 3 días" (hoy → hoy+3, no completadas,
  `priority DESC, due ASC`) + "Pendientes" (resto). Pull-to-refresh re-consulta.
- Nueva tarea exige materia del **cuatrimestre actual**; si no hay trimestre
  actual, se avisa antes de abrir el formulario.
- Cerrar sesión pide confirmación. Eliminar cuatrimestre/materia con
  asociados advierte del borrado en cascada.
- Historial: completadas con filtros por materia, cuatrimestre y rango de
  fechas; indica a tiempo / fuera de plazo y permite desmarcar.
- Perfil: editar nombre/email (valida unicidad), cambiar contraseña
  (pide actual), foto (galería/cámara → se copia al directorio de la app),
  selector de cuatrimestre actual.
- Tema Material 3 claro/oscuro según sistema. Textos en español.
