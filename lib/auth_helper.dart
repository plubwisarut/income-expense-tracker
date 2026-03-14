import 'package:firebase_auth/firebase_auth.dart';

class AuthHelper {
  static String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('User not logged in');
    return user.uid;
  }
}