import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/repositories/local_network_repository.dart';

/// The addresses the host shows so the other riders can type one to join.
final class FindHostAddresses {
  const new(this._network);

  final LocalNetworkRepository _network;

  Future<Result<List<LocalAddress>>> call() => _network.localAddresses();
}
