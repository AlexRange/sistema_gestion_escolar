import 'package:cloud_firestore/cloud_firestore.dart';

class GradeModel {
  final String id;
  final String groupId;
  final String studentId;
  final String periodName;
  final double value;
  final DateTime recordedAt;

  const GradeModel({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.periodName,
    required this.value,
    required this.recordedAt,
  });

  factory GradeModel.fromFirestore(Map<String, dynamic> d, String id) =>
      GradeModel(
        id: id,
        groupId: d['groupId'] ?? '',
        studentId: d['studentId'] ?? '',
        periodName: d['periodName'] ?? '',
        value: (d['value'] as num).toDouble(),
        recordedAt: (d['recordedAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'studentId': studentId,
        'periodName': periodName,
        'value': value,
        'recordedAt': Timestamp.fromDate(recordedAt),
      };
}
