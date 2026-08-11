import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  AttendanceRepository({required this.userId});

  CollectionReference _attendance(String groupId) => _db
      .collection('users')
      .doc(userId)
      .collection('groups')
      .doc(groupId)
      .collection('attendance');

  Stream<List<AttendanceModel>> watchAttendanceByDate(
      String groupId, DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return _attendance(groupId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AttendanceModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<List<AttendanceModel>> getAttendanceRange(
      String groupId, DateTime from, DateTime to) async {
    final snap = await _attendance(groupId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();
    return snap.docs
        .map((d) => AttendanceModel.fromFirestore(
            d.data() as Map<String, dynamic>, d.id))
        .toList();
  }

  Future<void> saveAttendanceBatch(
      String groupId, List<AttendanceModel> list) async {
    final batch = _db.batch();
    // Primero eliminar registros del día para evitar duplicados
    final date = list.first.date;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    final existing = await _attendance(groupId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThan: Timestamp.fromDate(end))
        .get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    // Guardar nuevos registros
    for (final a in list) {
      final ref = _attendance(groupId).doc();
      batch.set(ref, a.toFirestore());
    }
    await batch.commit();
  }
}
