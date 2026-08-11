import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/planner_repository.dart';
import '../../data/models/planner_model.dart';
import 'auth_provider.dart';

final plannerRepositoryProvider = Provider<PlannerRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? PlannerRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final plannerProvider = StreamProvider<List<PlannerModel>>((ref) {
  final repo = ref.watch(plannerRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchEntries();
});
