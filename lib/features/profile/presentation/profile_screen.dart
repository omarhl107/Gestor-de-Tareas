import 'dart:io';

import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/utils/formatters.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../trimesters/presentation/trimesters_screen.dart';
import '../../home/presentation/widgets.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  bool _init = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final user = ref.read(currentUserProvider);
    if (user?.id == null) return;
    final src = await showDialog<ImageSource>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Foto de perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galería'),
              onTap: () => Navigator.of(c).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Cámara'),
              onTap: () => Navigator.of(c).pop(ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    try {
      final picked =
          await ImagePicker().pickImage(source: src, maxWidth: 1024);
      if (picked == null) return;
      final dir = await getApplicationDocumentsDirectory();
      final dest =
          p.join(dir.path, 'profile_${user!.id}${p.extension(picked.path)}');
      await File(picked.path).copy(dest);
      final repo = ref.read(userRepositoryProvider);
      final fresh = await repo.getById(user.id!);
      if (fresh == null) return;
      await repo.update(fresh.copyWith(profileImagePath: dest));
      await ref.read(sessionProvider.notifier).refreshUser();
      if (mounted) showMsg(context, 'Foto actualizada');
    } catch (e) {
      if (mounted) showMsg(context, 'No se pudo guardar la foto: $e');
    }
  }

  Future<void> _saveProfile() async {
    final user = ref.read(currentUserProvider);
    if (user?.id == null) return;
    if (_name.text.trim().isEmpty) {
      showMsg(context, 'El nombre no puede estar vacío');
      return;
    }
    final repo = ref.read(userRepositoryProvider);
    final other = await repo.getByEmail(_email.text.trim());
    if (!mounted) return;
    if (other != null && other.id != user!.id) {
      showMsg(context, 'Ese email ya está en uso');
      return;
    }
    final fresh = await repo.getById(user!.id!);
    if (fresh == null || !mounted) return;
    await repo.update(fresh.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim().toLowerCase(),
    ));
    await ref.read(sessionProvider.notifier).refreshUser();
    if (mounted) showMsg(context, 'Perfil actualizado');
  }

  Future<void> _changePassword() async {
    final cur = TextEditingController();
    final neu = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: cur,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Actual')),
            TextField(
                controller: neu,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'Nueva (mín. 6)')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Cambiar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final user = ref.read(currentUserProvider)!;
    final repo = ref.read(userRepositoryProvider);
    final fresh = await repo.getById(user.id!);
    if (fresh == null || !mounted) return;
    if (!BCrypt.checkpw(cur.text, fresh.passwordHash)) {
      showMsg(context, 'La contraseña actual no es correcta');
      return;
    }
    if (neu.text.length < 6) {
      showMsg(context, 'La nueva debe tener mínimo 6 caracteres');
      return;
    }
    await repo.update(fresh.copyWith(
        passwordHash: BCrypt.hashpw(neu.text, BCrypt.gensalt())));
    if (!mounted) return;
    showMsg(context, 'Contraseña actualizada');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final trims = ref.watch(trimestersProvider);
    if (user != null && !_init) {
      _name.text = user.name;
      _email.text = user.email;
      _init = true;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      drawer: const AppDrawer(current: '/profile'),
      body: user == null
          ? const Center(child: Text('Sin sesión'))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 52,
                          backgroundImage: user.profileImagePath != null
                              ? FileImage(
                                  File(user.profileImagePath!))
                              : null,
                          child: user.profileImagePath == null
                              ? Text(
                                  user.name.isNotEmpty
                                      ? user.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 40),
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: IconButton.filled(
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.camera_alt, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Nombre')),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration:
                          const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  FilledButton(
                      onPressed: _saveProfile,
                      child: const Text('Guardar cambios')),
                  const SizedBox(height: 8),
                  OutlinedButton(
                      onPressed: _changePassword,
                      child: const Text('Cambiar contraseña')),
                  const SizedBox(height: 20),
                  const Text('Cuatrimestre actual',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  trims.when(
                    loading: () => const CircularProgressIndicator(),
                    error: (e, _) => Text('Error: $e'),
                    data: (items) {
                      if (items.isEmpty) {
                        return const Text(
                            'Aún no tienes cuatrimestres.');
                      }
                      return DropdownButtonFormField<int>(
                        initialValue: items
                                .any((t) => t.id == user.currentTrimesterId)
                            ? user.currentTrimesterId
                            : null,
                        decoration: const InputDecoration(
                            labelText: 'Cuatrimestre actual'),
                        items: items
                            .map((t) => DropdownMenuItem(
                                value: t.id, child: Text(t.name)))
                            .toList(),
                        onChanged: (v) async {
                          await ref
                              .read(userRepositoryProvider)
                              .setCurrentTrimester(user.id!, v);
                          await ref
                              .read(sessionProvider.notifier)
                              .refreshUser();
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}
