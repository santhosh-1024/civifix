import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<User?> authChanges() => _auth.authStateChanges();

  Future<AppUser?> getProfile(String uid) async {
    final doc = await _db.collection("users").doc(uid).get();
    if (!doc.exists) return null;
    return AppUser.fromMap(doc.data()!);
  }

  Future<void> createUserProfile(AppUser user) async {
    await _db.collection("users").doc(user.uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserCredential> registerEmail(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await createUserProfile(AppUser(uid: cred.user!.uid, email: email, name: name, role: "citizen"));
    return cred;
  }

  Future<UserCredential> loginEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async => _auth.signOut();

  Future<void> sendOtp({
    required String phone,
    required Function(String verificationId) onCodeSent,
    required Function(String message) onError,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) => onError(e.message ?? "Phone auth failed"),
      codeSent: (String verificationId, int? resendToken) => onCodeSent(verificationId),
      codeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  Future<UserCredential> verifyOtp(String verificationId, String otp) async {
    final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: otp);
    final userCred = await _auth.signInWithCredential(cred);

    await createUserProfile(
      AppUser(uid: userCred.user!.uid, phone: userCred.user!.phoneNumber, role: "citizen"),
    );

    return userCred;
  }
}
