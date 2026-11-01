import 'package:flutter_test/flutter_test.dart';
import 'package:offtopic/features/home/domain/entities/app_info.dart';

import '../../../../helpers/fixtures.dart';

void main() {
  test('AppInfo compares every field', () {
    const same = AppInfo(
      coreVersion: '0.1.0',
      manufacturer: 'Xiaomi',
      model: 'Redmi Note 13',
      osName: 'android',
      osVersion: '17',
    );
    const otherCore = AppInfo(
      coreVersion: '0.2.0',
      manufacturer: 'Xiaomi',
      model: 'Redmi Note 13',
      osName: 'android',
      osVersion: '17',
    );

    expect(sampleAppInfo, same);
    expect(sampleAppInfo.hashCode, same.hashCode);
    expect(sampleAppInfo, isNot(otherCore));
  });
}
