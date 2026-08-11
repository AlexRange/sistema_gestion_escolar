import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/student_model.dart';
//import '../../../data/models/group_model.dart';
import '../../providers/students_provider.dart';
import '../../providers/groups_provider.dart';
import '../../../domain/services/excel_import_service.dart';
import '../../../core/utils/back_handler.dart';

class GroupDetailScreen extends ConsumerWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(studentsProvider(groupId));
    final groupsAsync = ref.watch(groupsProvider);

    final groupName = groupsAsync.maybeWhen(
      data: (groups) {
        final g = groups.where((g) => g.id == groupId);
        return g.isNotEmpty ? g.first.name : 'Grupo';
      },
      orElse: () => 'Grupo',
    );
    return BackHandler(
        backRoute: '/groups',
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text(groupName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/groups'),
            ),
            actions: [
              // Importar Excel
              IconButton(
                icon: const Icon(Icons.upload_file),
                tooltip: 'Importar desde Excel',
                onPressed: () => _importFromExcel(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.check_circle_outline),
                tooltip: 'Asistencia',
                onPressed: () => context.go('/attendance/$groupId'),
              ),
              IconButton(
                icon: const Icon(Icons.grade),
                tooltip: 'Calificaciones',
                onPressed: () => context.go('/grades/$groupId'),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar alumno'),
            onPressed: () => _showStudentDialog(context, ref, null),
          ),
          body: studentsAsync.when(
            data: (students) {
              if (students.isEmpty) return _emptyState(context, ref);
              return Column(
                children: [
                  // Banner resumen
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.secondary],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.people, color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${students.length} alumnos',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold)),
                            const Text('Lista del grupo',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Lista
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      itemCount: students.length,
                      itemBuilder: (context, i) =>
                          _studentTile(context, ref, students[i], i),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
        ));
  }

  Widget _studentTile(
      BuildContext context, WidgetRef ref, StudentModel student, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.12),
          child: Text(
            '${student.listNumber}',
            style: const TextStyle(
                color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(student.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: student.matricula != null
            ? Text('Matrícula: ${student.matricula}',
                style: const TextStyle(fontSize: 12, color: Colors.grey))
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: AppColors.secondary, size: 20),
              onPressed: () => _showStudentDialog(context, ref, student),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 20),
              onPressed: () => _confirmDelete(context, ref, student),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin alumnos en este grupo',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Agregar alumno'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _showStudentDialog(context, ref, null),
          ),
        ],
      ),
    );
  }

  void _showStudentDialog(
      BuildContext context, WidgetRef ref, StudentModel? existing) {
    final firstCtrl = TextEditingController(text: existing?.firstName ?? '');
    final lastCtrl = TextEditingController(text: existing?.lastName ?? '');
    final matCtrl = TextEditingController(text: existing?.matricula ?? '');
    final numCtrl =
        TextEditingController(text: existing?.listNumber.toString() ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(existing == null ? 'Nuevo alumno' : 'Editar alumno',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: numCtrl,
                  decoration:
                      _inputDeco('No. de lista', Icons.format_list_numbered),
                  keyboardType: TextInputType.number,
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: firstCtrl,
                  decoration: _inputDeco('Nombre(s)', Icons.person_outline),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: lastCtrl,
                  decoration: _inputDeco('Apellidos', Icons.person_outline),
                  validator: (v) =>
                      v == null || v.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: matCtrl,
                  decoration:
                      _inputDeco('Matrícula (opcional)', Icons.badge_outlined),
                ),
              ],
            ),
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
              final repo = ref.read(studentRepositoryProvider)!;
              if (existing == null) {
                await repo.addStudent(
                  groupId,
                  StudentModel(
                    id: '',
                    groupId: groupId,
                    firstName: firstCtrl.text.trim(),
                    lastName: lastCtrl.text.trim(),
                    matricula:
                        matCtrl.text.isEmpty ? null : matCtrl.text.trim(),
                    listNumber: int.tryParse(numCtrl.text.trim()) ?? 0,
                  ),
                );
              } else {
                await repo.updateStudent(
                  groupId,
                  StudentModel(
                    id: existing.id,
                    groupId: groupId,
                    firstName: firstCtrl.text.trim(),
                    lastName: lastCtrl.text.trim(),
                    matricula:
                        matCtrl.text.isEmpty ? null : matCtrl.text.trim(),
                    listNumber: int.tryParse(numCtrl.text.trim()) ?? 0,
                  ),
                );
              }
              if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: Text(existing == null ? 'Agregar' : 'Guardar'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, StudentModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar alumno'),
        content: Text(
            '¿Eliminar a "${student.fullName}"? Esta acción no se puede deshacer.'),
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
              await ref
                  .read(studentRepositoryProvider)!
                  .deleteStudent(groupId, student.id);
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

  Future<void> _importFromExcel(BuildContext context, WidgetRef ref) async {
    // Mostrar instrucciones antes de abrir el selector
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Importar alumnos desde Excel',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('El archivo Excel debe tener este formato:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            SizedBox(height: 12),
            Text(
                'Columna A → No. de lista\n'
                'Columna B → Apellidos\n'
                'Columna C → Nombre(s)\n'
                'Columna D → Matrícula (opcional)',
                style: TextStyle(
                    fontFamily: 'monospace', fontSize: 13, height: 1.8)),
            SizedBox(height: 12),
            Text(
              '⚠️ Si la primera fila es encabezado se omite automáticamente.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Seleccionar archivo'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final service = ExcelImportService();
      final imported = await service.pickAndParse();

      if (imported == null) return; // Canceló el picker
      if (imported.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se encontraron alumnos en el archivo'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Mostrar preview antes de confirmar
      if (context.mounted) {
        final save = await _showImportPreview(context, imported);
        if (save != true) return;
      }

      // Convertir a StudentModel y guardar
      final repo = ref.read(studentRepositoryProvider)!;
      final students = imported
          .map((d) => StudentModel(
                id: '',
                groupId: groupId,
                firstName: d.firstName,
                lastName: d.lastName,
                matricula: d.matricula,
                listNumber: d.listNumber,
              ))
          .toList();

      await repo.importStudents(groupId, students);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ ${students.length} alumnos importados correctamente'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al importar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<bool?> _showImportPreview(
      BuildContext context, List<StudentImportData> data) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Vista previa — ${data.length} alumnos',
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: data.length,
            itemBuilder: (context, i) {
              final s = data[i];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  radius: 14,
                  child: Text('${s.listNumber}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text('${s.firstName} ${s.lastName}',
                    style: const TextStyle(fontSize: 13)),
                subtitle: s.matricula != null
                    ? Text('Mat: ${s.matricula}',
                        style: const TextStyle(fontSize: 11))
                    : null,
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Importar ${data.length} alumnos'),
          ),
        ],
      ),
    );
  }
}
