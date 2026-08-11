import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/student_model.dart';

class StudentRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  StudentRepository({required this.userId});

  CollectionReference _students(String groupId) => _db
      .collection('users')
      .doc(userId)
      .collection('groups')
      .doc(groupId)
      .collection('students');

  Stream<List<StudentModel>> watchStudents(String groupId) {
    return _students(groupId)
        .orderBy('listNumber')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StudentModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addStudent(String groupId, StudentModel student) async {
    await _students(groupId).add(student.toFirestore());
  }

  Future<void> updateStudent(String groupId, StudentModel student) async {
    await _students(groupId).doc(student.id).update(student.toFirestore());
  }

  Future<void> deleteStudent(String groupId, String studentId) async {
    await _students(groupId).doc(studentId).delete();
  }

  Future<void> importStudents(
      String groupId, List<StudentModel> students) async {
    final batch = _db.batch();
    for (final s in students) {
      final ref = _students(groupId).doc();
      batch.set(ref, s.toFirestore());
    }
    await batch.commit();
  }

  Future<int> getStudentCount(String groupId) async {
    final snap = await _students(groupId).count().get();
    return snap.count ?? 0;
  }
}
