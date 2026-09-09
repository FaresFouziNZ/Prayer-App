import Flutter
import UIKit

/// Hosts the `live_activity` method channel (SRS FR-LA-01's "Buttons" row):
/// drains prayer-log actions tapped on the Live Activity while this app
/// wasn't running to receive them directly. See
/// `ios/PrayerLiveActivity/PendingLiveActivityLogs.swift` (shared with the
/// PrayerLiveActivity widget extension target, the writer of that queue)
/// and `lib/platform/live_activity/pending_live_activity_logs.dart` (the
/// Dart-side reader, which applies each entry through the app's ordinary
/// logging path).
@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // `registrar(forPlugin:)` is inherited from `FlutterPluginRegistry`
    // regardless of which engine-bootstrap API this template uses — the
    // stable, long-standing way to get a `FlutterBinaryMessenger` for a
    // channel that isn't a full plugin. (If this project's Flutter version
    // exposes a messenger directly on `engineBridge`, that'd work too and
    // is arguably more in the spirit of the newer API — this just doesn't
    // assume a specific property name on a bridge type this comment can't
    // verify against what's actually installed.)
    guard let messenger = self.registrar(forPlugin: "LiveActivityChannel")?.messenger() else {
      return
    }
    let channel = FlutterMethodChannel(name: "live_activity", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "drainPendingLogs":
        result(PendingLiveActivityLogs.drain())
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
