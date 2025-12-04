import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // ใช้ 'app_icon' ซึ่งเป็นชื่อ default ที่ Flutter สร้างให้ใน mipmap
    // เปลี่ยนจาก 'app_icon' เป็น 'ic_launcher' ซึ่งเป็นชื่อไอคอนเริ่มต้นของ Flutter
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_launcher');

    // สำหรับ iOS (ยังไม่มีการตั้งค่าพิเศษ)
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
        InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _plugin.initialize(initializationSettings);

    // ขออนุญาตแสดง Notification บน Android (ตั้งแต่ API 33+)
    _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  Future<void> showBackupReminderNotification({required int days}) async {
    const AndroidNotificationDetails androidNotificationDetails =
        AndroidNotificationDetails(
      'backup_reminder_channel',
      'Backup Reminders',
      channelDescription: 'Channel for database backup reminders',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidNotificationDetails);

    await _plugin.show(
        0,
        'แจ้งเตือนการสำรองข้อมูล',
        'คุณยังไม่ได้สำรองข้อมูลมานานกว่า $days วันแล้ว แนะนำให้สำรองข้อมูลเพื่อความปลอดภัย',
        notificationDetails);
  }
}

final notificationServiceProvider = Provider((ref) => NotificationService());
