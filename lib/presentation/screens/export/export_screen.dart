import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../data/models/student_model.dart';
import '../../providers/groups_provider.dart';
import '../../providers/students_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../../domain/services/excel_export_service.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/evaluation_model.dart';
import '../../../domain/services/grade_calculator.dart';
import '../../providers/partials_provider.dart';
import '../../../core/utils/back_handler.dart';
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  GroupModel? _selectedGroup;
  bool _exportAllGroups = false;
  String _exportType = 'attendance';
  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  bool _isLoading = false;
  final _dateFmt = DateFormat('d MMM yyyy', 'es_MX');

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupsProvider);

    return BackHandler(
      backRoute: '/dashboard',
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          title: const Text('Exportar a Excel',
              style: TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/dashboard'),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 20),

              // ── Sección 1: Selección de grupo ──────────────────────
              _sectionTitle('1. Selecciona el grupo'),
              const SizedBox(height: 10),

              // Toggle: Un grupo vs Todos
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _exportAllGroups = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_exportAllGroups
                              ? AppColors.primary
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !_exportAllGroups
                                ? AppColors.primary
                                : Colors.grey[300]!,
                          ),
                          boxShadow: !_exportAllGroups
                              ? [
                                  BoxShadow(
                                      color: AppColors.primary.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.group,
                                color: !_exportAllGroups
                                    ? Colors.white
                                    : Colors.grey[500],
                                size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Un grupo',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: !_exportAllGroups
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _exportAllGroups = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _exportAllGroups
                              ? AppColors.accent
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _exportAllGroups
                                ? AppColors.accent
                                : Colors.grey[300]!,
                          ),
                          boxShadow: _exportAllGroups
                              ? [
                                  BoxShadow(
                                      color: AppColors.accent.withOpacity(0.2),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2))
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_books,
                                color: _exportAllGroups
                                    ? Colors.white
                                    : Colors.grey[500],
                                size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Todos los grupos',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _exportAllGroups
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Selector individual o info de "todos"
              if (!_exportAllGroups)
                groupsAsync.when(
                  data: (groups) => _groupSelector(groups),
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                )
              else
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.accent.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: AppColors.accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: groupsAsync.when(
                          data: (groups) => Text(
                            'Se exportarán ${groups.length} grupos — '
                            'una hoja por grupo en el mismo archivo Excel.',
                            style: const TextStyle(fontSize: 13, height: 1.4),
                          ),
                          loading: () => const Text('Cargando grupos...'),
                          error: (e, _) => Text('Error: $e'),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),

              // ── Sección 2: Tipo de exportación ─────────────────────
              _sectionTitle('2. Tipo de exportación'),
              const SizedBox(height: 8),
              _typeSelector(),
              const SizedBox(height: 20),

              // ── Sección 3: Rango de fechas ──────────────────────────
              if (_exportType != 'grades') ...[
                _sectionTitle('3. Rango de fechas'),
                const SizedBox(height: 8),
                _dateRangeSelector(context),
                const SizedBox(height: 20),
              ],

              // ── Botón exportar ──────────────────────────────────────
              _exportButton(),
              const SizedBox(height: 32),

              // ── Info ────────────────────────────────────────────────
              _infoCard(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets de UI ───────────────────────────────────────────────────

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.file_download, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Exportar datos',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text('Genera archivos Excel con asistencia y calificaciones',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: AppColors.primary));
  }

  Widget _groupSelector(List<GroupModel> groups) {
    if (groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Text('No tienes grupos creados',
            style: TextStyle(color: Colors.grey)),
      );
    }

    // Limpiar selección si el grupo ya no existe
    if (_selectedGroup != null &&
        !groups.any((g) => g.id == _selectedGroup!.id)) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => setState(() => _selectedGroup = null));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GroupModel>(
          isExpanded: true,
          hint: const Text('Selecciona un grupo'),
          value: _selectedGroup,
          items: groups.map((g) {
            return DropdownMenuItem(
              value: g,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    radius: 16,
                    child: Text(
                      g.name.isNotEmpty ? g.name[0] : 'G',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(g.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(g.subject,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (g) => setState(() => _selectedGroup = g),
        ),
      ),
    );
  }

  Widget _typeSelector() {
    final options = [
      (
        value: 'attendance',
        label: 'Asistencia',
        icon: Icons.check_circle_outline
      ),
      (value: 'grades', label: 'Calificaciones', icon: Icons.grade_outlined),
      (value: 'both', label: 'Ambos', icon: Icons.description_outlined),
    ];

    return Row(
      children: options.map((opt) {
        final selected = _exportType == opt.value;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _exportType = opt.value),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.grey[300]!,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))
                      ]
                    : [],
              ),
              child: Column(
                children: [
                  Icon(opt.icon,
                      color: selected ? Colors.white : Colors.grey[500],
                      size: 24),
                  const SizedBox(height: 6),
                  Text(opt.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected ? Colors.white : Colors.grey[600])),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _dateRangeSelector(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _dateButton(
            label: 'Desde',
            date: _fromDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _fromDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'MX'),
              );
              if (picked != null) setState(() => _fromDate = picked);
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _dateButton(
            label: 'Hasta',
            date: _toDate,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _toDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                locale: const Locale('es', 'MX'),
              );
              if (picked != null) setState(() => _toDate = picked);
            },
          ),
        ),
      ],
    );
  }

  Widget _dateButton({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(_dateFmt.format(date),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.download),
        label: Text(
          _isLoading ? 'Generando archivo...' : 'Generar y compartir Excel',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              _exportAllGroups ? AppColors.accent : AppColors.primary,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: _isLoading ? null : _export,
      ),
    );
  }

  Widget _infoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 18),
              SizedBox(width: 8),
              Text('¿Cómo funciona?',
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          SizedBox(height: 8),
          Text(
            '• "Un grupo": exporta el grupo seleccionado\n'
            '• "Todos los grupos": genera un libro con una hoja por grupo\n'
            '• La asistencia muestra P/F/R/J con colores\n'
            '• Las calificaciones incluyen promedio final por alumno\n'
            '• Se abre el menú para compartir por WhatsApp, Gmail o Drive',
            style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── Lógica de exportación ────────────────────────────────────────────

  Future<void> _export() async {
    if (!_exportAllGroups && _selectedGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un grupo primero'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ExcelExportService();

      if (_exportAllGroups) {
        await _exportAll(service);
      } else {
        await _exportSingle(service);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Archivo generado correctamente'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al exportar: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Exportar TODOS los grupos ──────────────────────────────────────
  Future<void> _exportAll(ExcelExportService service) async {
    final groups = ref.read(groupsProvider).maybeWhen(
          data: (g) => g,
          orElse: () => <GroupModel>[],
        );

    if (groups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tienes grupos creados')),
        );
      }
      return;
    }

    final studentRepo = ref.read(studentRepositoryProvider)!;
    final attRepo = ref.read(attendanceRepositoryProvider)!;
    final partialRepo = ref.read(partialRepositoryProvider)!;
    final actRepo = ref.read(activityRepositoryProvider)!;
    final evalRepo = ref.read(evaluationRepositoryProvider)!;

    final Map<String, List<StudentModel>> studentsByGroup = {};
    final Map<String, String> groupNames = {};

    for (final g in groups) {
      groupNames[g.id] = g.name;
      studentsByGroup[g.id] = await studentRepo.watchStudents(g.id).first;
    }

    if (_exportType == 'attendance' || _exportType == 'both') {
      final Map<String, List<AttendanceModel>> attendanceByGroup = {};
      for (final g in groups) {
        attendanceByGroup[g.id] = await attRepo.getAttendanceRange(
          g.id,
          _fromDate,
          _toDate,
        );
      }
      await service.exportAllGroupsAttendance(
        studentsByGroup: studentsByGroup,
        attendanceByGroup: attendanceByGroup,
        groupNames: groupNames,
      );
    }

    if (_exportType == 'grades' || _exportType == 'both') {
      final Map<String, List<Map<String, dynamic>>> summaryByGroup = {};

      for (final g in groups) {
        final partials = await partialRepo.watchPartials(g.id).first;
        final summaryData = <Map<String, dynamic>>[];

        for (final partial in partials) {
          final attendance = await attRepo.getAttendanceRange(
              g.id, partial.startDate, partial.endDate);
          final activities =
              await actRepo.watchActivities(g.id, partial.name).first;
          final actTitles = activities.map((a) => a.title).toSet().toList();
          final evaluations =
              await evalRepo.watchEvaluations(g.id, partial.name).first;

          for (final student in studentsByGroup[g.id]!) {
            final attCount = attendance
                .where((a) =>
                    a.studentId == student.id &&
                    (a.status == AttendanceStatus.present ||
                        a.status == AttendanceStatus.late))
                .length;

            final actCount = activities
                .where((a) =>
                    a.studentId == student.id && (a.completed || a.reponed))
                .length;

            final eval = evaluations.firstWhere(
              (e) => e.studentId == student.id,
              orElse: () => EvaluationModel(
                id: '',
                groupId: g.id,
                studentId: student.id,
                partialName: partial.name,
                criteria: [],
                recordedAt: DateTime.now(),
              ),
            );

            final result = GradeCalculator.calculate(
              components: partial.activeComponents,
              studentAttendance: attCount,
              totalClassDays: partial.totalClassDays,
              studentActivities: actCount,
              totalActivities: actTitles.length,
              evaluationPoints: eval.totalPoints,
              customValues: eval.customValues,
              extraPoints: eval.extraPoints,
            );

            summaryData.add({
              'studentId': student.id,
              'partialName': partial.name,
              'total': result.total,
            });
          }
        }
        summaryByGroup[g.id] = summaryData;
      }

      await service.exportAllGroupsSummary(
        studentsByGroup: studentsByGroup,
        summaryByGroup: summaryByGroup,
        groupNames: groupNames,
      );
    }
  }

  // ── Exportar UN grupo ──────────────────────────────────────────────
  Future<void> _exportSingle(ExcelExportService service) async {
    final students = await ref
        .read(studentRepositoryProvider)!
        .watchStudents(_selectedGroup!.id)
        .first;

    if (_exportType == 'attendance' || _exportType == 'both') {
      final attRepo = ref.read(attendanceRepositoryProvider)!;
      final attendance = await attRepo.getAttendanceRange(
        _selectedGroup!.id,
        _fromDate,
        _toDate,
      );
      await service.exportAttendance(
        groupName: _selectedGroup!.name,
        students: students,
        attendance: attendance,
      );
    }

    if (_exportType == 'grades' || _exportType == 'both') {
      final partials = await ref
          .read(partialRepositoryProvider)!
          .watchPartials(_selectedGroup!.id)
          .first;

      final attRepo = ref.read(attendanceRepositoryProvider)!;
      final actRepo = ref.read(activityRepositoryProvider)!;
      final evalRepo = ref.read(evaluationRepositoryProvider)!;
      final summaryData = <Map<String, dynamic>>[];

      for (final partial in partials) {
        final attendance = await attRepo.getAttendanceRange(
          _selectedGroup!.id,
          partial.startDate,
          partial.endDate,
        );
        final activities = await actRepo
            .watchActivities(_selectedGroup!.id, partial.name)
            .first;
        final actTitles = activities.map((a) => a.title).toSet().toList();
        final evaluations = await evalRepo
            .watchEvaluations(_selectedGroup!.id, partial.name)
            .first;

        for (final student in students) {
          final attCount = attendance
              .where((a) =>
                  a.studentId == student.id &&
                  (a.status == AttendanceStatus.present ||
                      a.status == AttendanceStatus.late))
              .length;

          final actCount = activities
              .where((a) =>
                  a.studentId == student.id && (a.completed || a.reponed))
              .length;

          final eval = evaluations.firstWhere(
            (e) => e.studentId == student.id,
            orElse: () => EvaluationModel(
              id: '',
              groupId: _selectedGroup!.id,
              studentId: student.id,
              partialName: partial.name,
              criteria: [],
              recordedAt: DateTime.now(),
            ),
          );

          final result = GradeCalculator.calculate(
            components: partial.activeComponents,
            studentAttendance: attCount,
            totalClassDays: partial.totalClassDays,
            studentActivities: actCount,
            totalActivities: actTitles.length,
            evaluationPoints: eval.totalPoints,
            customValues: eval.customValues,
            extraPoints: eval.extraPoints,
          );

          summaryData.add({
            'studentId': student.id,
            'partialName': partial.name,
            'att': result.attendanceScore,
            'act': result.activitiesScore,
            'eval': result.evaluationScore,
            'total': result.total,
          });
        }
      }

      await service.exportPartialSummary(
        groupName: _selectedGroup!.name,
        students: students,
        summaryData: summaryData,
      );
    }
  }
}
