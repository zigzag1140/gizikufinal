import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> createUserWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error Saat Daftar:");
      print("Kode Error: ${e.code}");
      print("Pesan Error: ${e.message}");
      return null;
    } catch (e) {
      print("Error Umum Saat Daftar: ${e.toString()}");
      return null;
    }
  }

  Future<User?> signInWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      print("Firebase Auth Error Saat Login:");
      print("Kode Error: ${e.code}");
      print("Pesan Error: ${e.message}");
      return null;
    } catch (e) {
      print("Error Umum Saat Login: ${e.toString()}");
      return null;
    }
  }
}
