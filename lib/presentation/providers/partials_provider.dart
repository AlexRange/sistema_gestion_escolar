import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/partial_repository.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/evaluation_repository.dart';
import '../../data/models/partial_model.dart';
import '../../data/models/activity_model.dart';
import '../../data/models/evaluation_model.dart';
import 'auth_provider.dart';

final partialRepositoryProvider = Provider<PartialRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? PartialRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final activityRepositoryProvider = Provider<ActivityRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? ActivityRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final evaluationRepositoryProvider = Provider<EvaluationRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? EvaluationRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final partialsProvider =
    StreamProvider.family<List<PartialModel>, String>((ref, groupId) {
  final repo = ref.watch(partialRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchPartials(groupId);
});

final activitiesProvider = StreamProvider.family<List<ActivityModel>,
    ({String groupId, String partialName})>((ref, params) {
  final repo = ref.watch(activityRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchActivities(params.groupId, params.partialName);
});

final evaluationsProvider = StreamProvider.family<List<EvaluationModel>,
    ({String groupId, String partialName})>((ref, params) {
  final repo = ref.watch(evaluationRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchEvaluations(params.groupId, params.partialName);
});
