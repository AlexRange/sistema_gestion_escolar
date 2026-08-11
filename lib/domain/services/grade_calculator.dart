class GradeCalculator {
  static GradeResult calculate({
    required int studentAttendance,
    required int totalClassDays,
    required int studentActivities,
    required int totalActivities,
    required double evaluationPoints,
    double extraPoints = 0,       // ← NUEVO
    double maxExtraPoints = 5.0,  // ← NUEVO tope configurable
  }) {
    final safeAtt =
        studentAttendance.clamp(0, totalClassDays);
    final safeAct = studentActivities
        .clamp(0, totalActivities == 0 ? 1 : totalActivities);

    final attScore = totalClassDays == 0
        ? 0.0
        : (safeAtt / totalClassDays) * 10;

    final actScore = totalActivities == 0
        ? 0.0
        : (safeAct / totalActivities) * 60;

    final evalScore =
        evaluationPoints.clamp(0, 30).toDouble();

    // El profesor ingresa en escala 0-10, convertimos a 0-100
    final safeExtra =
        (extraPoints.clamp(0, maxExtraPoints) * 10).toDouble();

    // Total con puntos extra, tope 100
    final total =
        (attScore + actScore + evalScore + safeExtra)
            .clamp(0, 100)
            .toDouble();

    return GradeResult(
      attendanceScore: double.parse(attScore.toStringAsFixed(2)),
      activitiesScore: double.parse(actScore.toStringAsFixed(2)),
      evaluationScore: double.parse(evalScore.toStringAsFixed(2)),
      extraPoints: double.parse(safeExtra.toStringAsFixed(2)),
      total: double.parse(total.toStringAsFixed(2)),
      accredited: total >= 60,
    );
  }
}

class GradeResult {
  final double attendanceScore;
  final double activitiesScore;
  final double evaluationScore;
  final double extraPoints;   // ← NUEVO
  final double total;
  final bool accredited;

  const GradeResult({
    required this.attendanceScore,
    required this.activitiesScore,
    required this.evaluationScore,
    required this.extraPoints,
    required this.total,
    required this.accredited,
  });
}
