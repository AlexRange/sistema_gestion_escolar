import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/activity_model.dart';

class ActivityRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  ActivityRepository({required this.userId});

  CollectionReference _activities(String groupId) => _db
      .collection('users')
      .doc(userId)
      .collection('groups')
      .doc(groupId)
      .collection('activities');

  // Todas las actividades de un grupo en un parcial
  Stream<List<ActivityModel>> watchActivities(
      String groupId, String partialName) {
    return _activities(groupId)
        .where('partialName', isEqualTo: partialName)
        .orderBy('date')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ActivityModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // Registrar una nueva actividad para TODOS los alumnos del día
  Future<void> registerDailyActivity({
    required String groupId,
    required List<String> studentIds,
    required String partialName,
    required String title,
    required DateTime date,
  }) async {
    final batch = _db.batch();
    for (final sid in studentIds) {
      final ref = _activities(groupId).doc();
      batch.set(ref, ActivityModel(
        id: '',
        groupId: groupId,
        studentId: sid,
        partialName: partialName,
        date: date,
        title: title,
      ).toFirestore());
    }
    await batch.commit();
  }

  // Actualizar si el alumno completó la actividad
  Future<void> updateActivity(
      String groupId, ActivityModel activity) async {
    await _activities(groupId)
        .doc(activity.id)
        .update(activity.toFirestore());
  }

  Future<void> deleteActivity(
      String groupId, String activityId) async {
    await _activities(groupId).doc(activityId).delete();
  }
  // Marcar TODOS los alumnos como completados en una actividad
Future<void> markAllCompleted(
    String groupId, String activityTitle, bool completed) async {
  final snap = await _activities(groupId)
      .where('title', isEqualTo: activityTitle)
      .get();

  final batch = _db.batch();
  for (final doc in snap.docs) {
    batch.update(doc.reference, {'completed': completed});
  }
  await batch.commit();
}
}
