import Flutter
import UIKit
import FirebaseCore
import FirebaseInstallations

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Before ML Kit / camera — satisfies CCTPolicyVending_API on iOS.
    if FirebaseApp.app() == nil {
      FirebaseApp.configure()
    }
    _ = Installations.installations()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
