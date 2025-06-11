import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

enum UserRole { supervisor, agent }

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  User? _user;
  bool _isLoading = false;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      notifyListeners();
    });
    // Ensure no pre-sign in by signing out on initialization
    _auth.signOut();
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signUpWithEmailAndPassword(
    String email,
    String password,
    UserRole role,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await userCredential.user?.sendEmailVerification();

      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email,
        'role': role.toString().split('.').last,
        'createdAt': FieldValue.serverTimestamp(),
        'isEmailVerified': false,
      });

      _isLoading = false;
      notifyListeners();
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  Future<UserCredential> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      _isLoading = true;
      notifyListeners();
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!userCredential.user!.emailVerified) {
        await _auth.signOut();
        throw Exception('Please verify your email before signing in');
      }

      // Get user role from Firestore
      final userDoc = await _firestore.collection('users').doc(userCredential.user?.uid).get();
      if (!userDoc.exists) {
        await _auth.signOut();
        throw Exception('User data not found');
      }

      final userRole = userDoc.get('role') as String;
      if (userRole != 'supervisor' && userRole != 'agent') {
        await _auth.signOut();
        throw Exception('Invalid user role');
      }

      await _firestore.collection('users').doc(userCredential.user?.uid).update({
        'isEmailVerified': true,
        'lastLogin': FieldValue.serverTimestamp(),
      });

      _isLoading = false;
      notifyListeners();
      return userCredential;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await GoogleSignIn().signOut(); // Also sign out from Google
      _user = null;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  Future<UserRole?> getUserRole() async {
    if (currentUser == null) return null;
    
    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    
    if (!doc.exists) return null;
    
    String role = doc.get('role') as String;
    return role == 'supervisor' ? UserRole.supervisor : UserRole.agent;
  }

  Future<void> resendVerificationEmail() async {
    if (currentUser != null && !currentUser!.emailVerified) {
      await currentUser!.sendEmailVerification();
    }
  }

  Future<UserCredential?> signInWithGoogle({UserRole? role}) async {
    try {
      _isLoading = true;
      notifyListeners();
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null; // User cancelled
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;
      if (user == null) throw Exception('Google sign-in failed');
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        // New user, must have role
        if (role == null) {
          await _auth.signOut();
          throw Exception('Role required for new Google user');
        }
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': role.toString().split('.').last,
          'createdAt': FieldValue.serverTimestamp(),
          'isEmailVerified': true,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login for existing user
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }
      _isLoading = false;
      notifyListeners();
      return userCredential;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }
} 