import '../../onboarding/presentation/bouga_tour.dart';
import '../../settings/data/reminder_service.dart';

/// Captures and restores the small user settings that belong in a full app
/// backup: reminder preferences and the onboarding-tour marker.
class BougaBackupSettings {
  static Future<Map<String, Object?>> capture({
    ReminderService? reminders,
    BougaTourStore? tourStore,
  }) async {
    final reminderService = reminders ?? ReminderService();
    final store = tourStore ?? BougaTourStore();
    ReminderSettings reminder = const ReminderSettings();
    try {
      reminder = await reminderService.read();
    } catch (_) {
      // Keep defaults when the native side is unavailable.
    }
    var tourSeen = false;
    try {
      tourSeen = await store.seen;
    } catch (_) {}
    return <String, Object?>{
      'reminders': <String, Object?>{
        'enabled': reminder.enabled,
        'days': reminder.days,
      },
      'tourSeen': tourSeen,
    };
  }

  static Future<void> apply(
    Map<String, dynamic> settings, {
    ReminderService? reminders,
    BougaTourStore? tourStore,
  }) async {
    final reminderService = reminders ?? ReminderService();
    final store = tourStore ?? BougaTourStore();
    final reminder = settings['reminders'];
    if (reminder is Map && reminderService.supported) {
      final days = reminder['days'];
      try {
        await reminderService.save(
          enabled: reminder['enabled'] == true,
          days: days is int ? days : 3,
        );
      } catch (_) {}
    }
    if (settings['tourSeen'] == true) {
      try {
        await store.complete();
      } catch (_) {}
    }
  }
}
