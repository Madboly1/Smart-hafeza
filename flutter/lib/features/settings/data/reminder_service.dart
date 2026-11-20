import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ReminderSettings {
  const ReminderSettings(
      {this.enabled = false, this.days = 3, this.permission = false});
  final bool enabled;
  final int days;
  final bool permission;
  factory ReminderSettings.fromMap(Map<Object?, Object?>? value) =>
      ReminderSettings(
          enabled: value?['enabled'] == true,
          days:
              value?['days'] is int ? (value!['days'] as int).clamp(1, 30) : 3,
          permission: value?['permission'] == true);
}

class ReminderService {
  static const channel = MethodChannel('bouga/reminders');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<ReminderSettings> read() => _call('state');
  Future<ReminderSettings> initialize() => _call('initialize');
  Future<ReminderSettings> save({required bool enabled, required int days}) {
    if (![1, 2, 3, 7, 14, 30].contains(days)) throw ArgumentError.value(days);
    return _call('set', {'enabled': enabled, 'days': days});
  }

  Future<ReminderSettings> _call(String method,
      [Map<String, Object>? args]) async {
    if (!supported) return const ReminderSettings();
    final value = await channel.invokeMapMethod<Object?, Object?>(method, args);
    return ReminderSettings.fromMap(value);
  }
}
