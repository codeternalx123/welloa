import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/error/failures.dart';

abstract class AuthRemoteDataSource {
  Future<User> signInWithEmailAndPassword(String email, String password);
  Future<User> registerWithEmailAndPassword(String email, String password);
  Future<void> signOut();
  Future<User?> getCurrentUser();
  Stream<User?> get authStateChanges;
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth firebaseAuth;

  AuthRemoteDataSourceImpl({FirebaseAuth? auth})
      : firebaseAuth = auth ?? FirebaseAuth.instance;

  @override
  Stream<User?> get authStateChanges => firebaseAuth.authStateChanges();

  @override
  Future<User?> getCurrentUser() async {
    return firebaseAuth.currentUser;
  }

  @override
  Future<User> registerWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        return credential.user!;
      } else {
        throw const ServerFailure('Registration failed: No user returned.');
      }
    } on FirebaseAuthException catch (e) {
      throw ServerFailure('Auth Error: \${e.message}');
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: \$e');
    }
  }

  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final credential = await firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (credential.user != null) {
        // Here we could implement session timeout logic or custom token generation
        // for enterprise grade security.
        return credential.user!;
      } else {
        throw const ServerFailure('Sign in failed: No user returned.');
      }
    } on FirebaseAuthException catch (e) {
      throw ServerFailure('Auth Error: \${e.message}');
    } catch (e) {
      throw ServerFailure('An unexpected error occurred: \$e');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await firebaseAuth.signOut();
    } catch (e) {
      throw ServerFailure('Failed to sign out: \$e');
    }
  }
}
