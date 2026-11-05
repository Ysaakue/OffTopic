import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';

/// This phone's addresses on the local networks other riders can reach.
abstract interface class LocalNetworkRepository {
  /// The addresses, hotspot first, then Wi-Fi, then other local networks.
  /// Empty when the phone is on no local network (hotspot off, no Wi-Fi).
  Future<Result<List<LocalAddress>>> localAddresses();
}
