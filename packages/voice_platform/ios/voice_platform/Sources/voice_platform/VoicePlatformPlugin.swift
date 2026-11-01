import Flutter
import UIKit

/// Flutter entry point on iOS: wires the Pigeon channels to the iOS host.
///
/// Until phase 7 (iPhone as a client) the host only describes the device and
/// keeps the screen awake; room commands answer with an error code.
public class VoicePlatformPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    VoicePlatformHostApiSetup.setUp(binaryMessenger: messenger, api: IosVoicePlatformApi())
    WatchPlatformStateStreamHandler.register(
      with: messenger,
      streamHandler: IdlePlatformStateStreamHandler()
    )
  }
}
