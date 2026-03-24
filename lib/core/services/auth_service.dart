import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Для debugPrint

final authServiceProvider = Provider((ref) => AuthService());

// Провайдер для слежения за пользователем
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Создаем экземпляр GoogleSignIn (без параметров для стандартного использования)
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Стрим для отслеживания входа/выхода
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Метод входа
  Future<void> signInWithGoogle() async {
    try {
      // 1. Начинаем процесс выбора аккаунта
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      // Если пользователь закрыл окно выбора — выходим
      if (googleUser == null) return;

      // 2. Получаем данные аутентификации (токены)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Создаем учетные данные для Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Входим в Firebase под этим пользователем
      await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Ошибка Google Sign-In: $e");
    }
  }

  // Метод выхода
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint("Ошибка при выходе: $e");
    }
  }
}