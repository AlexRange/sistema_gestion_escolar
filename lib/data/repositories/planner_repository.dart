import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/planner_model.dart';

class PlannerRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  PlannerRepository({required this.userId});

  CollectionReference get _planner =>
      _db.collection('users').doc(userId).collection('plannerEntries');

  Stream<List<PlannerModel>> watchEntries() {
    return _planner
        .orderBy('date', descending: false)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PlannerModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addEntry(PlannerModel entry) async {
    await _planner.add(entry.toFirestore());
  }

  Future<void> updateEntry(PlannerModel entry) async {
    await _planner.doc(entry.id).update(entry.toFirestore());
  }

  Future<void> deleteEntry(String id) async {
    await _planner.doc(id).delete();
  }
}
