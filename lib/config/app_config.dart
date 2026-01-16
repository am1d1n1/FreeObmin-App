import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static String get oneSignalAppId =>
      dotenv.env['ONE_SIGNAL_APP_ID'] ?? '';
  static String get pushServerUrl =>
      dotenv.env['PUSH_SERVER_URL'] ?? '';
  static String get cloudinaryCloudName =>
      dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get cloudinaryUploadPreset =>
      dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String get githubUpdateOwner =>
      dotenv.env['GITHUB_UPDATE_OWNER'] ?? '';
  static String get githubUpdateRepo => dotenv.env['GITHUB_UPDATE_REPO'] ?? '';

  static FirebaseOptions get firebaseOptions => FirebaseOptions(
        apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
        appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
        messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
        projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
        storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
      );
}
