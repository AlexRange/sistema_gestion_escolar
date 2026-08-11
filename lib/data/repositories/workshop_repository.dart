import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/workshop_model.dart';
import '../models/attendance_model.dart';

class WorkshopRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  WorkshopRepository({required this.userId});

  CollectionReference get _workshops =>
      _db.collection('users').doc(userId).collection('workshops');

  CollectionReference _sessions(String workshopId) =>
      _workshops.doc(workshopId).collection('sessions');

  Stream<List<WorkshopModel>> watchWorkshops() {
    return _workshops
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => WorkshopModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addWorkshop(WorkshopModel w) async {
    await _workshops.add(w.toFirestore());
  }

  Future<void> updateWorkshop(WorkshopModel w) async {
    await _workshops.doc(w.id).update(w.toFirestore());
  }

  Future<void> deleteWorkshop(String id) async {
    await _workshops.doc(id).delete();
  }

  Stream<List<AttendanceModel>> watchSessions(String workshopId) {
    return _sessions(workshopId)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> saveSessionBatch(
      String workshopId, List<AttendanceModel> list) async {
    if (list.isEmpty) return;
    final batch = _db.batch();
    final date = list.first.date;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final existing = await _sessions(workshopId)
        .where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();

    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final a in list) {
      final ref = _sessions(workshopId).doc();
      batch.set(ref, a.toFirestore());
    }
    await batch.commit();
  }

  Future<List<AttendanceModel>> getSessionsAll(String workshopId) async {
    final snap =
        await _sessions(workshopId).orderBy('date').get();
    return snap.docs
        .map((d) => AttendanceModel.fromFirestore(
            d.data() as Map<String, dynamic>, d.id))
        .toList();
  }
}
