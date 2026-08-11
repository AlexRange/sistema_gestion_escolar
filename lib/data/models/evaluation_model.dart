import 'package:cloud_firestore/cloud_firestore.dart';

class EvaluationCriterion {
  final String name;
  final bool completed;

  const EvaluationCriterion({
    required this.name,
    this.completed = false,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'completed': completed,
      };

  factory EvaluationCriterion.fromMap(Map<String, dynamic> d) =>
      EvaluationCriterion(
        name: d['name'] ?? '',
        completed: d['completed'] ?? false,
      );

  EvaluationCriterion copyWith({bool? completed}) =>
      EvaluationCriterion(
          name: name, completed: completed ?? this.completed);
}

class EvaluationModel {
  final String id;
  final String groupId;
  final String studentId;
  final String partialName;
  final List<EvaluationCriterion> criteria;
  final double extraPoints;
  // Valores para componentes custom: componentId → valor (0-10)
  final Map<String, double> customValues; // ← NUEVO
  final String? notes;
  final DateTime recordedAt;

  const EvaluationModel({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.partialName,
    required this.criteria,
    this.extraPoints = 0,
    this.customValues = const {}, // ← NUEVO
    this.notes,
    required this.recordedAt,
  });

  double get totalPoints {
    if (criteria.isEmpty) return 0;
    final completed = criteria.where((c) => c.completed).length;
    return (completed / criteria.length) * 30;
  }

  int get completedCount => criteria.where((c) => c.completed).length;
  int get totalCount => criteria.length;

  factory EvaluationModel.fromFirestore(
      Map<String, dynamic> d, String id) =>
      EvaluationModel(
        id: id,
        groupId: d['groupId'] ?? '',
        studentId: d['studentId'] ?? '',
        partialName: d['partialName'] ?? '',
        criteria: (d['criteria'] as List<dynamic>? ?? [])
            .map((c) => EvaluationCriterion.fromMap(
                c as Map<String, dynamic>))
            .toList(),
        extraPoints:
            (d['extraPoints'] as num?)?.toDouble() ?? 0,
        customValues: Map<String, double>.from(
          (d['customValues'] as Map<String, dynamic>? ?? {})
              .map((k, v) => MapEntry(k, (v as num).toDouble())),
        ),
        notes: d['notes'],
        recordedAt: (d['recordedAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'studentId': studentId,
        'partialName': partialName,
        'criteria': criteria.map((c) => c.toMap()).toList(),
        'extraPoints': extraPoints,
        'customValues': customValues,
        'notes': notes,
        'recordedAt': Timestamp.fromDate(recordedAt),
      };
}
