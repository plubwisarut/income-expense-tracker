import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_helper.dart';

// ─────────────────────────────────────────────
//  NotificationService
//  ใช้ flutter_local_notifications + timezone
//
//  pubspec.yaml ต้องมี:
//    flutter_local_notifications: ^17.0.0
//    timezone: ^0.9.0
//
//  AndroidManifest.xml ต้องมี (ใน <manifest>):
//    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//
//  ใน <application>:
//    <receiver android:exported="false"
//       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"/>
//    <receiver android:exported="false"
//       android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
//      <intent-filter>
//        <action android:name="android.intent.action.BOOT_COMPLETED"/>
//        <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
//      </intent-filter>
//    </receiver>
// ─────────────────────────────────────────────

// ── Notification ID constants (ไม่ซ้ำกัน) ──
class NotifId {
  static const int budgetWarning    = 1001; // งบใกล้หมด
  static const int budgetOverrun    = 1002; // งบหมดแล้ว
  static const int questReminder    = 2001; // quest รายวัน
  static const int habitReminder    = 2002; // habit streak
  static const int repeatTx         = 3001; // repeat transaction base (3001+i)
  static const int dailySummary     = 4001; // สรุปรายวัน
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  // ── Channel definitions ──
  static const _channelBudget = AndroidNotificationChannel(
    'budget_channel_v2', 'งบประมาณ',
    description: 'แจ้งเตือนเมื่องบประมาณใกล้หมดหรือเกิน',
    importance: Importance.defaultImportance,
  );
  static const _channelQuest = AndroidNotificationChannel(
    'quest_channel', 'ภารกิจ',
    description: 'แจ้งเตือนภารกิจประจำวันและ habit streak',
    importance: Importance.defaultImportance,
  );
  static const _channelRepeat = AndroidNotificationChannel(
    'repeat_channel', 'รายการซ้ำ',
    description: 'แจ้งเตือนรายการซ้ำที่ถึงกำหนด',
    importance: Importance.defaultImportance,
  );
  static const _channelSummary = AndroidNotificationChannel(
    'summary_channel', 'สรุปรายวัน',
    description: 'สรุปรายรับรายจ่ายประจำวัน',
    importance: Importance.low,
  );

