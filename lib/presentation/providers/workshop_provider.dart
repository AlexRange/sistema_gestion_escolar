import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/workshop_repository.dart';
import '../../data/models/workshop_model.dart';
import 'auth_provider.dart';

final workshopRepositoryProvider = Provider<WorkshopRepository?>((ref) {
  final userAsync = ref.watch(authStateProvider);
  return userAsync.maybeWhen(
    data: (user) =>
        user != null ? WorkshopRepository(userId: user.uid) : null,
    orElse: () => null,
  );
});

final workshopsProvider = StreamProvider<List<WorkshopModel>>((ref) {
  final repo = ref.watch(workshopRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchWorkshops();
});
