import 'package:voice_core/src/voice_core_client.dart';
import 'package:voice_core/src/voice_core_exception.dart';

/// In-memory [VoiceCoreClient] for tests.
///
/// It honors the same contract as the FFI client (see
/// test/contracts/voice_core_client_contract.dart in this package).
final class FakeVoiceCoreClient implements VoiceCoreClient {
  /// Creates a fake reporting [_version], or throwing [versionError] if set.
  new({this._version = '0.0.0', this.versionError});

  String _version;

  /// When set, reading [version] throws it.
  VoiceCoreException? versionError;

  @override
  String get version {
    final error = versionError;
    if (error != null) {
      throw error;
    }
    return _version;
  }

  set version(String value) => _version = value;
}
