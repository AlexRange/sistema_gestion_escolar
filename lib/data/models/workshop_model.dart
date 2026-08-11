import 'package:cloud_firestore/cloud_firestore.dart';

class WorkshopStudentRef {
  final String studentId;
  final String groupId;
  final String studentName;
  final int listNumber;

  const WorkshopStudentRef({
    required this.studentId,
    required this.groupId,
    required this.studentName,
    required this.listNumber,
  });

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'groupId': groupId,
        'studentName': studentName,
        'listNumber': listNumber,
      };

  factory WorkshopStudentRef.fromMap(Map<String, dynamic> d) =>
      WorkshopStudentRef(
        studentId: d['studentId'] ?? '',
        groupId: d['groupId'] ?? '',
        studentName: d['studentName'] ?? '',
        listNumber: d['listNumber'] ?? 0,
      );
}

class WorkshopModel {
  final String id;
  final String name;
  final String teacherName;
  final String partialName;
  // Lista de alumnos seleccionados manualmente
  final List<WorkshopStudentRef> students;
  final DateTime createdAt;

  const WorkshopModel({
    required this.id,
    required this.name,
    required this.teacherName,
    required this.partialName,
    this.students = const [],
    required this.createdAt,
  });

  factory WorkshopModel.fromFirestore(Map<String, dynamic> d, String id) =>
      WorkshopModel(
        id: id,
        name: d['name'] ?? '',
        teacherName: d['teacherName'] ?? '',
        partialName: d['partialName'] ?? '',
        students: (d['students'] as List<dynamic>? ?? [])
            .map((s) =>
                WorkshopStudentRef.fromMap(s as Map<String, dynamic>))
            .toList(),
        createdAt: (d['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'teacherName': teacherName,
        'partialName': partialName,
        'students': students.map((s) => s.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };

  WorkshopModel copyWith({List<WorkshopStudentRef>? students}) =>
      WorkshopModel(
        id: id,
        name: name,
        teacherName: teacherName,
        partialName: partialName,
        students: students ?? this.students,
        createdAt: createdAt,
      );
}
