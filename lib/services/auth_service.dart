import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  Future<bool> signUp(String email, String password) async {
    try {
      // Create user with Firebase Authentication
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If the user is created successfully, save their data to Firestore
      if (userCredential.user != null) {
        final String uid = userCredential.user!.uid;  // Get the unique UID

        // You can store additional user details in Firestore if needed
        await _firestore.collection('user').doc(uid).set({
          'uid': uid,  // Explicitly storing the UID
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });

        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('Error during sign up: $e');
      return false;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user != null;
    } catch (e) {
      print('Error during sign in: $e');
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error during sign out: $e');
    }
  }

  Future<bool> isLoggedIn() async {
    final User? user = _auth.currentUser;
    return user != null;
  }

  String? getCurrentUserEmail() {
    final User? user = _auth.currentUser;
    return user?.email;
  }
}
