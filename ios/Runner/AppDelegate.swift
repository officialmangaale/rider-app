import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var mapsReady = false
  private var mapsAttempted = false
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "MangaaleMapsConfiguration") {
      let channel = FlutterMethodChannel(name: "com.mangaale/maps_configuration", binaryMessenger: registrar.messenger())
      channel.setMethodCallHandler { [weak self] call, result in
        guard call.method == "initialize" else { result(FlutterMethodNotImplemented); return }
        guard let args = call.arguments as? [String: Any], args["enabled"] as? Bool == true else { result(false); return }
        result(self?.initializeMaps() ?? false)
      }
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func initializeMaps() -> Bool {
    if mapsAttempted { return mapsReady }
    mapsAttempted = true
    let key = (Bundle.main.object(forInfoDictionaryKey: "MangaaleMapsAPIKey") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !key.isEmpty, !key.hasPrefix("$(") else {
      #if DEBUG
      NSLog("[Maps] iOS map capability unavailable: IOS_MAPS_API_KEY is not configured")
      #endif
      return false
    }
    mapsReady = GMSServices.provideAPIKey(key)
    return mapsReady
  }
}
