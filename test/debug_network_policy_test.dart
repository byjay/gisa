import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the debug manifest allows cleartext local-worker traffic', () {
    final debugManifest = File(
      'android/app/src/debug/AndroidManifest.xml',
    ).readAsStringSync();
    final mainManifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(debugManifest, contains('android:usesCleartextTraffic="true"'));
    expect(
      mainManifest,
      isNot(contains('android:usesCleartextTraffic="true"')),
    );
  });
}
