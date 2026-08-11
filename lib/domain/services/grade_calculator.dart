import '../../data/models/grading_component_model.dart';

class GradeCalculator {
  /// Calcula la calificación con componentes dinámicos.
  /// Cada componente define su tipo y peso.
  static GradeResult calculate({
    required List<GradingComponent> components,
    // Datos por tipo automático
    required int studentAttendance,
    required int totalClassDays,
    required int studentActivities,
    required int totalActivities,
    required double evaluationPoints, // ya en escala 0-30 del checklist
    // Valores manuales para componentes 'custom'
    // key = component.id → valor 0.0 a 10.0
    Map<String, double> customValues = const {},
    // Puntos extra
    double extraPoints = 0,
    double maxExtraPoints = 1.0,
  }) {
    final componentScores = <String, double>{};
    double total = 0;

    for (final component in components) {
      final maxPts = component.maxPoints; // ej. 10, 60, 30
      double score = 0;

      switch (component.type) {
        case 'attendance':
          if (totalClassDays > 0) {
            final safe =
                studentAttendance.clamp(0, totalClassDays);
            score = (safe / totalClassDays) * maxPts;
          }
          break;

        case 'activities':
          if (totalActivities > 0) {
            final safe =
                studentActivities.clamp(0, totalActivities);
            score = (safe / totalActivities) * maxPts;
          }
          break;

        case 'evaluation':
          // evaluationPoints ya viene calculado (0 a 30)
          // pero ahora puede valer diferente según el peso
          // Normalizamos: si el checklist da X/30 → X/maxPts
          final normalized =
              maxPts == 0 ? 0.0 : (evaluationPoints / 30) * maxPts;
          score = normalized.clamp(0, maxPts);
          break;

        case 'custom':
          // El profesor ingresa un valor de 0 a 10
          // Lo convertimos a la escala del componente
          final raw = customValues[component.id] ?? 0;
          score = (raw / 10) * maxPts;
          break;
      }

      componentScores[component.id] =
          double.parse(score.toStringAsFixed(2));
      total += score;
    }

    // Puntos extra (escala 0-1 del maestro → 0-10 en calificación)
    final safeExtra =
        (extraPoints.clamp(0, maxExtraPoints) * 10).toDouble();

    final finalTotal = (total + safeExtra).clamp(0, 100).toDouble();

    return GradeResult(
      componentScores: componentScores,
      components: components,
      extraPoints: double.parse(safeExtra.toStringAsFixed(2)),
      total: double.parse(finalTotal.toStringAsFixed(2)),
      accredited: finalTotal >= 60,
    );
  }
}

class GradeResult {
  final Map<String, double> componentScores; // id → puntos obtenidos
  final List<GradingComponent> components;
  final double extraPoints;
  final double total;
  final bool accredited;

  const GradeResult({
    required this.componentScores,
    required this.components,
    required this.extraPoints,
    required this.total,
    required this.accredited,
  });

  // Compatibilidad con código existente
  double get attendanceScore =>
      componentScores.entries
          .where((e) => components
              .any((c) => c.id == e.key && c.type == 'attendance'))
          .fold(0.0, (s, e) => s + e.value);

  double get activitiesScore =>
      componentScores.entries
          .where((e) => components
              .any((c) => c.id == e.key && c.type == 'activities'))
          .fold(0.0, (s, e) => s + e.value);

  double get evaluationScore =>
      componentScores.entries
          .where((e) => components
              .any((c) => c.id == e.key && c.type == 'evaluation'))
          .fold(0.0, (s, e) => s + e.value);
}
