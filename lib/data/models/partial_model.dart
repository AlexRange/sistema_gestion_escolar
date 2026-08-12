import 'package:cloud_firestore/cloud_firestore.dart';
import 'grading_component_model.dart';

class PartialModel {
  final String id;
  final String groupId;
  final String name;
  final int totalClassDays;
  final int totalActivities;
  final DateTime startDate;
  final DateTime endDate;
  final bool isClosed;
  final List<Map<String, dynamic>> evaluationCriteria;
  final List<GradingComponent> gradingComponents; // ← NUEVO

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
    this.gradingComponents = const [], // ← vacío = usar defaults
  });

  // Si no tiene componentes configurados usa los defaults
  List<GradingComponent> get activeComponents =>
      gradingComponents.isEmpty
          ? GradingComponent.defaults
          : gradingComponents;

  // Suma total de pesos (debe ser 1.0 = 100%)
  double get totalWeight =>
      activeComponents.fold(0.0, (sum, c) => sum + c.weight);

  // Verificar si los pesos son válidos
  bool get weightsAreValid =>
      (totalWeight - 1.0).abs() < 0.001;

  factory PartialModel.fromFirestore(
      Map<String, dynamic> d, String id) =>
      PartialModel(
        id: id,
        groupId: d['groupId'] ?? '',
        name: d['name'] ?? '',
        totalClassDays: d['totalClassDays'] ?? 0,
        totalActivities: d['totalActivities'] ?? 0,
        startDate: (d['startDate'] as Timestamp).toDate(),
        endDate: (d['endDate'] as Timestamp).toDate(),
        isClosed: d['isClosed'] ?? false,
        evaluationCriteria: List<Map<String, dynamic>>.from(
            d['evaluationCriteria'] ?? []),
        gradingComponents:
            (d['gradingComponents'] as List<dynamic>? ?? [])
                .map((c) => GradingComponent.fromMap(
                    c as Map<String, dynamic>))
                .toList(),
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
        'gradingComponents':
            gradingComponents.map((c) => c.toMap()).toList(),
      };

  PartialModel copyWith({
    int? totalClassDays,
    int? totalActivities,
    bool? isClosed,
    List<Map<String, dynamic>>? evaluationCriteria,
    List<GradingComponent>? gradingComponents,
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
        gradingComponents:
            gradingComponents ?? this.gradingComponents,
      );
}
