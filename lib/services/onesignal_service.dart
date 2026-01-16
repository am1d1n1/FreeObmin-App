import 'package:onesignal_flutter/onesignal_flutter.dart';

Future<void> initOneSignal(String appId) async {
  if (appId.isEmpty) return;
  OneSignal.initialize(appId);
  await OneSignal.Notifications.requestPermission(true);
}
