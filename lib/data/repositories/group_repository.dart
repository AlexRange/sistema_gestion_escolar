import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/group_model.dart';

class GroupRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String userId;

  GroupRepository({required this.userId});

  CollectionReference get _groups =>
      _db.collection('users').doc(userId).collection('groups');

  Stream<List<GroupModel>> watchGroups() {
    return _groups
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => GroupModel.fromFirestore(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addGroup(GroupModel group) async {
    await _groups.add(group.toFirestore());
  }

  Future<void> updateGroup(GroupModel group) async {
    await _groups.doc(group.id).update(group.toFirestore());
  }

  Future<void> deleteGroup(String groupId) async {
    await _groups.doc(groupId).delete();
  }
}
