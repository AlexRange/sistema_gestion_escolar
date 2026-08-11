import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/models/group_model.dart';
import 'auth_provider.dart';

final groupRepositoryProvider = Provider<GroupRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? GroupRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final groupsProvider = StreamProvider<List<GroupModel>>((ref) {
  final repo = ref.watch(groupRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchGroups();
});