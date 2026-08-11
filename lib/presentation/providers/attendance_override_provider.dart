import 'package:flutter_riverpod/flutter_riverpod.dart';

// Guarda overrides de asistencia: key = 'groupId_partialId_studentId' → count
final attendanceOverrideProvider =
    StateNotifierProvider<AttendanceOverrideNotifier, Map<String, int>>(
  (ref) => AttendanceOverrideNotifier(),
);

class AttendanceOverrideNotifier extends StateNotifier<Map<String, int>> {
  AttendanceOverrideNotifier() : super({});

  void setOverride(String key, int value) {
    state = {...state, key: value};
  }

  void removeOverride(String key) {
    final newState = Map<String, int>.from(state);
    newState.remove(key);
    state = newState;
  }

  int? getOverride(String key) => state[key];
}