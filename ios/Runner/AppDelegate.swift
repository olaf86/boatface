import AdSupport
import AppTrackingTransparency
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let trackingTransparencyChannelName =
    "dev.asobo.boatface/tracking_transparency"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let channel = FlutterMethodChannel(
      name: trackingTransparencyChannelName,
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handleTrackingTransparency(call: call, result: result)
    }
  }

  private func handleTrackingTransparency(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getTrackingInfo":
      result(currentTrackingInfo())
    case "requestTrackingAuthorization":
      requestTrackingAuthorization(result: result)
    case "openAppSettings":
      openAppSettings(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestTrackingAuthorization(result: @escaping FlutterResult) {
    guard #available(iOS 14, *) else {
      result(currentTrackingInfo())
      return
    }

    ATTrackingManager.requestTrackingAuthorization { [weak self] _ in
      DispatchQueue.main.async {
        result(self?.currentTrackingInfo())
      }
    }
  }

  private func openAppSettings(result: @escaping FlutterResult) {
    guard let url = URL(string: UIApplication.openSettingsURLString) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { success in
      result(success)
    }
  }

  private func currentTrackingInfo() -> [String: Any?] {
    let status: String
    if #available(iOS 14, *) {
      switch ATTrackingManager.trackingAuthorizationStatus {
      case .notDetermined:
        status = "notDetermined"
      case .restricted:
        status = "restricted"
      case .denied:
        status = "denied"
      case .authorized:
        status = "authorized"
      @unknown default:
        status = "notSupported"
      }
    } else {
      status = "notSupported"
    }

    return [
      "status": status,
      "idfa": currentIdfa()
    ]
  }

  private func currentIdfa() -> String? {
    let identifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    if identifier == "00000000-0000-0000-0000-000000000000" {
      return nil
    }
    return identifier
  }
}
