import Flutter
import UIKit

/// Error codes shared with Dart (VoicePlatformErrorCode) and Kotlin.
enum PlatformErrorCode {
  /// Scheduled for a later phase.
  static let notImplemented = "not_implemented"
  /// iOS cannot offer this feature at all.
  static let unsupported = "unsupported"
}

/// iOS implementation of the Pigeon host API (phase 0 stub).
///
/// iPhones join rooms as clients only (phase 7); they never host, cannot open
/// hotspot settings and have no battery optimization exemption.
final class IosVoicePlatformApi: VoicePlatformHostApi {
  static let capabilities = PlatformCapabilitiesMessage(
    canHostRoom: false,
    supportsGatewayDiscovery: false,
    supportsHotspotSettings: false,
    supportsBatteryExemption: false
  )

  func getPlatformInfo() throws -> PlatformInfoMessage {
    let device = UIDevice.current
    return PlatformInfoMessage(
      osName: "ios",
      osVersion: device.systemVersion,
      apiLevel: Int64(ProcessInfo.processInfo.operatingSystemVersion.majorVersion),
      manufacturer: "Apple",
      model: device.model,
      capabilities: Self.capabilities
    )
  }

  func startRoom(config: RoomConfigMessage) async throws {
    throw notImplemented("startRoom")
  }

  func stopRoom() async throws {
    throw notImplemented("stopRoom")
  }

  func setMute(muted: Bool) throws {
    throw notImplemented("setMute")
  }

  func openHotspotSettings() throws {
    throw unsupported("openHotspotSettings")
  }

  func requestBatteryExemption() async throws -> Bool {
    throw unsupported("requestBatteryExemption")
  }

  func setKeepScreenOn(enabled: Bool) throws {
    DispatchQueue.main.async {
      UIApplication.shared.isIdleTimerDisabled = enabled
    }
  }

  /// No room can be running before the iOS client exists (phase 7).
  func getActiveRoom() throws -> ActiveRoomMessage? {
    return nil
  }

  private func notImplemented(_ method: String) -> PigeonError {
    PigeonError(
      code: PlatformErrorCode.notImplemented,
      message: "\(method) is not implemented yet on iOS.",
      details: nil
    )
  }

  private func unsupported(_ method: String) -> PigeonError {
    PigeonError(
      code: PlatformErrorCode.unsupported,
      message: "\(method) is not available on iOS.",
      details: nil
    )
  }
}

/// Emits the idle state to every new listener (no room service on iOS yet).
final class IdlePlatformStateStreamHandler: WatchPlatformStateStreamHandler {
  override func onListen(
    withArguments arguments: Any?,
    sink: PigeonEventSink<PlatformStateMessage>
  ) {
    sink.success(
      PlatformStateMessage(serviceRunning: false, audioRoute: .unknown, wifiState: .unknown)
    )
  }
}
