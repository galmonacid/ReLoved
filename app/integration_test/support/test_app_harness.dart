import "package:app/theme/app_theme.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";

Future<void> pumpTestApp(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      title: "ReLoved E2E",
      theme: AppTheme.light,
      home: home,
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}
