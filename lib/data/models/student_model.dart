//import 'package:cloud_firestore/cloud_firestore.dart';

class StudentModel {
  final String id;
  final String groupId;
  final String firstName;
  final String lastName;
  final String? matricula;
  final int listNumber;
  final bool isActive;

  const StudentModel({
    required this.id,
    required this.groupId,
    required this.firstName,
    required this.lastName,
    this.matricula,
    required this.listNumber,
    this.isActive = true,
  });

  String get fullName => '$firstName $lastName';

  factory StudentModel.fromFirestore(Map<String, dynamic> d, String id) =>
      StudentModel(
        id: id,
        groupId: d['groupId'] ?? '',
        firstName: d['firstName'] ?? '',
        lastName: d['lastName'] ?? '',
        matricula: d['matricula'],
        listNumber: d['listNumber'] ?? 0,
        isActive: d['isActive'] ?? true,
      );

  Map<String, dynamic> toFirestore() => {
        'groupId': groupId,
        'firstName': firstName,
        'lastName': lastName,
        'matricula': matricula,
        'listNumber': listNumber,
        'isActive': isActive,
      };
}
