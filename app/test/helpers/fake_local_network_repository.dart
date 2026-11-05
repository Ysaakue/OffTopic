import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/repositories/local_network_repository.dart';

/// [LocalNetworkRepository] that answers [result] and counts the reads.
final class FakeLocalNetworkRepository implements LocalNetworkRepository {
  new([this.result = const Success([])]);

  Result<List<LocalAddress>> result;
  int reads = 0;

  @override
  Future<Result<List<LocalAddress>>> localAddresses() async {
    reads++;
    return result;
  }
}
