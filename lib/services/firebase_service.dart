import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

enum FirebaseConnectionState { connecting, connected, disconnected }

class FirebaseService {
  static FirebaseConnectionState connectionState =
      FirebaseConnectionState.connecting;

  static FirebaseAuth? auth;
  static FirebaseFirestore? firestore;
  // Cloudinary is used for image uploads.

  static Future<void> initialize(FirebaseOptions options) async {
    try {
      connectionState = FirebaseConnectionState.connecting;
      print('?? Инициализация Firebase...');

      if (Firebase.apps.isEmpty) {
        try {
          await Firebase.initializeApp(options: options);
        } on FirebaseException catch (e) {
          if (e.code != 'duplicate-app') rethrow;
        }
      }

      // Инициализируем сервисы
      auth = FirebaseAuth.instance;
      firestore = FirebaseFirestore.instance;

      // Проверяем подключение
      print('?? Проверка подключения к Firestore...');
      try {
        await firestore!
            .collection('test_connection')
            .limit(1)
            .get()
            .timeout(const Duration(seconds: 10));

        connectionState = FirebaseConnectionState.connected;
        print('? Firebase успешно инициализирован');
      } on TimeoutException {
        print('? Таймаут подключения к Firestore');
        connectionState = FirebaseConnectionState.disconnected;
      } catch (e) {
        print('?? Предупреждение при проверке подключения: $e');
        connectionState = FirebaseConnectionState.connected;
      }
    } catch (e) {
      print('? Критическая помилка инициализации Firebase: $e');
      connectionState = FirebaseConnectionState.disconnected;
    }
  }
}
