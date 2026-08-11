import 'package:cloud_firestore/cloud_firestore.dart';

class PlannerModel {
  final String id;
  final String? groupId;
  final DateTime date;
  final String title;
  final String? description;
  final bool isCompleted;

  const PlannerModel({
    required this.id,
    this.groupId,
    required this.date,
    required this.title,
    this.description,
    this.isCompleted = false,
  });

  factory PlannerModel.fromFirestore(Map<String, dynamic> d, String id) =>
      PlannerModel(
        id: id,
        groupId: d['groupId'],
        date: (d['date'] as Timestamp).toDate(),
        title: d['title'] ?? '',
        description: d['description'],
        isCompleted: d['isCompleted'] ?? false,
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'date': Timestamp.fromDate(date),
        'title': title,
        'description': description,
        'isCompleted': isCompleted,
      };

  PlannerModel copyWith({bool? isCompleted, String? title, String? description}) =>
      PlannerModel(
        id: id,
        groupId: groupId,
        date: date,
        title: title ?? this.title,
        description: description ?? this.description,
        isCompleted: isCompleted ?? this.isCompleted,
      );
}
