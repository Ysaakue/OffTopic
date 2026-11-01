import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every translation must define the same messages and placeholders as the
/// English template, so no screen ever falls back to a missing string.
void main() {
  const templateFile = 'lib/l10n/app_en.arb';
  final translations = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.arb'))
      .where((file) => !file.path.endsWith('app_en.arb'))
      .toList();

  Map<String, Object?> read(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  Set<String> messageKeys(Map<String, Object?> arb) =>
      arb.keys.where((key) => !key.startsWith('@')).toSet();

  Set<String> placeholdersIn(String message) =>
      RegExp(r'\{(\w+)\}').allMatches(message).map((m) => m.group(1)!).toSet();

  final template = read(templateFile);

  test('there is at least one translation', () {
    expect(translations, isNotEmpty);
  });

  test('every template message documents itself', () {
    for (final key in messageKeys(template)) {
      expect(template, contains('@$key'), reason: '$key has no description');
    }
  });

  for (final file in translations) {
    group(file.uri.pathSegments.last, () {
      final translation = read(file.path);

      test('defines exactly the template messages', () {
        expect(messageKeys(translation), messageKeys(template));
      });

      test('uses the same placeholders as the template', () {
        for (final key in messageKeys(template)) {
          expect(
            placeholdersIn(translation[key]! as String),
            placeholdersIn(template[key]! as String),
            reason: key,
          );
        }
      });
    });
  }
}
