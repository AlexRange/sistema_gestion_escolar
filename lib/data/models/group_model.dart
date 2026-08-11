import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String subject;
  final String schoolYear;
  final int studentCount;
  final DateTime createdAt;

  const GroupModel({
    required this.id,
    required this.name,
    required this.subject,
    required this.schoolYear,
    this.studentCount = 0,
    required this.createdAt,
  });

  factory GroupModel.fromFirestore(Map<String, dynamic> d, String id) =>
      GroupModel(
        id: id,
        name: d['name'] ?? '',
        subject: d['subject'] ?? '',
        schoolYear: d['schoolYear'] ?? '',
        studentCount: d['studentCount'] ?? 0,
        createdAt: (d['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'subject': subject,
        'schoolYear': schoolYear,
        'studentCount': studentCount,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  GroupModel copyWith({
    String? name,
    String? subject,
    String? schoolYear,
    int? studentCount,
  }) =>
      GroupModel(
        id: id,
        name: name ?? this.name,
        subject: subject ?? this.subject,
        schoolYear: schoolYear ?? this.schoolYear,
        studentCount: studentCount ?? this.studentCount,
        createdAt: createdAt,
      );
}
