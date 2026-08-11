import 'package:cloud_firestore/cloud_firestore.dart';

class PartialModel {
  final String id;
  final String groupId;
  final String name;
  final int totalClassDays;
  final int totalActivities;
  final DateTime startDate;
  final DateTime endDate;
  final bool isClosed;
  // ← NUEVO: criterios del examen compartidos para todos los alumnos
  final List<Map<String, dynamic>> evaluationCriteria;

  const PartialModel({
    required this.id,
    required this.groupId,
    required this.name,
    required this.totalClassDays,
    required this.totalActivities,
    required this.startDate,
    required this.endDate,
    this.isClosed = false,
    this.evaluationCriteria = const [],
  });

  double get maxEvaluationPoints => evaluationCriteria
      .fold(0.0, (sum, c) => sum + ((c['maxPoints'] as num?)?.toDouble() ?? 0));

  factory PartialModel.fromFirestore(Map<String, dynamic> d, String id) =>
      PartialModel(
        id: id,
        groupId: d['groupId'] ?? '',
        name: d['name'] ?? '',
        totalClassDays: d['totalClassDays'] ?? 0,
        totalActivities: d['totalActivities'] ?? 0,
        startDate: (d['startDate'] as Timestamp).toDate(),
        endDate: (d['endDate'] as Timestamp).toDate(),
        isClosed: d['isClosed'] ?? false,
        evaluationCriteria:
            List<Map<String, dynamic>>.from(d['evaluationCriteria'] ?? []),
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'name': name,
        'totalClassDays': totalClassDays,
        'totalActivities': totalActivities,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'isClosed': isClosed,
        'evaluationCriteria': evaluationCriteria,
      };

  PartialModel copyWith({
    int? totalClassDays,
    int? totalActivities,
    bool? isClosed,
    List<Map<String, dynamic>>? evaluationCriteria,
  }) =>
      PartialModel(
        id: id,
        groupId: groupId,
        name: name,
        totalClassDays: totalClassDays ?? this.totalClassDays,
        totalActivities: totalActivities ?? this.totalActivities,
        startDate: startDate,
        endDate: endDate,
        isClosed: isClosed ?? this.isClosed,
        evaluationCriteria:
            evaluationCriteria ?? this.evaluationCriteria,
      );
}
