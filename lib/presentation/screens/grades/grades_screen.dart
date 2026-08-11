import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/partial_model.dart';
import '../../../data/models/activity_model.dart';
import '../../../data/models/evaluation_model.dart';
import '../../../data/models/student_model.dart';
import '../../../domain/services/grade_calculator.dart';
import '../../providers/partials_provider.dart';
import '../../providers/students_provider.dart';
import '../../providers/groups_provider.dart';
import '../../providers/attendance_provider.dart';
import '../../../data/models/attendance_model.dart';
//import '../../../data/repositories/attendance_repository.dart';\
import '../../../core/utils/back_handler.dart';
import '../../providers/attendance_override_provider.dart';

class GradesScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GradesScreen({super.key, required this.groupId});

  @override
  ConsumerState<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends ConsumerState<GradesScreen>
    with SingleTickerProviderStateMixin {
  PartialModel? _selectedPartial;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final partialsAsync = ref.watch(partialsProvider(widget.groupId));
    final studentsAsync = ref.watch(studentsProvider(widget.groupId));
    final groupName = ref.watch(groupsProvider).maybeWhen(
          data: (gs) {
            final g = gs.where((g) => g.id == widget.groupId);
            return g.isNotEmpty ? g.first.name : 'Grupo';
          },
          orElse: () => 'Grupo',
        );
    return BackHandler(
        backRoute: '/groups/${widget.groupId}',
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            title: Text('Calificaciones — $groupName',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/groups/${widget.groupId}'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.add_chart),
                tooltip: 'Nuevo parcial',
                onPressed: () => _addPartialDialog(context),
              ),
            ],
            bottom: _selectedPartial == null
                ? null
                : TabBar(
                    controller: _tabController,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    isScrollable: true, // ← importante en pantallas pequeñas
                    tabs: const [
                      Tab(
                          icon: Icon(Icons.check_circle_outline, size: 18),
                          text: 'Asistencia'),
                      Tab(
                          icon: Icon(Icons.assignment_outlined, size: 18),
                          text: 'Actividades'),
                      Tab(
                          icon: Icon(Icons.star_outline, size: 18),
                          text: 'Evaluación'),
                      Tab(
                          icon: Icon(Icons.bar_chart, size: 18),
                          text: 'Resumen'),
                    ],
                  ),
          ),
          body: partialsAsync.when(
            data: (partials) {
              if (partials.isEmpty) return _emptyPartials();

              // Inicializar automáticamente al primer parcial
              if (_selectedPartial == null && partials.isNotEmpty) {
                // Usar addPostFrameCallback para evitar setState durante build
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _selectedPartial == null) {
                    setState(() => _selectedPartial = partials.first);
                  }
                });
                // Mostrar el primer parcial inmediatamente sin tabs
                return _partialSelector(partials);
              }

              return Column(
                children: [
                  _partialSelector(partials),
                  Expanded(
                    child: studentsAsync.when(
                      data: (students) => TabBarView(
                        controller: _tabController,
                        children: [
                          _AttendanceSummaryTab(
                            groupId: widget.groupId,
                            partial: _selectedPartial!,
                            students: students,
                          ),
                          _ActivitiesTab(
                            groupId: widget.groupId,
                            partial: _selectedPartial!,
                            students: students,
                          ),
                          _EvaluationTab(
                            groupId: widget.groupId,
                            partial: _selectedPartial!,
                            students: students,
                          ),
                          _SummaryTab(
                            groupId: widget.groupId,
                            partial: _selectedPartial!,
                            students: students,
                            attendanceOverrides: ref.watch(attendanceOverrideProvider),
                          ),
                        ],
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
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

  Widget _partialSelector(List<PartialModel> partials) {
    // Sincronizar _selectedPartial con la lista actualizada por ID
    if (_selectedPartial != null) {
      final updated = partials.where((p) => p.id == _selectedPartial!.id);
      if (updated.isNotEmpty) {
        _selectedPartial = updated.first;
      } else {
        _selectedPartial = partials.first;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Row(
        children: [
          const Text('Parcial:',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                // ← usa String (id) no PartialModel
                value: _selectedPartial?.id,
                isExpanded: true,
                items: partials
                    .map((p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(p.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                        ))
                    .toList(),
                onChanged: (id) => setState(() {
                  _selectedPartial = partials.firstWhere((p) => p.id == id);
                  _tabController.animateTo(0);
                }),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.secondary, size: 20),
            onPressed: () => _editPartialDialog(_selectedPartial!),
          ),
          // Después del IconButton de editar, agrega:
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: AppColors.error, size: 20),
            onPressed: () => _confirmDeletePartial(_selectedPartial!),
          ),
        ],
      ),
    );
  }

  Widget _emptyPartials() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Sin parciales configurados',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Crea un parcial para comenzar',
              style: TextStyle(color: Colors.grey[400])),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Crear parcial'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => _addPartialDialog(context),
          ),
        ],
      ),
    );
  }

  void _addPartialDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final daysCtrl = TextEditingController();
    final activitiesCtrl = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nuevo parcial',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: _inputDeco(
                        'Nombre (ej. Parcial 1)', Icons.school_outlined),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: daysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(
                        'Total de días de clase', Icons.calendar_today),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: activitiesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco(
                        'Total de actividades', Icons.assignment_outlined),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  // Fechas
                  _dateRow(
                    label: 'Inicio',
                    date: startDate,
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('es', 'MX'),
                      );
                      if (p != null) {
                        setDialogState(() => startDate = p);
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _dateRow(
                    label: 'Fin',
                    date: endDate,
                    onTap: () async {
                      final p = await showDatePicker(
                        context: ctx,
                        initialDate: endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        locale: const Locale('es', 'MX'),
                      );
                      if (p != null) {
                        setDialogState(() => endDate = p);
                      }
                    },
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
                await ref.read(partialRepositoryProvider)!.addPartial(
                      widget.groupId,
                      PartialModel(
                        id: '',
                        groupId: widget.groupId,
                        name: nameCtrl.text.trim(),
                        totalClassDays: int.tryParse(daysCtrl.text.trim()) ?? 0,
                        totalActivities:
                            int.tryParse(activitiesCtrl.text.trim()) ?? 0,
                        startDate: startDate,
                        endDate: endDate,
                      ),
                    );
                if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: const Text('Crear'),
            ),
          ],
        ),
      ),
    );
  }

  void _editPartialDialog(PartialModel partial) {
    final daysCtrl =
        TextEditingController(text: partial.totalClassDays.toString());
    final activitiesCtrl =
        TextEditingController(text: partial.totalActivities.toString());

    // Copiar criterios existentes o poner defaults
    List<Map<String, dynamic>> criteria = partial.evaluationCriteria.isEmpty
        ? [
            {'name': 'Criterio 1'},
            {'name': 'Criterio 2'},
            {'name': 'Criterio 3'},
          ]
        : partial.evaluationCriteria
            .map((c) => {'name': c['name'] ?? ''})
            .toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Editar ${partial.name}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: daysCtrl,
                  keyboardType: TextInputType.number,
                  decoration:
                      _inputDeco('Total días de clase', Icons.calendar_today),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: activitiesCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _inputDeco(
                      'Total actividades', Icons.assignment_outlined),
                ),
                const SizedBox(height: 16),
                // Criterios de evaluación
                const Text('Criterios de evaluación (30 pts total)',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 13)),
                const SizedBox(height: 4),
                const Text(
                  'Define los criterios una vez. Al calificar solo ingresarás los puntos por alumno.',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                ...criteria.asMap().entries.map((entry) {
                  final i = entry.key;
                  final c = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: const InputDecoration(
                              labelText: 'Criterio',
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            controller: TextEditingController(text: c['name'])
                              ..selection = TextSelection.collapsed(
                                  offset: (c['name'] as String).length),
                            onChanged: (v) =>
                                setS(() => criteria[i]['name'] = v),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.error, size: 18),
                          onPressed: () => setS(() => criteria.removeAt(i)),
                        ),
                      ],
                    ),
                  );
                }),
                // Total
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar criterio',
                            style: TextStyle(fontSize: 12)),
                        onPressed: () => setS(() => criteria.add(
                              {'name': 'Criterio ${criteria.length + 1}'},
                            )),
                      ),
                      Text(
                        '${criteria.length} criterios = 30 pts',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary),
                      ),
                    ],
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
                await ref.read(partialRepositoryProvider)!.updatePartial(
                      widget.groupId,
                      partial.copyWith(
                        totalClassDays: int.tryParse(daysCtrl.text.trim()) ??
                            partial.totalClassDays,
                        totalActivities:
                            int.tryParse(activitiesCtrl.text.trim()) ??
                                partial.totalActivities,
                        evaluationCriteria: criteria,
                      ),
                    );
                if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeletePartial(PartialModel partial) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar parcial',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text(
            '¿Eliminar "${partial.name}"?\nSe borrarán todas las actividades, evaluaciones y calificaciones de este parcial.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              await ref
                  .read(partialRepositoryProvider)!
                  .deletePartial(widget.groupId, partial.id);
              setState(() => _selectedPartial = null);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Widget _dateRow({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[400]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('$label: ',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            Text(
              DateFormat('d MMM yyyy', 'es_MX').format(date),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 1 — Resumen de Asistencia del parcial
// ═══════════════════════════════════════════════════════════════════════
class _AttendanceSummaryTab extends ConsumerWidget {
  final String groupId;
  final PartialModel partial;
  final List<StudentModel> students;

  const _AttendanceSummaryTab({
    required this.groupId,
    required this.partial,
    required this.students,
  });

  String _overrideKey(String studentId) =>
      '${groupId}_${partial.id}_$studentId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attRepo = ref.watch(attendanceRepositoryProvider);
    if (attRepo == null)
      return const Center(child: CircularProgressIndicator());
    final overrides = ref.watch(attendanceOverrideProvider);
    final fmt = DateFormat('d MMM yyyy', 'es_MX');

    return FutureBuilder(
      future: attRepo.getAttendanceRange(
          groupId, partial.startDate, partial.endDate),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final attendance = snap.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _infoCard(fmt),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: AppColors.warning, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Toca el número de asistencias para corregirlo. Los cambios se mantienen mientras uses la app.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ...students.map((s) {
                final counted = attendance
                    .where((a) =>
                        a.studentId == s.id &&
                        (a.status == AttendanceStatus.present ||
                            a.status == AttendanceStatus.late))
                    .length;

                final key = _overrideKey(s.id);
                final displayed =
                    overrides.containsKey(key) ? overrides[key]! : counted;
                final safe = displayed.clamp(0, partial.totalClassDays);
                final score = partial.totalClassDays == 0
                    ? 0.0
                    : (safe / partial.totalClassDays) * 10;

                return _studentAttRow(
                  context,
                  ref,
                  s,
                  displayed,
                  safe,
                  score,
                  partial.totalClassDays,
                  key,
                  overrides.containsKey(key),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(DateFormat fmt) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('Periodo de asistencias',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${fmt.format(partial.startDate)}  →  ${fmt.format(partial.endDate)}',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _chip('Días configurados', '${partial.totalClassDays}'),
              _chip('Vale', '10 pts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20)),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _studentAttRow(
    BuildContext context,
    WidgetRef ref,
    StudentModel s,
    int displayed,
    int safe,
    double score,
    int total,
    String overrideKey,
    bool isOverridden,
  ) {
    final isAboveLimit = displayed > total;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isAboveLimit
            ? Border.all(color: AppColors.warning, width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primary.withOpacity(0.1),
            radius: 14,
            child: Text('${s.listNumber}',
                style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                if (isAboveLimit)
                  const Text('⚠️ Supera días configurados',
                      style: TextStyle(fontSize: 10, color: AppColors.warning)),
                if (isOverridden)
                  const Text('✏️ Editado manualmente',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.secondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                _editAttDialog(context, ref, s, displayed, overrideKey),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text('$safe/$total',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 12, color: AppColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _scoreColor(score).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${score.toStringAsFixed(1)} pts',
              style: TextStyle(
                  color: _scoreColor(score),
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _editAttDialog(BuildContext context, WidgetRef ref, StudentModel student,
      int current, String overrideKey) {
    final ctrl = TextEditingController(text: current.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Editar asistencias',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Días configurados: ${partial.totalClassDays}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Días asistidos',
                helperText: 'Máximo: ${partial.totalClassDays}',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref
                  .read(attendanceOverrideProvider.notifier)
                  .removeOverride(overrideKey);
              Navigator.of(ctx, rootNavigator: true).pop();
            },
            child: const Text('Resetear', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val != null && val >= 0) {
                ref
                    .read(attendanceOverrideProvider.notifier)
                    .setOverride(overrideKey, val);
                Navigator.of(ctx, rootNavigator: true).pop();
              }
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 8) return AppColors.gradeHigh;
    if (s >= 5) return AppColors.gradeMid;
    return AppColors.gradeLow;
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 2 — Actividades
// ═══════════════════════════════════════════════════════════════════════
class _ActivitiesTab extends ConsumerWidget {
  final String groupId;
  final PartialModel partial;
  final List<StudentModel> students;

  const _ActivitiesTab({
    required this.groupId,
    required this.partial,
    required this.students,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(
        activitiesProvider((groupId: groupId, partialName: partial.name)));

    return activitiesAsync.when(
      data: (activities) {
        // Obtener títulos únicos de actividades
        final titles = activities.map((a) => a.title).toSet().toList()..sort();

        return Column(
          children: [
            // Info + botón agregar actividad
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${titles.length}/${partial.totalActivities} actividades • Vale 60 pts',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Nueva', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    onPressed: () =>
                        _addActivityDialog(context, ref, activities),
                  ),
                ],
              ),
            ),
            // Tabla horizontal: alumnos × actividades
            Expanded(
              child: titles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Sin actividades registradas',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                        child: _activitiesTable(
                            context, ref, students, titles, activities),
                      ),
                    ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _activitiesTable(
    BuildContext context,
    WidgetRef ref,
    List<StudentModel> students,
    List<String> titles,
    List<ActivityModel> activities,
  ) {
    const numW = 40.0;
    const nameW = 150.0;
    const cellW = 80.0;
    const scoreW = 70.0;

    // Total real = actividades registradas (no el número configurado)
    final totalReal = titles.length;

    return DataTable(
      headingRowColor: WidgetStateProperty.all(AppColors.primary),
      border: TableBorder.all(color: Colors.grey[200]!, width: 1),
      columnSpacing: 0,
      horizontalMargin: 0,
      columns: [
        const DataColumn(
            label: SizedBox(
                width: numW,
                child: const Center(
                    child: Text('No.',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12))))),
        const DataColumn(
            label: SizedBox(
                width: nameW,
                child: const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text('Alumno',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12))))),
        ...titles.map((t) => DataColumn(
  label: SizedBox(
    width: cellW,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Tooltip(
            message: t,
            child: Text(
              t.length > 6 ? '${t.substring(0, 6)}…' : t,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 11),
            ),
          ),
        ),
        // Menú de opciones por actividad
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert,
              color: Colors.white54, size: 14),
          padding: EdgeInsets.zero,
          itemBuilder: (ctx) => [
            const PopupMenuItem(
              value: 'all_done',
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.present, size: 18),
                  SizedBox(width: 8),
                  Text('Marcar todos ✓',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'all_undone',
              child: Row(
                children: [
                  Icon(Icons.cancel_outlined,
                      color: AppColors.absent, size: 18),
                  SizedBox(width: 8),
                  Text('Desmarcar todos',
                      style: TextStyle(fontSize: 13)),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline,
                      color: AppColors.error, size: 18),
                  SizedBox(width: 8),
                  Text('Eliminar actividad',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.error)),
                ],
              ),
            ),
          ],
          onSelected: (action) async {
            if (action == 'delete') {
              _confirmDeleteActivity(context, ref, t, activities);
            } else if (action == 'all_done') {
              await ref
                  .read(activityRepositoryProvider)!
                  .markAllCompleted(groupId, t, true);
            } else if (action == 'all_undone') {
              await ref
                  .read(activityRepositoryProvider)!
                  .markAllCompleted(groupId, t, false);
            }
          },
        ),
      ],
    ),
  ),
)),
        DataColumn(
            label: SizedBox(
                width: scoreW,
                child: const Center(
                    child: Text('Pts',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12))))),
      ],
      rows: students.map((student) {
        int completedCount = 0;
        final cells = titles.map((title) {
          final act = activities.firstWhere(
            (a) => a.studentId == student.id && a.title == title,
            orElse: () => ActivityModel(
              id: '__none__',
              groupId: groupId,
              studentId: student.id,
              partialName: partial.name,
              date: DateTime.now(),
              title: title,
            ),
          );
          final done = act.completed || act.reponed;
          if (done) completedCount++;

          return DataCell(
            Container(
              width: cellW,
              alignment: Alignment.center,
              color: done
                  ? AppColors.present.withOpacity(0.1)
                  : AppColors.absent.withOpacity(0.05),
              child: act.id == '__none__'
                  ? Icon(Icons.remove, color: Colors.grey[400], size: 16)
                  : GestureDetector(
                      onTap: () async {
                        await ref
                            .read(activityRepositoryProvider)!
                            .updateActivity(
                              groupId,
                              act.copyWith(completed: !act.completed),
                            );
                      },
                      child: Icon(
                        done ? Icons.check_circle : Icons.cancel_outlined,
                        color: done ? AppColors.present : AppColors.absent,
                        size: 22,
                      ),
                    ),
            ),
          );
        }).toList();

        // Regla de 3 sobre actividades registradas reales
        final score = totalReal == 0 ? 0.0 : (completedCount / totalReal) * 60;

        return DataRow(cells: [
          DataCell(SizedBox(
              width: numW,
              child: Center(
                  child: Text('${student.listNumber}',
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12))))),
          DataCell(SizedBox(
              width: nameW,
              child: Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(student.fullName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500))))),
          ...cells,
          DataCell(Container(
            width: scoreW,
            alignment: Alignment.center,
            child: Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: score >= 36
                      ? AppColors.gradeHigh
                      : score >= 24
                          ? AppColors.gradeMid
                          : AppColors.gradeLow),
            ),
          )),
        ]);
      }).toList(),
    );
  }

  void _addActivityDialog(
      BuildContext context, WidgetRef ref, List<ActivityModel> existing) {
    final titleCtrl = TextEditingController();
    DateTime date = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Nueva actividad',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppColors.primary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la actividad',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    locale: const Locale('es', 'MX'),
                  );
                  if (p != null) setS(() => date = p);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('d MMM yyyy', 'es_MX').format(date),
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Se registrará para todos los alumnos del grupo. Después puedes marcar quién la realizó.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
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
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                await ref
                    .read(activityRepositoryProvider)!
                    .registerDailyActivity(
                      groupId: groupId,
                      studentIds: students.map((s) => s.id).toList(),
                      partialName: partial.name,
                      title: title,
                      date: date,
                    );
                if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
              },
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteActivity(BuildContext context, WidgetRef ref, String title,
      List<ActivityModel> activities) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar actividad',
            style:
                TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text(
            '¿Eliminar "$title" para todos los alumnos?\nEsta acción no se puede deshacer.'),
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
              Navigator.pop(ctx);
              // Eliminar todos los registros de esa actividad
              final toDelete =
                  activities.where((a) => a.title == title).toList();
              for (final act in toDelete) {
                await ref
                    .read(activityRepositoryProvider)!
                    .deleteActivity(groupId, act.id);
              }
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 3 — Evaluación Final
// ═══════════════════════════════════════════════════════════════════════
class _EvaluationTab extends ConsumerWidget {
  final String groupId;
  final PartialModel partial;
  final List<StudentModel> students;

