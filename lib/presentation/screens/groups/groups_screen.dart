import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../providers/groups_provider.dart';
import '../../../core/utils/back_handler.dart';

class GroupsScreen extends ConsumerWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(groupsProvider); // ← AGREGAR ESTA LÍNEA
    return BackHandler(
        backRoute: '/dashboard',
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: const Text('Mis Grupos',
                style: TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/dashboard'),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo grupo'),
            onPressed: () => _showGroupDialog(context, ref, null),
          ),
          body: groupsAsync.when(
            data: (groups) {
              if (groups.isEmpty) return _emptyState(context, ref);
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: groups.length,
                itemBuilder: (context, i) =>
                    _groupCard(context, ref, groups[i]),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ));
  }

  Widget _groupCard(BuildContext context, WidgetRef ref, GroupModel group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.primary,
          radius: 26,
          child: Text(
            group.name.isNotEmpty ? group.name[0].toUpperCase() : 'G',
            style: const TextStyle(
                color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(group.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(group.subject,
                style: const TextStyle(color: AppColors.secondary)),
            Text(group.schoolYear,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.secondary),
              onPressed: () => _showGroupDialog(context, ref, group),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.error),
              onPressed: () => _confirmDelete(context, ref, group),
            ),
          ],
        ),
        onTap: () => context.go('/groups/${group.id}'),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Aún no tienes grupos',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Toca el botón para crear tu primer grupo',
              style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crear grupo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showGroupDialog(context, ref, null),
          ),
        ],
      ),
    );
  }

  void _showGroupDialog(
      BuildContext context, WidgetRef ref, GroupModel? existing) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final subjectCtrl = TextEditingController(text: existing?.subject ?? '');
    final yearCtrl =
        TextEditingController(text: existing?.schoolYear ?? '2024-2025');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Nuevo grupo' : 'Editar grupo',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration:
                    _inputDeco('Nombre del grupo', Icons.group_outlined),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: subjectCtrl,
                decoration: _inputDeco('Materia', Icons.book_outlined),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: yearCtrl,
                decoration:
                    _inputDeco('Ciclo escolar', Icons.calendar_today_outlined),
                validator: (v) =>
                    v == null || v.isEmpty ? 'Campo requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final repo = ref.read(groupRepositoryProvider)!;
              if (existing == null) {
                await repo.addGroup(GroupModel(
                  id: '',
                  name: nameCtrl.text.trim(),
                  subject: subjectCtrl.text.trim(),
                  schoolYear: yearCtrl.text.trim(),
                  createdAt: DateTime.now(),
                ));
              } else {
                await repo.updateGroup(existing.copyWith(
                  name: nameCtrl.text.trim(),
                  subject: subjectCtrl.text.trim(),
                  schoolYear: yearCtrl.text.trim(),
                ));
              }
              if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: Text(existing == null ? 'Crear' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, GroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar grupo'),
        content: Text(
            '¿Eliminar "${group.name}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(groupRepositoryProvider)!.deleteGroup(group.id);
              if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
    );
  }
}
