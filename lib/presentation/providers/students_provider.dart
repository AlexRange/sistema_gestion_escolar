import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/student_repository.dart';
import '../../data/models/student_model.dart';
import 'auth_provider.dart';

final studentRepositoryProvider = Provider<StudentRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? StudentRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final studentsProvider =
    StreamProvider.family<List<StudentModel>, String>((ref, groupId) {
  final repo = ref.watch(studentRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchStudents(groupId);
});