  const _EvaluationTab({
    required this.groupId,
    required this.partial,
    required this.students,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evalsAsync = ref.watch(
        evaluationsProvider((groupId: groupId, partialName: partial.name)));

    return evalsAsync.when(
      data: (evals) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La evaluación vale 30 puntos. Toca a un alumno para registrar sus criterios.',
                    style: TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          ...students.map((student) {
            final eval = evals.firstWhere(
              (e) => e.studentId == student.id,
              orElse: () => EvaluationModel(
                id: '',
                groupId: groupId,
                studentId: student.id,
                partialName: partial.name,
                criteria: [],
                recordedAt: DateTime.now(),
              ),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                  radius: 14,
                  child: Text('${student.listNumber}',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(student.fullName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                trailing: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(eval.totalPoints).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    eval.criteria.isEmpty
                        ? 'Sin eval.'
                        : '${eval.totalPoints.toStringAsFixed(1)}/30',
                    style: TextStyle(
                        color: _scoreColor(eval.totalPoints),
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
                onTap: () => _evalDialog(context, ref, student, eval),
              ),
            );
          }),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Color _scoreColor(double s) {
    if (s >= 24) return AppColors.gradeHigh;
    if (s >= 18) return AppColors.gradeMid;
    return AppColors.gradeLow;
  }

  void _evalDialog(BuildContext context, WidgetRef ref, StudentModel student,
      EvaluationModel existing) {
    final templateCriteria = partial.evaluationCriteria.isEmpty
        ? [
            {'name': 'Criterio 1'},
            {'name': 'Criterio 2'},
            {'name': 'Criterio 3'}
          ]
        : partial.evaluationCriteria;

    // Estado inicial de checks
    final extraCtrl = TextEditingController(
  text: existing.extraPoints.toStringAsFixed(1),
);
    List<bool> checks = templateCriteria.map((c) {
      final name = c['name'] as String;
      final found = existing.criteria.where((ec) => ec.name == name);
      return found.isNotEmpty ? found.first.completed : false;
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final completedCount = checks.where((v) => v).length;
          final total = templateCriteria.isEmpty
              ? 0.0
              : (completedCount / templateCriteria.length) * 30;

          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Evaluación Final',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.primary)),
                Text(student.fullName,
                    style: const TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Info regla de 3
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Marca los criterios cumplidos. $completedCount/${templateCriteria.length} = ${total.toStringAsFixed(1)}/30 pts',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  // Lista de criterios como checkboxes
                  ...templateCriteria.asMap().entries.map((entry) {
                    final i = entry.key;
                    final c = entry.value;
                    return CheckboxListTile(
                      value: checks[i],
                      activeColor: AppColors.present,
                      title: Text(c['name'] as String,
                          style: const TextStyle(fontSize: 14)),
                      dense: true,
                      onChanged: (v) => setS(() => checks[i] = v ?? false),
                    );
                  }),
                  const Divider(),

// ── Puntos extra ──────────────────────────────────────
Padding(
  padding: const EdgeInsets.symmetric(vertical: 4),
  child: Row(
    children: [
      const Icon(Icons.star, color: Colors.amber, size: 20),
      const SizedBox(width: 8),
      const Text('Pts extra:',
          style: TextStyle(fontWeight: FontWeight.bold)),
      const Spacer(),
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.remove_circle_outline,
            color: AppColors.error, size: 22),
        onPressed: () {
          final current =
              double.tryParse(extraCtrl.text) ?? 0;
          final next = (current - 0.5).clamp(0.0, 1.0);
          setS(() => extraCtrl.text =
              next.toStringAsFixed(1));
        },
      ),
      const SizedBox(width: 4),
      SizedBox(
        width: 55,
        child: TextField(
          controller: extraCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(
            isDense: true,
            border: OutlineInputBorder(),
            contentPadding:
                EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          ),
          onChanged: (_) => setS(() {}),
        ),
      ),
      const SizedBox(width: 4),
      IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: const Icon(Icons.add_circle_outline,
            color: AppColors.present, size: 22),
        onPressed: () {
          final current =
              double.tryParse(extraCtrl.text) ?? 0;
          final next = (current + 0.5).clamp(0.0, 1.0);
          setS(() => extraCtrl.text =
              next.toStringAsFixed(1));
        },
      ),
      const SizedBox(width: 4),
      const Text('/ 1 pt máx.',
          style: TextStyle(fontSize: 11, color: Colors.grey)),
    ],
  ),
),

// Total
Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Puntos obtenidos:',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '${total.toStringAsFixed(1)} / 30 pts',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: total >= 18
                                  ? AppColors.gradeHigh
                                  : AppColors.gradeLow),
                        ),
                      ],
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
                  final criteriaToSave = templateCriteria
                      .asMap()
                      .entries
                      .map((entry) => EvaluationCriterion(
                            name: entry.value['name'] as String,
                            completed: checks[entry.key],
                          ))
                      .toList();

                  final extra = double.tryParse(extraCtrl.text) ?? 0;

await ref
    .read(evaluationRepositoryProvider)!
    .saveEvaluation(
      groupId,
      EvaluationModel(
        id: existing.id,
        groupId: groupId,
        studentId: student.id,
        partialName: partial.name,
        criteria: criteriaToSave,
        extraPoints: extra.clamp(0.0, 1.0),
        recordedAt: DateTime.now(),
      ),
    );
                  if (ctx.mounted) Navigator.of(ctx, rootNavigator: true).pop();
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// TAB 4 — Resumen y Calificación Final
// ═══════════════════════════════════════════════════════════════════════
class _SummaryTab extends ConsumerWidget {
  final String groupId;
  final PartialModel partial;
  final List<StudentModel> students;
  final Map<String, int> attendanceOverrides; // ← nuevo

  const _SummaryTab({
    required this.groupId,
    required this.partial,
    required this.students,
    required this.attendanceOverrides,
  });

  // Misma key que usa _AttendanceSummaryTab
  String _overrideKey(String studentId) =>
      '${groupId}_${partial.id}_$studentId';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evalsAsync = ref.watch(
        evaluationsProvider((groupId: groupId, partialName: partial.name)));
    final activitiesAsync = ref.watch(
        activitiesProvider((groupId: groupId, partialName: partial.name)));
    final attRepo = ref.watch(attendanceRepositoryProvider);

    if (attRepo == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return evalsAsync.when(
      data: (evals) => activitiesAsync.when(
        data: (activities) => FutureBuilder(
          future: attRepo.getAttendanceRange(
              groupId, partial.startDate, partial.endDate),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final attendance = snap.data!;
            final actTitles =
                activities.map((a) => a.title).toSet().toList();

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _formulaCard(),
                  const SizedBox(height: 12),
                  ...students.map((student) {
                    // ── Asistencia: usar override si existe ──────────
                    final rawCount = attendance
                        .where((a) =>
                            a.studentId == student.id &&
                            (a.status == AttendanceStatus.present ||
                                a.status == AttendanceStatus.late))
                        .length;

                    final key = _overrideKey(student.id);
                    final attCount = attendanceOverrides.containsKey(key)
                        ? attendanceOverrides[key]!.clamp(
                            0, partial.totalClassDays)
                        : rawCount.clamp(0, partial.totalClassDays);

                    // ── Actividades ───────────────────────────────────
                    final actCount = activities
                        .where((a) =>
                            a.studentId == student.id &&
                            (a.completed || a.reponed))
                        .length;

                    // ── Evaluación ────────────────────────────────────
                    final eval = evals.firstWhere(
                      (e) => e.studentId == student.id,
                      orElse: () => EvaluationModel(
                        id: '',
                        groupId: groupId,
                        studentId: student.id,
                        partialName: partial.name,
                        criteria: [],
                        recordedAt: DateTime.now(),
                      ),
                    );

                    final result = GradeCalculator.calculate(
                      studentAttendance: attCount,
                      totalClassDays: partial.totalClassDays,
                      studentActivities: actCount,
                      totalActivities: actTitles.length,
                      evaluationPoints: eval.totalPoints,
                      extraPoints: eval.extraPoints, // ← NUEVO
                    );

                    // Indicar si se usó override
                    final usedOverride =
                        attendanceOverrides.containsKey(key);

                    return _summaryCard(
                        student, result, attCount, actCount,
                        eval.totalPoints, usedOverride);
                  }),
                  // Nota informativa
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppColors.primary, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'El promedio final del cuatrimestre se calcula al exportar el reporte de calificaciones.',
                            style: TextStyle(
                                fontSize: 12, color: Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      loading: () =>
          const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _formulaCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.secondary]),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          const Text('Fórmula de evaluación',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _formulaItem(
                  'Asistencia', '10%', Icons.check_circle_outline),
              _formulaItem(
                  'Actividades', '60%', Icons.assignment_outlined),
              _formulaItem('Evaluación', '30%', Icons.star_outline),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star,
                      color: Colors.amber, size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Hasta 5 pts extra',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('≥ 60 pts = ACREDITADO',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _formulaItem(String label, String pct, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(height: 4),
        Text(pct,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18)),
        Text(label,
            style:
                const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }

  Widget _summaryCard(
    StudentModel student,
    GradeResult result,
    int attCount,
    int actCount,
    double evalPts,
    bool usedOverride,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(
            color: result.accredited
                ? AppColors.gradeHigh
                : AppColors.gradeLow,
            width: 5,
          ),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.1),
                radius: 14,
                child: Text('${student.listNumber}',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.fullName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                    // Indicador de override
                    if (usedOverride)
                      const Text('✏️ Asistencia editada manualmente',
                          style: TextStyle(
                              fontSize: 10,
                              color: AppColors.secondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: result.accredited
                      ? AppColors.gradeHigh
                      : AppColors.gradeLow,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  result.accredited ? 'ACREDITADO' : 'NO ACREDITADO',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _scoreItem('Asistencia',
                  result.attendanceScore.toStringAsFixed(1), '/10'),
              _scoreItem('Actividades',
                  result.activitiesScore.toStringAsFixed(1), '/60'),
              _scoreItem('Evaluación',
                  result.evaluationScore.toStringAsFixed(1), '/30'),
              _scoreItem(
                'TOTAL',
                result.total.toStringAsFixed(1),
                '/100',
                isTotal: true,
                color: result.accredited
                    ? AppColors.gradeHigh
                    : AppColors.gradeLow,
              ),
            ],
          ),
          // Después del Row de _scoreItem(...)
if (result.extraPoints > 0) ...[
  const SizedBox(height: 6),
  Align(
    alignment: Alignment.centerRight,
    child: Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Colors.amber.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star,
              color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(
            '+${(result.extraPoints / 10).toStringAsFixed(1)} pt extra (${result.extraPoints.toStringAsFixed(0)} en calificación)',
            style: const TextStyle(
                fontSize: 12,
                color: Colors.amber,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  ),
],
        ],
      ),
    );
  }

  Widget _scoreItem(String label, String value, String max,
      {bool isTotal = false, Color? color}) {
    return Column(
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTotal ? 20 : 16,
                    color: color ?? AppColors.primary),
              ),
              TextSpan(
                text: max,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: isTotal
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ],
    );
  }
}