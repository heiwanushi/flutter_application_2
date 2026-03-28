import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

import '../../data/models/note.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider((_) => NotificationService());

class NotificationService {
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        // Handle notification tap if needed
      },
    );

    if (Platform.isAndroid) {
      await _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }

  Future<void> scheduleNoteNotification(Note note) async {
    if (note.eventAt == null || note.isCompleted || note.isDeleted) {
      await cancelNoteNotification(note.id);
      return;
    }

    final reminderTime = note.eventAt!.subtract(
      Duration(minutes: note.reminderMinutes ?? 10),
    );

    if (reminderTime.isBefore(DateTime.now()) && note.repeatMode == NoteRepeatMode.none) {
      return;
    }

    final scheduledDate = tz.TZDateTime.from(reminderTime, tz.local);

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'notes_reminders',
      'Напоминания о заметках',
      channelDescription: 'Уведомления о событиях в ваших заметках',
      importance: Importance.max,
      priority: Priority.high,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    if (note.repeatMode == NoteRepeatMode.none) {
      await _notifications.zonedSchedule(
        note.notificationId,
        note.title.isEmpty ? 'Напоминание' : note.title,
        note.content.isEmpty ? 'Посмотрите вашу заметку' : note.content,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } else {
      await _notifications.zonedSchedule(
        note.notificationId,
        note.title.isEmpty ? 'Напоминание' : note.title,
        note.content.isEmpty ? 'Посмотрите вашу заметку' : note.content,
        scheduledDate,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: _getMatchComponents(note.repeatMode),
      );
    }
  }

  DateTimeComponents? _getMatchComponents(NoteRepeatMode mode) {
    return switch (mode) {
      NoteRepeatMode.none => null,
      NoteRepeatMode.daily => DateTimeComponents.time,
      NoteRepeatMode.weekly => DateTimeComponents.dayOfWeekAndTime,
      NoteRepeatMode.monthly => DateTimeComponents.dayOfMonthAndTime,
      NoteRepeatMode.yearly => DateTimeComponents.dateAndTime,
    };
  }

  Future<void> cancelNoteNotification(String noteId) async {
    // We use the absolute value of hashcode as ID
    await _notifications.cancel(noteId.hashCode.abs());
  }
}
