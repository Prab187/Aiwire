import Flutter
import UIKit
import ObjectiveC

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Disable Flutter's touch rate correction VSyncClient to prevent crash on iOS 26
    // with ProMotion displays. This is a workaround for a Flutter beta engine bug where
    // the VSyncClient init reads a null callback pointer on 120Hz displays.
    disableTouchRateCorrection()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// Swizzle FlutterViewController's createTouchRateCorrectionVSyncClientIfNeeded
  /// method to be a no-op, avoiding the iOS 26 ProMotion crash.
  private func disableTouchRateCorrection() {
    let cls: AnyClass = FlutterViewController.self
    let selector = NSSelectorFromString("createTouchRateCorrectionVSyncClientIfNeeded")
    guard let originalMethod = class_getInstanceMethod(cls, selector) else { return }

    let block: @convention(block) (AnyObject) -> Void = { _ in
      // No-op — skip VSyncClient creation entirely
    }
    let impl = imp_implementationWithBlock(block)
    method_setImplementation(originalMethod, impl)
  }
}
