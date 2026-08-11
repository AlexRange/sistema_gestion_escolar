import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/partial_model.dart';

class PartialRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  PartialRepository({required this.userId});

  CollectionReference _partials(String groupId) => _db
      .collection('users')
      .doc(userId)
      .collection('groups')
      .doc(groupId)
      .collection('partials');

  Stream<List<PartialModel>> watchPartials(String groupId) {
    return _partials(groupId)
        .orderBy('startDate')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PartialModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addPartial(
      String groupId, PartialModel partial) async {
    await _partials(groupId).add(partial.toFirestore());
  }

  Future<void> updatePartial(
      String groupId, PartialModel partial) async {
    await _partials(groupId)
        .doc(partial.id)
        .update(partial.toFirestore());
  }

  Future<void> deletePartial(
      String groupId, String partialId) async {
    await _partials(groupId).doc(partialId).delete();
  }
}
