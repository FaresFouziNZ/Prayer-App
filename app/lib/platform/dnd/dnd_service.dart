import 'package:do_not_disturb/do_not_disturb_plugin.dart';
import 'package:do_not_disturb/types.dart';

/// Wraps the `do_not_disturb` plugin for FR-NT-08 (Android-only optional DND
/// during prayer): the permission check/request, the manual toggle in
/// Settings, and the actual enable/disable calls that [DndAlarmScheduler]
/// runs automatically at iqamah and iqamah+duration.
class DndService {
  final _plugin = DoNotDisturbPlugin();

  Future<bool> isPermissionGranted() =>
      _plugin.isNotificationPolicyAccessGranted();

  Future<void> openPermissionSettings() =>
      _plugin.openNotificationPolicyAccessSettings();

  Future<void> enablePriorityOnly() =>
      _plugin.setInterruptionFilter(InterruptionFilter.priority);

  Future<void> disable() =>
      _plugin.setInterruptionFilter(InterruptionFilter.all);
}
