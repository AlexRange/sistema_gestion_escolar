import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? schoolName;
  final DateTime createdAt;

  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.schoolName,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(Map<String, dynamic> d, String id) =>
      UserModel(
        uid: id,
        email: d['email'] ?? '',
        displayName: d['displayName'] ?? '',
        schoolName: d['schoolName'],
        createdAt: (d['createdAt'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toFirestore() => {
        'email': email,
        'displayName': displayName,
        'schoolName': schoolName,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
