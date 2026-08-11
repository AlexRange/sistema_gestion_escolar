import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/grade_model.dart';

class GradeRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  GradeRepository({required this.userId});

  CollectionReference _grades(String groupId) => _db
      .collection('users')
      .doc(userId)
      .collection('groups')
      .doc(groupId)
      .collection('grades');

  Stream<List<GradeModel>> watchGrades(String groupId) {
    return _grades(groupId).snapshots().map((snap) => snap.docs
        .map((d) =>
            GradeModel.fromFirestore(d.data() as Map<String, dynamic>, d.id))
        .toList());
  }

  Future<void> saveGrade(String groupId, GradeModel grade) async {
    // Buscar si ya existe calificación del alumno en ese periodo
    final existing = await _grades(groupId)
        .where('studentId', isEqualTo: grade.studentId)
        .where('periodName', isEqualTo: grade.periodName)
        .get();
    if (existing.docs.isNotEmpty) {
      await _grades(groupId)
          .doc(existing.docs.first.id)
          .update(grade.toFirestore());
    } else {
      await _grades(groupId).add(grade.toFirestore());
    }
  }

  Future<List<String>> getPeriods(String groupId) async {
    final snap = await _grades(groupId).get();
    final periods = snap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['periodName'] as String)
        .toSet()
        .toList();
    periods.sort();
    return periods;
  }
}
