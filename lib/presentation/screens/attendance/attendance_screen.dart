import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/student_model.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/students_provider.dart';
import '../../providers/groups_provider.dart';
import '../../../core/utils/back_handler.dart';

class AttendanceScreen extends ConsumerStatefulWidget {
  final String groupId;
  const AttendanceScreen({super.key, required this.groupId});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  DateTime _selectedDate = DateTime.now();
  // Mapa local: studentId → status (para edición rápida sin esperar Firestore)
  final Map<String, AttendanceStatus> _localStatus = {};
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider(widget.groupId));
    final attendanceAsync = ref.watch(attendanceByDateProvider(
        (groupId: widget.groupId, date: _selectedDate)));
    final groupsAsync = ref.watch(groupsProvider);

    final groupName = groupsAsync.maybeWhen(
      data: (groups) {
        final g = groups.where((g) => g.id == widget.groupId);
        return g.isNotEmpty ? g.first.name : 'Grupo';
      },
      orElse: () => 'Grupo',
    );

    // Inicializar mapa local cuando llegan datos de Firestore
    if (!_initialized) {
      attendanceAsync.whenData((list) {
        if (list.isNotEmpty && _localStatus.isEmpty) {
          for (final a in list) {
            _localStatus[a.studentId] = a.status;
          }
          _initialized = true;
        }
      });
    }
    return BackHandler(
    backRoute: '/groups/${widget.groupId}',
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('Asistencia — $groupName',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/groups/${widget.groupId}'),
        ),
      ),
      body: studentsAsync.when(
        data: (students) {
          if (students.isEmpty) {
            return const Center(
              child: Text('No hay alumnos en este grupo.\nAgrégalos primero.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          // Inicializar todos como "presente" si no hay registro previo
          for (final s in students) {
            _localStatus.putIfAbsent(s.id, () => AttendanceStatus.present);
          }

          final present = _localStatus.values
              .where((s) => s == AttendanceStatus.present)
              .length;
          final total = students.length;

          return Column(
            children: [
              // Selector de fecha + resumen
              _dateAndSummary(context, present, total),
              // Leyenda
              _legend(),
              // Lista de alumnos
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  itemCount: students.length,
                  itemBuilder: (context, i) =>
                      _studentRow(students[i]),
                ),
              ),
              // Botón guardar
              _saveButton(students),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    )
    );
  }

  Widget _dateAndSummary(BuildContext context, int present, int total) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Selector de fecha
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.white),
                onPressed: () => _changeDate(-1),
              ),
              GestureDetector(
                onTap: () => _pickDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('EEEE d MMM yyyy', 'es_MX')
                            .format(_selectedDate),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white),
                onPressed: () => _changeDate(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Resumen
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _summaryChip('Presentes', present, AppColors.present),
              _summaryChip(
                  'Faltas', total - present, AppColors.absent),
              _summaryChip(
                  'Total', total, Colors.white.withOpacity(0.7)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Column(
      children: [
        Text('$count',
            style: TextStyle(
                color: color,
                fontSize: 24,
                fontWeight: FontWeight.bold)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  Widget _legend() {
    final items = [
      ('P', 'Presente', AppColors.present),
      ('F', 'Falta', AppColors.absent),
      ('R', 'Retardo', AppColors.late),
      ('J', 'Justificado', AppColors.justified),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: items.map((item) {
          return Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.$3,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(item.$1,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 4),
              Text(item.$2,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _studentRow(StudentModel student) {
    final status =
        _localStatus[student.id] ?? AttendanceStatus.present;
    final color = _statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.1),
          child: Text('${student.listNumber}',
              style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13)),
        ),
        title: Text(student.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: _statusButton(student.id, status),
      ),
    );
  }

  Widget _statusButton(String studentId, AttendanceStatus status) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _localStatus[studentId] = status.next;
        });
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _statusColor(status),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          status.label,
          style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16),
        ),
      ),
    );
  }

  Widget _saveButton(List<StudentModel> students) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      color: Colors.white,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.save),
        label: const Text('Guardar asistencia',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: () => _saveAttendance(students),
      ),
    );
  }

  Future<void> _saveAttendance(List<StudentModel> students) async {
    final repo = ref.read(attendanceRepositoryProvider)!;
    final list = students.map((s) {
      return AttendanceModel(
        id: '',
        groupId: widget.groupId,
        studentId: s.id,
        date: _selectedDate,
        status: _localStatus[s.id] ?? AttendanceStatus.present,
      );
    }).toList();

    try {
      await repo.saveAttendanceBatch(widget.groupId, list);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Asistencia guardada correctamente'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _changeDate(int days) {
    setState(() {
      _selectedDate =
          _selectedDate.add(Duration(days: days));
      _localStatus.clear();
      _initialized = false;
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'MX'),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _localStatus.clear();
        _initialized = false;
      });
    }
  }

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:   return AppColors.present;
      case AttendanceStatus.absent:    return AppColors.absent;
      case AttendanceStatus.late:      return AppColors.late;
      case AttendanceStatus.justified: return AppColors.justified;
    }
  }
}
