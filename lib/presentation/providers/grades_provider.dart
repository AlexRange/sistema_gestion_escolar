import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/grade_repository.dart';
import '../../data/models/grade_model.dart';
import 'auth_provider.dart';

final gradeRepositoryProvider = Provider<GradeRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? GradeRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final gradesProvider =
    StreamProvider.family<List<GradeModel>, String>((ref, groupId) {
  final repo = ref.watch(gradeRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchGrades(groupId);
});
