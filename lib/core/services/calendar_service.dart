import 'package:device_calendar/device_calendar.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../data/models/note.dart';
import '../utils/note_deep_links.dart';

final calendarServiceProvider = Provider((_) => CalendarService());

class CalendarSyncResult {
  final String calendarId;
  final String eventId;

  const CalendarSyncResult({required this.calendarId, required this.eventId});
}

class CalendarPermissionDeniedException implements Exception {
  @override
  String toString() =>
      'Нет доступа к системному календарю. '
      'На Android откройте: Настройки -> Приложения -> Flutter Application 2 -> '
      'Разрешения -> Календарь -> Разрешить. '
      'Если разрешение не появляется, переустановите приложение и попробуйте снова.';
}

class CalendarUnavailableException implements Exception {
  final String message;

  const CalendarUnavailableException(this.message);

  @override
  String toString() => message;
}

class CalendarService {
  CalendarService() : _plugin = DeviceCalendarPlugin();

  final DeviceCalendarPlugin _plugin;

  Future<CalendarSyncResult> upsertNoteEvent(Note note) async {
    final eventAt = note.eventAt;
    if (eventAt == null) {
      throw const CalendarUnavailableException('У заметки не выбрано время.');
    }

    await _ensurePermissions();
    final calendar = await _resolveCalendar(note.calendarId);
    final location = await _resolveTimeZone();
    final start = tz.TZDateTime.from(eventAt, location);
    final end = start.add(const Duration(minutes: 30));

    final event = Event(
      calendar.id,
      eventId: note.calendarEventId,
      title: note.title.trim().isNotEmpty ? note.title.trim() : 'Заметка',
      description: _buildDescription(note),
      start: start,
      end: end,
      reminders: [Reminder(minutes: note.reminderMinutes ?? 10)],
      url: buildNoteDeepLink(note.id),
    );

    final result = await _plugin.createOrUpdateEvent(event);
    if (result == null || !result.isSuccess || result.data == null) {
      final errorMessage = result != null && result.errors.isNotEmpty
          ? result.errors.first.errorMessage
          : 'Не удалось создать событие в календаре.';
      throw CalendarUnavailableException(errorMessage);
    }

    return CalendarSyncResult(calendarId: calendar.id!, eventId: result.data!);
  }

  Future<void> deleteNoteEvent(Note note) async {
    if ((note.calendarId?.isEmpty ?? true) ||
        (note.calendarEventId?.isEmpty ?? true)) {
      return;
    }

    await _ensurePermissions();
    final result = await _plugin.deleteEvent(
      note.calendarId,
      note.calendarEventId,
    );
    if (!result.isSuccess) {
      final errorMessage = result.errors.isNotEmpty
          ? result.errors.first.errorMessage
          : 'Не удалось удалить событие из календаря.';
      throw CalendarUnavailableException(errorMessage);
    }
  }

  Future<void> _ensurePermissions() async {
    final current = await _plugin.hasPermissions();
    final hasAccess = current.data ?? false;
    if (hasAccess) return;

    final requested = await _plugin.requestPermissions();
    if (!(requested.data ?? false)) {
      throw CalendarPermissionDeniedException();
    }
  }

  Future<Calendar> _resolveCalendar(String? preferredCalendarId) async {
    final calendarsResult = await _plugin.retrieveCalendars();
    final calendars =
        calendarsResult.data
            ?.where(
              (calendar) =>
                  calendar.isReadOnly != true &&
                  (calendar.id?.isNotEmpty ?? false),
            )
            .toList() ??
        const <Calendar>[];

    if (calendars.isEmpty) {
      throw const CalendarUnavailableException(
        'На устройстве не найден доступный календарь для записи.',
      );
    }

    for (final calendar in calendars) {
      if (calendar.id == preferredCalendarId) return calendar;
    }

    final defaultCalendar = calendars.cast<Calendar?>().firstWhere(
      (calendar) => calendar?.isDefault == true,
      orElse: () => null,
    );
    return defaultCalendar ?? calendars.first;
  }

  Future<tz.Location> _resolveTimeZone() async {
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      return tz.getLocation(timezoneInfo.identifier);
    } catch (_) {
      return tz.local;
    }
  }

  String _buildDescription(Note note) {
    final parts = <String>[];

    if (note.content.trim().isNotEmpty) {
      parts.add(note.content.trim());
    }

    if (note.tags.isNotEmpty) {
      parts.add('Теги: ${note.tags.join(', ')}');
    }

    return parts.join('\n\n');
  }
}
