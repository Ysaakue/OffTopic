import 'dart:io';

import 'package:offtopic/core/network/local_interfaces.dart';
import 'package:offtopic/core/result/app_failure.dart';
import 'package:offtopic/core/result/result.dart';
import 'package:offtopic/features/room/data/services/local_address_classifier.dart';
import 'package:offtopic/features/room/domain/entities/local_address.dart';
import 'package:offtopic/features/room/domain/repositories/local_network_repository.dart';

/// [LocalNetworkRepository] over the phone's network interfaces.
final class LocalNetworkRepositoryImpl implements LocalNetworkRepository {
  const new({
    required this._list,
    this._classifier = const LocalAddressClassifier(),
  });

  final LocalInterfaceLister _list;
  final LocalAddressClassifier _classifier;

  @override
  Future<Result<List<LocalAddress>>> localAddresses() async {
    try {
      return Success(_classifier.classifyAll(await _list()));
    } on SocketException catch (exception) {
      return Failure(LocalNetworkFailure(exception.message));
    }
  }
}
