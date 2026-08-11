import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel> signIn(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final doc = await _db
        .collection('users')
        .doc(cred.user!.uid)
        .get();
    return UserModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<UserModel> register(
    String email, String password, String displayName, String? school) async {
  final cred = await _auth.createUserWithEmailAndPassword(
    email: email.trim(),
    password: password.trim(),
  );

  // Enviar email de verificación
  await cred.user!.sendEmailVerification();

  // Actualizar displayName en Firebase Auth
  await cred.user!.updateDisplayName(displayName.trim());

  final user = UserModel(
    uid: cred.user!.uid,
    email: email.trim(),
    displayName: displayName.trim(),
    schoolName: school?.trim(),
    createdAt: DateTime.now(),
  );
  await _db.collection('users').doc(user.uid).set(user.toFirestore());
  return user;
}

// Verificar si el email está confirmado
bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

Future<void> reloadUser() => _auth.currentUser!.reload();

  Future<void> signOut() => _auth.signOut();

  Future<void> resetPassword(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());
}
