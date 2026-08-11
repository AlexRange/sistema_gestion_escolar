import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/evaluation_model.dart';

class EvaluationRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  EvaluationRepository({required this.userId});

  CollectionReference _evals(String groupId) => _db
      .collection('users')
      .doc(userId)
      .collection('groups')
      .doc(groupId)
      .collection('evaluations');

  Stream<List<EvaluationModel>> watchEvaluations(
      String groupId, String partialName) {
    return _evals(groupId)
        .where('partialName', isEqualTo: partialName)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => EvaluationModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> saveEvaluation(
      String groupId, EvaluationModel eval) async {
    // Buscar si ya existe para este alumno en este parcial
    final existing = await _evals(groupId)
        .where('studentId', isEqualTo: eval.studentId)
        .where('partialName', isEqualTo: eval.partialName)
        .get();
    if (existing.docs.isNotEmpty) {
      await _evals(groupId)
          .doc(existing.docs.first.id)
          .update(eval.toFirestore());
    } else {
      await _evals(groupId).add(eval.toFirestore());
    }
  }
}
