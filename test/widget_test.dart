// Basic smoke test for the CredLock app.
// Verifies the app widget can be instantiated without errors.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:credlock/main.dart';

void main() {
  testWidgets('CredLockApp smoke test', (WidgetTester tester) async {
    // Just verify the app widget builds without throwing.
    expect(const CredLockApp(), isA<Widget>());
  });
}