  // ────────────────────────────────────────────
  //  init — เรียกครั้งเดียวตอน app start ใน main.dart
  // ────────────────────────────────────────────
  static Future<void> init() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Bangkok'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // สร้าง channels
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelBudget);
    await androidPlugin?.createNotificationChannel(_channelQuest);
    await androidPlugin?.createNotificationChannel(_channelRepeat);
    await androidPlugin?.createNotificationChannel(_channelSummary);

    // ขอ permission (Android 13+)
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) {
    // handle deep link ถ้าต้องการในอนาคต
  }

  // ────────────────────────────────────────────
  //  1. แจ้งเตือนงบประมาณ (เรียกหลัง saveTransaction)
  //     - เรียกใน doscreen.dart → _saveTransaction()
  // ────────────────────────────────────────────
  static Future<void> checkAndNotifyBudget({
    required int remaining,
    required int budgetAmount,
    required String walletName,
  }) async {
    if (budgetAmount <= 0) return;
    final progress = remaining / budgetAmount;

    if (remaining < 0) {
      // เกินงบแล้ว
      await _showImmediate(
        id: NotifId.budgetOverrun,
        title: '⚠️ ใช้เกินงบแล้ว! ($walletName)',
        body: 'คุณใช้เกินงบไป ฿${remaining.abs()} กรุณาตรวจสอบรายจ่าย',
        channel: _channelBudget,
      );
    } else if (progress <= 0.25) {
      // เหลือน้อยกว่า 25%
      await _showImmediate(
        id: NotifId.budgetWarning,
        title: '🔔 งบประมาณใกล้หมดแล้ว ($walletName)',
        body: 'เหลืออีกแค่ ฿$remaining จาก ฿$budgetAmount (${(progress * 100).toInt()}%)',
        channel: _channelBudget,
      );
    }
  }

  // ────────────────────────────────────────────
  //  2. แจ้งเตือน Quest รายวัน — schedule เวลา 20:00 ทุกวัน
  //     - เรียกใน main.dart หรือ goalprogress.dart ตอน activate quest
  // ────────────────────────────────────────────
  static Future<void> scheduleDailyQuestReminder() async {
    await _plugin.cancel(NotifId.questReminder);
    await _scheduleDaily(
      id: NotifId.questReminder,
      hour: 20,
      minute: 0,
      title: '🎯 อย่าลืมภารกิจวันนี้!',
      body: 'เปิดแอปดูภารกิจงดรายจ่ายและ habit streak ของคุณ',
      channel: _channelQuest,
    );
  }

  // ────────────────────────────────────────────
  //  3. แจ้งเตือน Habit Quest streak
  //     - เรียกหลัง checkHabitQuests ใน doscreen.dart
  // ────────────────────────────────────────────
  static Future<void> notifyHabitStreak({required int streak}) async {
    if (streak < 2) return; // แจ้งตั้งแต่วันที่ 2 ขึ้นไป
    String emoji = streak >= 7 ? '🔥🔥🔥' : streak >= 5 ? '🔥🔥' : '🔥';
    await _showImmediate(
      id: NotifId.habitReminder,
      title: '$emoji บันทึกต่อเนื่อง $streak วันแล้ว!',
      body: streak >= 7
          ? 'ยอดเยี่ยม! ครบ 7 วันแล้ว ภารกิจ habit สำเร็จ!'
          : 'เหลืออีก ${7 - streak} วัน จะครบ 7 วัน สู้ๆ!',
      channel: _channelQuest,
    );
  }

  // ────────────────────────────────────────────
  //  4. แจ้งเตือน Repeat Transaction
  //     - schedule ล่วงหน้า 1 วัน เวลา 09:00
  //     - เรียกใน result.dart → _checkAndGenerateRepeatTransactions()
  // ────────────────────────────────────────────
  static Future<void> scheduleRepeatTransactionReminder({
    required int index,
    required String category,
    required int amount,
    required DateTime nextDate,
  }) async {
    final notifId = NotifId.repeatTx + index;
    final reminderDate = nextDate.subtract(const Duration(days: 1));
    if (reminderDate.isBefore(DateTime.now())) return;

    final scheduledTime = tz.TZDateTime(
      tz.local,
      reminderDate.year, reminderDate.month, reminderDate.day, 9, 0,
    );

    await _plugin.cancel(notifId);
    await _plugin.zonedSchedule(
      notifId,
      '📅 รายการซ้ำพรุ่งนี้: $category',
      'รายการ ฿$amount จะถูกบันทึกพรุ่งนี้ (${nextDate.day}/${nextDate.month}/${nextDate.year})',
      scheduledTime,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelRepeat.id, _channelRepeat.name,
          channelDescription: _channelRepeat.description,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ────────────────────────────────────────────
  //  5. สรุปรายวัน — schedule เวลา 21:00 ทุกวัน
  //     - เรียกครั้งเดียวใน main.dart
  // ────────────────────────────────────────────
  static Future<void> scheduleDailySummary() async {
    await _plugin.cancel(NotifId.dailySummary);
    await _scheduleDaily(
      id: NotifId.dailySummary,
      hour: 21,
      minute: 0,
      title: '📊 สรุปรายวัน',
      body: 'เปิดแอปดูสรุปรายรับรายจ่ายของวันนี้',
      channel: _channelSummary,
    );
  }

  // ────────────────────────────────────────────
  //  6. ยกเลิกทั้งหมด (เรียกตอน logout)
  // ────────────────────────────────────────────
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ────────────────────────────────────────────
  //  Private helpers
  // ────────────────────────────────────────────
  static Future<void> _showImmediate({
    required int id,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
  }) async {
    await _plugin.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required AndroidNotificationChannel channel,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await _plugin.zonedSchedule(
      id, title, body, scheduled,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id, channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // วนซ้ำทุกวัน
    );
  }
}