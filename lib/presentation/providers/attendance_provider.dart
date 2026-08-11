import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/models/attendance_model.dart';
import 'auth_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? AttendanceRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final attendanceByDateProvider = StreamProvider.family<List<AttendanceModel>,
    ({String groupId, DateTime date})>((ref, params) {
  final repo = ref.watch(attendanceRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchAttendanceByDate(params.groupId, params.date);
});
