import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/models/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((_) => AuthRepository());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

// Notifier para login/registro
class AuthNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final AuthRepository _repo;

  AuthNotifier(this._repo) : super(const AsyncValue.data(null));

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.signIn(email, password),
    );
  }

  Future<void> register(
      String email, String password, String name, String? school) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => _repo.register(email, password, name, school),
    );
  }

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }

  Future<void> resetPassword(String email) =>
      _repo.resetPassword(email);
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<UserModel?>>(
  (ref) => AuthNotifier(ref.watch(authRepositoryProvider)),
);
