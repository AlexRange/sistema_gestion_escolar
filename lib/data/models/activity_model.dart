import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityModel {
  final String id;
  final String groupId;
  final String studentId;
  final String partialName;   // 'Parcial 1', 'Parcial 2', etc.
  final DateTime date;
  final String title;         // nombre de la actividad
  final bool completed;       // ¿la realizó?
  final bool reponed;         // ¿la repuso después?
  final String? notes;

  const ActivityModel({
    required this.id,
    required this.groupId,
    required this.studentId,
    required this.partialName,
    required this.date,
    required this.title,
    this.completed = false,
    this.reponed = false,
    this.notes,
  });

  factory ActivityModel.fromFirestore(Map<String, dynamic> d, String id) =>
      ActivityModel(
        id: id,
        groupId: d['groupId'] ?? '',
        studentId: d['studentId'] ?? '',
        partialName: d['partialName'] ?? '',
        date: (d['date'] as Timestamp).toDate(),
        title: d['title'] ?? '',
        completed: d['completed'] ?? false,
        reponed: d['reponed'] ?? false,
        notes: d['notes'],
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'studentId': studentId,
        'partialName': partialName,
        'date': Timestamp.fromDate(date),
        'title': title,
        'completed': completed,
        'reponed': reponed,
        'notes': notes,
      };

  ActivityModel copyWith({bool? completed, bool? reponed, String? notes}) =>
      ActivityModel(
        id: id,
        groupId: groupId,
        studentId: studentId,
        partialName: partialName,
        date: date,
        title: title,
        completed: completed ?? this.completed,
        reponed: reponed ?? this.reponed,
        notes: notes ?? this.notes,
      );
}
