import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/workshop_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/student_model.dart';
import '../../../domain/services/excel_export_service.dart';
import '../../providers/workshop_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/students_provider.dart';
import '../../../core/utils/back_handler.dart';

class WorkshopScreen extends ConsumerStatefulWidget {
  const WorkshopScreen({super.key});

  @override
  ConsumerState<WorkshopScreen> createState() => _WorkshopScreenState();
}

class _WorkshopScreenState extends ConsumerState<WorkshopScreen> {
  @override
  Widget build(BuildContext context) {
    final workshopsAsync = ref.watch(workshopsProvider);

    return BackHandler(
    backRoute: '/dashboard',
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text('Taller Sabatino',
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
        label: const Text('Nuevo taller'),
        onPressed: () => _addWorkshopDialog(context),
      ),
      body: workshopsAsync.when(
        data: (workshops) {
          if (workshops.isEmpty) return _emptyState();
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            itemCount: workshops.length,
            itemBuilder: (context, i) => _workshopCard(context, workshops[i]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    )
    );
  }

  Widget _workshopCard(BuildContext context, WorkshopModel w) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.accent.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note,
                  color: AppColors.accent, size: 28),
            ),
            title: Text(w.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.teacherName, style: const TextStyle(color: Colors.grey)),
                Text(
                  '${w.partialName} • ${w.students.length} alumnos',
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.secondary),
                ),
              ],
            ),
          ),
          // Botones de acción
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Row(
              children: [
                _actionBtn(
                  icon: Icons.person_add,
                  label: 'Alumnos',
                  color: AppColors.secondary,
                  onTap: () => _manageStudentsDialog(context, w),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.how_to_reg,
                  label: 'Asistencia',
                  color: AppColors.accent,
                  onTap: () => w.students.isEmpty
                      ? ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Agrega alumnos al taller primero')))
                      : _takeAttendanceDialog(context, w),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.download,
                  label: 'Exportar',
                  color: AppColors.primary,
                  onTap: () => _exportWorkshop(w),
                ),
                const SizedBox(width: 8),
                _actionBtn(
                  icon: Icons.delete_outline,
                  label: 'Eliminar',
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, w),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Gestionar alumnos del taller ─────────────────────────────────
  void _manageStudentsDialog(
      BuildContext context, WorkshopModel workshop) async {
    final groupsAsync = ref.read(groupsProvider);
    final groups = groupsAsync.maybeWhen(data: (g) => g, orElse: () => []);

    if (groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No tienes grupos creados')),
      );
      return;
    }

    // Cargar todos los alumnos de todos los grupos de forma asíncrona
    final Map<String, List<StudentModel>> groupStudentsMap = {};
    for (final group in groups) {
      try {
        final students = await ref
            .read(studentRepositoryProvider)!
            .watchStudents(group.id)
            .first;
        if (students.isNotEmpty) {
          groupStudentsMap[group.id] = students;
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final Set<String> selected = {
      for (final s in workshop.students) s.studentId
    };
    final Map<String, StudentModel> allStudents = {};
    final Map<String, String> studentGroup = {};

    for (final entry in groupStudentsMap.entries) {
      for (final s in entry.value) {
        allStudents[s.id] = s;
        studentGroup[s.id] = entry.key;
      }
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gestionar alumnos del taller',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text(
                '${selected.length} seleccionados',
                style:
                    const TextStyle(fontSize: 13, color: AppColors.secondary),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: groupStudentsMap.isEmpty
                ? const Center(
                    child: Text(
                      'No hay alumnos en tus grupos.\nAgrégalos primero en la sección Grupos.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: groups.length,
                    itemBuilder: (context, gi) {
                      final group = groups[gi];
                      final groupStudents = groupStudentsMap[group.id] ?? [];
                      if (groupStudents.isEmpty) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado del grupo
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${group.name} — ${group.subject}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                        fontSize: 13),
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(60, 30)),
                                  onPressed: () {
                                    setS(() {
                                      final allIds = groupStudents
                                          .map((s) => s.id)
                                          .toSet();
                                      final allSel = allIds
                                          .every((id) => selected.contains(id));
                                      if (allSel) {
                                        selected.removeAll(allIds);
                                      } else {
                                        selected.addAll(allIds);
                                      }
                                    });
                                  },
                                  child: Text(
                                    groupStudents.every(
                                            (s) => selected.contains(s.id))
                                        ? 'Quitar todos'
                                        : 'Todos',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Alumnos
                          ...groupStudents.map((student) {
                            final isSelected = selected.contains(student.id);
                            return CheckboxListTile(
                              dense: true,
                              value: isSelected,
                              activeColor: AppColors.accent,
                              title: Text(
                                '${student.listNumber}. ${student.fullName}',
                                style: const TextStyle(fontSize: 13),
                              ),
                              subtitle: student.matricula != null
                                  ? Text(student.matricula!,
                                      style: const TextStyle(fontSize: 11))
                                  : null,
                              onChanged: (v) => setS(() {
                                if (v == true) {
                                  selected.add(student.id);
                                } else {
                                  selected.remove(student.id);
                                }
                              }),
                            );
                          }),
                        ],
                      );
                    },
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
                final refs = selected.map((sid) {
                  final student = allStudents[sid];
                  return WorkshopStudentRef(
                    studentId: sid,
                    groupId: studentGroup[sid] ?? '',
                    studentName: student?.fullName ?? '',
                    listNumber: student?.listNumber ?? 0,
                  );
                }).toList()
                  ..sort((a, b) => a.listNumber.compareTo(b.listNumber));

                await ref
                    .read(workshopRepositoryProvider)!
                    .updateWorkshop(workshop.copyWith(students: refs));
                if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tomar asistencia ─────────────────────────────────────────────
  void _takeAttendanceDialog(BuildContext context, WorkshopModel workshop) {
    DateTime selectedDate = DateTime.now();
    final Map<String, AttendanceStatus> localStatus = {
      for (final s in workshop.students) s.studentId: AttendanceStatus.present,
    };

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(workshop.name,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Selector de fecha
                InkWell(
                  onTap: () async {
                    final p = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                      locale: const Locale('es', 'MX'),
                    );
                    if (p != null) setS(() => selectedDate = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: AppColors.primary, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('EEEE d MMM yyyy', 'es_MX')
                              .format(selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Lista de alumnos del taller
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: workshop.students.length,
                    itemBuilder: (context, i) {
                      final s = workshop.students[i];
                      final status =
                          localStatus[s.studentId] ?? AttendanceStatus.present;
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
                        title: Text(s.studentName,
                            style: const TextStyle(fontSize: 13)),
                        trailing: GestureDetector(
                          onTap: () => setS(
                              () => localStatus[s.studentId] = status.next),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(status.label,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                        ),
                      );
                    },
                  ),
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
                final list = workshop.students
                    .map((s) => AttendanceModel(
                          id: '',
                          groupId: s.groupId,
                          studentId: s.studentId,
                          date: selectedDate,
                          status: localStatus[s.studentId] ??
                              AttendanceStatus.present,
                        ))
                    .toList();
                await ref
                    .read(workshopRepositoryProvider)!
                    .saveSessionBatch(workshop.id, list);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Asistencia guardada'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Guardar asistencia'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Exportar ─────────────────────────────────────────────────────
  Future<void> _exportWorkshop(WorkshopModel workshop) async {
    if (workshop.students.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay alumnos en este taller')),
        );
      }
      return;
    }

    final sessions =
        await ref.read(workshopRepositoryProvider)!.getSessionsAll(workshop.id);

    if (sessions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay sesiones registradas aún')),
        );
      }
      return;
    }

    // Convertir WorkshopStudentRef a StudentModel para el servicio
    final students = workshop.students
        .map((s) => StudentModel(
              id: s.studentId,
              groupId: s.groupId,
              firstName: s.studentName.split(' ').first,
              lastName: s.studentName.contains(' ')
                  ? s.studentName.substring(s.studentName.indexOf(' ') + 1)
                  : '',
              listNumber: s.listNumber,
            ))
        .toList();

    await ExcelExportService().exportAttendance(
      groupName: '${workshop.name} — ${workshop.teacherName}',
      students: students,
      attendance: sessions,
    );
  }

  void _confirmDelete(BuildContext context, WorkshopModel workshop) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar taller'),
        content: Text('¿Eliminar "${workshop.name}"? No se puede deshacer.'),
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
                  .read(workshopRepositoryProvider)!
                  .deleteWorkshop(workshop.id);
              if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin talleres registrados',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Crea un taller para registrar asistencias',
              style: TextStyle(color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _addWorkshopDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final partialCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Nuevo taller',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del taller',
                  prefixIcon: Icon(Icons.music_note, color: AppColors.primary),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: teacherCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del profesor',
                  prefixIcon:
                      Icon(Icons.person_outline, color: AppColors.primary),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: partialCtrl,
                decoration: const InputDecoration(
                  labelText: 'Parcial (ej. Unidad 1)',
                  prefixIcon:
                      Icon(Icons.school_outlined, color: AppColors.primary),
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
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
              await ref
                  .read(workshopRepositoryProvider)!
                  .addWorkshop(WorkshopModel(
                    id: '',
                    name: nameCtrl.text.trim(),
                    teacherName: teacherCtrl.text.trim(),
                    partialName: partialCtrl.text.trim(),
                    createdAt: DateTime.now(),
                  ));
              if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return AppColors.present;
      case AttendanceStatus.absent:
        return AppColors.absent;
      case AttendanceStatus.late:
        return AppColors.late;
      case AttendanceStatus.justified:
        return AppColors.justified;
    }
  }
}
