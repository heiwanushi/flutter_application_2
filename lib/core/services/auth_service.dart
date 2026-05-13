import 'dart:developer' as dev;
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
      dev.log('AuthService: Начало входа через Google...');
      
      // Сброс текущей сессии Google перед входом (форсирует выбор аккаунта)
      await _googleSignIn.signOut();
      
      // 1. Начинаем процесс выбора аккаунта
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        dev.log('AuthService: Вход отменен пользователем');
        return;
      }
      dev.log('AuthService: Аккаунт выбран: ${googleUser.email}');

      // 2. Получаем данные аутентификации (токены)
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      dev.log('AuthService: Токены получены. idToken: ${googleAuth.idToken != null ? 'OK' : 'NULL'}, accessToken: ${googleAuth.accessToken != null ? 'OK' : 'NULL'}');

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Не удалось получить токены доступа (idToken/accessToken)');
      }

      // 3. Создаем учетные данные для Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Входим в Firebase под этим пользователем
      dev.log('AuthService: Вход в Firebase через учетные данные...');
      final userCredential = await _auth.signInWithCredential(credential);
      dev.log('AuthService: Вход в Firebase успешен: ${userCredential.user?.uid}');
    } catch (e, stack) {
      dev.log('AuthService: Ошибка Google Sign-In: $e', error: e, stackTrace: stack);
      rethrow;
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