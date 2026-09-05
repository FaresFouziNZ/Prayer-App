import 'package:do_not_disturb/do_not_disturb_plugin.dart';
import 'package:do_not_disturb/types.dart';

/// Wraps the `do_not_disturb` plugin for FR-NT-08 (Android-only optional DND
/// during prayer). Automatically enabling DND exactly at iqamah time needs a
/// background task scheduler (e.g. `android_alarm_manager_plus`) beyond this
/// pass's scope — this wraps the permission and the manual toggle only.
class DndService {
  final _plugin = DoNotDisturbPlugin();

  Future<bool> isPermissionGranted() => _plugin.isNotificationPolicyAccessGranted();

  Future<void> openPermissionSettings() => _plugin.openNotificationPolicyAccessSettings();

  Future<void> enablePriorityOnly() =>
      _plugin.setInterruptionFilter(InterruptionFilter.priority);

  Future<void> disable() => _plugin.setInterruptionFilter(InterruptionFilter.all);
}
