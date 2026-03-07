import "package:app/src/testing/test_keys.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:integration_test/integration_test.dart";

class TestRobot {
  const TestRobot(this.tester);

  final WidgetTester tester;

  ValueKey<String> keyOf(String value) => ValueKey<String>(value);

  Finder _visibleByKey(String key) => find.byKey(keyOf(key)).hitTestable();
  Finder _rawByKey(String key) => find.byKey(keyOf(key));
  Finder _editableByKey(String key) => find
      .descendant(of: _rawByKey(key), matching: find.byType(EditableText))
      .hitTestable();

  Future<void> pumpFor(Duration duration) async {
    await tester.pump(duration);
  }

  Future<void> waitFor(
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 200));
      final pendingException = tester.takeException();
      if (pendingException != null) {
        _writeReportData("wait_for_exception");
        throw TestFailure(
          "Framework exception while waiting for $finder: $pendingException.\n"
          "Visible texts: ${visibleTexts()}\n"
          "Visible keys: ${visibleKeys()}",
        );
      }
      if (finder.evaluate().isNotEmpty) {
        return;
      }
    }
    _writeReportData("wait_for_timeout");
    final texts = find
        .byType(Text)
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? "")
        .where((text) => text.trim().isNotEmpty)
        .take(20)
        .toList(growable: false);
    final keys = tester.allWidgets
        .map((widget) => widget.key)
        .whereType<ValueKey<Object?>>()
        .map((key) => key.value.toString())
        .where((value) => value.isNotEmpty)
        .take(30)
        .toList(growable: false);
    throw TestFailure(
      "Timed out waiting for $finder.\n"
      "Visible texts: $texts\n"
      "Visible keys: $keys",
    );
  }

  Future<void> tapByKey(
    String key, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final finder = _bestTapTargetForKey(key);
    await waitFor(finder, timeout: timeout);
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> tapText(
    String text, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final finder = find.text(text).hitTestable();
    await waitFor(finder, timeout: timeout);
    await tester.tap(finder.first);
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> pressByKey(
    String key, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final finder = _rawByKey(key);
    await waitFor(finder, timeout: timeout);
    final widget = tester.widget(finder);
    if (widget is ButtonStyleButton) {
      final onPressed = widget.onPressed;
      if (onPressed == null) {
        throw TestFailure("Button '$key' is disabled.");
      }
      onPressed();
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    if (widget is InkWell) {
      final onTap = widget.onTap;
      if (onTap == null) {
        throw TestFailure("InkWell '$key' has no onTap callback.");
      }
      onTap();
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tapByKey(key, timeout: timeout);
  }

  Future<void> enterTextByKey(
    String key,
    String value, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final fieldFinder = _rawByKey(key);
    final editable = _editableByKey(key);
    await waitFor(editable, timeout: timeout);
    await tester.ensureVisible(editable);
    await tester.tap(editable);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.showKeyboard(editable);
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(editable, value);
    await tester.pump(const Duration(milliseconds: 300));

    var enteredValue = _readTextValue(fieldFinder) ?? _readTextValue(editable);
    if (enteredValue != null && enteredValue != value) {
      _setTextValue(fieldFinder, value);
      enteredValue = _readTextValue(fieldFinder) ?? _readTextValue(editable);
    }
    if (enteredValue != null && enteredValue != value) {
      throw TestFailure(
        "Failed to enter text for key '$key'. "
        "Expected '$value' but found '$enteredValue'.",
      );
    }
  }

  Future<void> enterSearchText(String value) async {
    final searchField = _visibleByKey(TestKeys.searchKeywordField);
    await waitFor(searchField);
    final editable = find
        .descendant(of: searchField, matching: find.byType(EditableText))
        .hitTestable();
    await waitFor(editable);
    await tester.tap(editable);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(editable, value);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> selectBottomNavIndex(
    int index, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final navFinder = find.byType(BottomNavigationBar);
    await waitFor(navFinder, timeout: timeout);
    final nav = tester.widget<BottomNavigationBar>(navFinder);
    final onTap = nav.onTap;
    if (onTap == null) {
      throw TestFailure("BottomNavigationBar.onTap is null.");
    }
    onTap(index);
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> openInboxTab() async {
    try {
      await tapByKey(TestKeys.navInbox);
      return;
    } catch (_) {
      // Fall through to label tap and callback fallback.
    }

    try {
      await tapText("Inbox");
      return;
    } catch (_) {
      // Fall through to direct callback fallback.
    }

    await selectBottomNavIndex(1);
  }

  Future<void> signIn({required String email, required String password}) async {
    print("E2E signIn UI start email=$email");
    _writeUiReportData("sign_in_ui_start");

    try {
      final inboxFinder = find.byKey(keyOf(TestKeys.navInbox)).hitTestable();
      if (inboxFinder.evaluate().isNotEmpty) {
        _writeUiReportData("sign_in_ui_already_signed_in");
        return;
      }

      _writeUiReportData("sign_in_ui_open_tab");
      await selectBottomNavIndex(1);
      _writeUiReportData("sign_in_ui_tab_opened");

      await waitFor(_editableByKey(TestKeys.authEmailField));
      _writeUiReportData("sign_in_ui_email_ready");
      await waitFor(_editableByKey(TestKeys.authPasswordField));
      _writeUiReportData("sign_in_ui_password_ready");
      await waitFor(_bestTapTargetForKey(TestKeys.authSubmitButton));
      _writeUiReportData("sign_in_ui_submit_ready");

      await enterTextByKey(TestKeys.authEmailField, email);
      _writeUiReportData("sign_in_ui_email_entered");
      await tester.pump(const Duration(milliseconds: 400));
      await enterTextByKey(TestKeys.authPasswordField, password);
      _writeUiReportData("sign_in_ui_password_entered");
      await tester.pump(const Duration(milliseconds: 400));

      final enteredEmail = readTextByKey(TestKeys.authEmailField);
      final enteredPassword = readTextByKey(TestKeys.authPasswordField);
      if (enteredEmail != email || enteredPassword != password) {
        _writeUiReportData("sign_in_ui_field_mismatch");
        throw TestFailure(
          "Sign in field mismatch before submit. "
          "Expected email='$email' passwordLength=${password.length}. "
          "Actual email='${enteredEmail ?? "null"}' "
          "passwordLength=${enteredPassword?.length ?? 0}. "
          "Visible texts: ${visibleTexts()}",
        );
      }

      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 400));
      _writeUiReportData("sign_in_ui_before_submit");
      await pressByKey(TestKeys.authSubmitButton);

      _writeUiReportData("sign_in_ui_submitted");
      final end = DateTime.now().add(const Duration(seconds: 20));
      var iteration = 0;
      while (DateTime.now().isBefore(end)) {
        iteration += 1;
        await tester.pump(const Duration(milliseconds: 200));
        final pendingException = tester.takeException();
        if (pendingException != null) {
          _writeUiReportData("sign_in_ui_rebuild_exception");
          throw TestFailure(
            "Sign in UI flow hit framework exception: $pendingException. "
            "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"}. "
            "Visible texts: ${visibleTexts()}. "
            "Visible keys: ${visibleKeys()}",
          );
        }
        if (inboxFinder.evaluate().isNotEmpty) {
          _writeUiReportData("sign_in_ui_success");
          await tester.pump(const Duration(milliseconds: 500));
          return;
        }

        final currentVisibleTexts = visibleTexts();
        final errorText = currentVisibleTexts
            .where((text) {
              final normalized = text.toLowerCase();
              return normalized.contains("required") ||
                  normalized.contains("error") ||
                  normalized.contains("invalid") ||
                  normalized.contains("wrong password") ||
                  normalized.contains("user");
            })
            .toList(growable: false);

        if (iteration % 5 == 0) {
          print(
            "E2E signIn UI wait "
            "uid=${FirebaseAuth.instance.currentUser?.uid ?? "null"} "
            "email=${FirebaseAuth.instance.currentUser?.email ?? "null"} "
            "inbox=${inboxFinder.evaluate().isNotEmpty} "
            "texts=$currentVisibleTexts",
          );
        }

        if (errorText.isNotEmpty && FirebaseAuth.instance.currentUser == null) {
          _writeUiReportData("sign_in_ui_visible_error");
          throw TestFailure(
            "Sign in failed with visible error(s): $errorText. "
            "Email field='${readTextByKey(TestKeys.authEmailField)}'. "
            "Password length=${readTextByKey(TestKeys.authPasswordField)?.length ?? 0}. "
            "Visible keys: ${visibleKeys()}",
          );
        }
      }

      _writeUiReportData("sign_in_ui_timeout");
      throw TestFailure(
        "Timed out waiting for sign-in to complete. "
        "Email field='${readTextByKey(TestKeys.authEmailField)}'. "
        "Password length=${readTextByKey(TestKeys.authPasswordField)?.length ?? 0}. "
        "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"} "
        "email=${FirebaseAuth.instance.currentUser?.email ?? "null"}. "
        "Visible texts: ${visibleTexts()}. "
        "Visible keys: ${visibleKeys()}",
      );
    } catch (error, stack) {
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData["sign_in_ui_phase"] = "sign_in_ui_error";
      reportData["sign_in_ui_error"] = error.toString();
      reportData["sign_in_ui_error_stack"] = stack.toString();
      reportData["sign_in_ui_error_visible_texts"] = _safeVisibleTexts();
      reportData["sign_in_ui_error_visible_keys"] = _safeVisibleKeys();
      rethrow;
    }
  }

  Future<void> signInProgrammatically({
    required String email,
    required String password,
    bool waitForSignedInShell = true,
  }) async {
    print("E2E signInProgrammatically start email=$email");
    _writeReportData("sign_in_programmatic_start");
    try {
      try {
        await tester.runAsync(() async {
          if (FirebaseAuth.instance.currentUser != null) {
            await FirebaseAuth.instance.signOut();
          }
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
          await FirebaseAuth.instance
              .authStateChanges()
              .firstWhere(
                (user) =>
                    user != null && (user.email == null || user.email == email),
              )
              .timeout(const Duration(seconds: 10));
        });
        print(
          "E2E signInProgrammatically auth call returned "
          "uid=${FirebaseAuth.instance.currentUser?.uid ?? "null"} "
          "email=${FirebaseAuth.instance.currentUser?.email ?? "null"}",
        );
        _writeReportData("sign_in_programmatic_auth_returned");
      } catch (error) {
        print("E2E signInProgrammatically auth call failed: $error");
        _writeReportData("sign_in_programmatic_auth_failed");
        throw TestFailure(
          "Programmatic sign-in failed for '$email': $error. "
          "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"}. "
          "Visible texts: ${visibleTexts()}. "
          "Visible keys: ${visibleKeys()}",
        );
      }

      if (!waitForSignedInShell) {
        final immediateUser = FirebaseAuth.instance.currentUser;
        _writeReportData("sign_in_programmatic_auth_only_enter");
        if (immediateUser != null &&
            (immediateUser.email == null || immediateUser.email == email)) {
          _writeReportData("sign_in_programmatic_auth_only_success");
          print(
            "E2E signInProgrammatically auth-only immediate success "
            "uid=${immediateUser.uid} email=${immediateUser.email ?? "null"}",
          );
          return;
        }

        final authOnlyEnd = DateTime.now().add(const Duration(seconds: 5));
        while (DateTime.now().isBefore(authOnlyEnd)) {
          await tester.pump(const Duration(milliseconds: 200));
          final pendingException = tester.takeException();
          if (pendingException != null) {
            print(
              "E2E signInProgrammatically auth-only rebuild exception: "
              "$pendingException",
            );
            _writeReportData("sign_in_programmatic_auth_only_exception");
            throw TestFailure(
              "Programmatic auth-only sign-in rebuild failed for '$email': "
              "$pendingException. "
              "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"}. "
              "Visible texts: ${visibleTexts()}. "
              "Visible keys: ${visibleKeys()}",
            );
          }
          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null &&
              (currentUser.email == null || currentUser.email == email)) {
            _writeReportData("sign_in_programmatic_auth_only_success");
            print(
              "E2E signInProgrammatically auth-only success "
              "uid=${currentUser.uid} email=${currentUser.email ?? "null"}",
            );
            return;
          }
        }
        _writeReportData("sign_in_programmatic_auth_only_timeout");
        throw TestFailure(
          "Programmatic auth-only sign-in timed out for '$email'. "
          "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"} "
          "email=${FirebaseAuth.instance.currentUser?.email ?? "null"}. "
          "Visible texts: ${visibleTexts()}. "
          "Visible keys: ${visibleKeys()}",
        );
      }

      final end = DateTime.now().add(const Duration(seconds: 10));
      var iteration = 0;
      final inboxFinder = find.byKey(keyOf(TestKeys.navInbox));
      while (DateTime.now().isBefore(end)) {
        iteration += 1;
        final binding = IntegrationTestWidgetsFlutterBinding.instance;
        final reportData = binding.reportData ??= <String, dynamic>{};
        reportData["sign_in_programmatic_loop_iteration"] = iteration;
        reportData["sign_in_programmatic_nav_inbox_visible"] = inboxFinder
            .evaluate()
            .isNotEmpty;
        reportData["sign_in_programmatic_current_user"] =
            FirebaseAuth.instance.currentUser?.uid ?? "null";
        reportData["sign_in_programmatic_current_email"] =
            FirebaseAuth.instance.currentUser?.email ?? "null";

        await tester.pump(const Duration(milliseconds: 200));
        final pendingException = tester.takeException();
        if (pendingException != null) {
          print(
            "E2E signInProgrammatically rebuild exception: $pendingException",
          );
          _writeReportData("sign_in_programmatic_rebuild_exception");
          throw TestFailure(
            "Programmatic sign-in rebuild failed for '$email': $pendingException. "
            "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"}. "
            "Visible texts: ${visibleTexts()}. "
            "Visible keys: ${visibleKeys()}",
          );
        }
        final currentUser = FirebaseAuth.instance.currentUser;
        if (iteration % 5 == 0) {
          print(
            "E2E signInProgrammatically wait "
            "uid=${currentUser?.uid ?? "null"} "
            "email=${currentUser?.email ?? "null"} "
            "navInbox=${inboxFinder.evaluate().isNotEmpty}",
          );
        }
        if (currentUser != null &&
            (currentUser.email == null || currentUser.email == email) &&
            inboxFinder.evaluate().isNotEmpty) {
          _writeReportData("sign_in_programmatic_success");
          print(
            "E2E signInProgrammatically success "
            "uid=${currentUser.uid} email=${currentUser.email ?? "null"}",
          );
          return;
        }
      }

      print(
        "E2E signInProgrammatically timeout "
        "uid=${FirebaseAuth.instance.currentUser?.uid ?? "null"} "
        "email=${FirebaseAuth.instance.currentUser?.email ?? "null"} "
        "navInbox=${inboxFinder.evaluate().isNotEmpty} "
        "texts=${visibleTexts()} keys=${visibleKeys()}",
      );
      _writeReportData("sign_in_programmatic_timeout");
      throw TestFailure(
        "Programmatic sign-in timed out for '$email'. "
        "Current user=${FirebaseAuth.instance.currentUser?.uid ?? "null"} "
        "email=${FirebaseAuth.instance.currentUser?.email ?? "null"}. "
        "Nav inbox visible=${inboxFinder.evaluate().isNotEmpty}. "
        "Visible texts: ${visibleTexts()}. "
        "Visible keys: ${visibleKeys()}",
      );
    } catch (error, stack) {
      final binding = IntegrationTestWidgetsFlutterBinding.instance;
      final reportData = binding.reportData ??= <String, dynamic>{};
      reportData["sign_in_programmatic_phase"] = "sign_in_programmatic_error";
      reportData["sign_in_programmatic_error"] = error.toString();
      reportData["sign_in_programmatic_error_stack"] = stack.toString();
      reportData["sign_in_programmatic_error_visible_texts"] =
          _safeVisibleTexts();
      reportData["sign_in_programmatic_error_visible_keys"] =
          _safeVisibleKeys();
      rethrow;
    }
  }

  String? readTextByKey(String key) => _readTextValue(find.byKey(keyOf(key)));

  List<String> visibleTexts() {
    return find
        .byType(Text)
        .hitTestable()
        .evaluate()
        .map((element) => element.widget)
        .whereType<Text>()
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? "")
        .where((text) => text.trim().isNotEmpty)
        .take(30)
        .toList(growable: false);
  }

  List<String> visibleKeys() {
    return tester.allWidgets
        .map((widget) => widget.key)
        .whereType<ValueKey<Object?>>()
        .map((key) => key.value.toString())
        .where((value) => value.isNotEmpty)
        .take(40)
        .toList(growable: false);
  }

  String? _readTextValue(Finder finder) {
    if (finder.evaluate().isEmpty) {
      return null;
    }
    final widget = tester.widget(finder);
    if (widget is TextField) {
      return widget.controller?.text;
    }
    if (widget is EditableText) {
      return widget.controller.text;
    }
    if (widget is TextFormField) {
      return widget.controller?.text;
    }
    return null;
  }

  void _setTextValue(Finder finder, String value) {
    if (finder.evaluate().isEmpty) {
      return;
    }
    final widget = tester.widget(finder);
    TextEditingController? controller;
    if (widget is TextField) {
      controller = widget.controller;
    } else if (widget is EditableText) {
      controller = widget.controller;
    } else if (widget is TextFormField) {
      controller = widget.controller;
    }
    if (controller == null) {
      return;
    }
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    tester.binding.scheduleFrame();
  }

  Finder _bestTapTargetForKey(String key) {
    final raw = _rawByKey(key);
    final candidates = <Finder>[
      raw.hitTestable(),
      find.descendant(of: raw, matching: find.byType(Text)).hitTestable(),
      find.descendant(of: raw, matching: find.byType(Icon)).hitTestable(),
      find.descendant(of: raw, matching: find.byType(RichText)).hitTestable(),
      find.descendant(of: raw, matching: find.byType(InkWell)).hitTestable(),
      find
          .descendant(of: raw, matching: find.byType(GestureDetector))
          .hitTestable(),
    ];
    for (final candidate in candidates) {
      if (candidate.evaluate().isNotEmpty) {
        return candidate;
      }
    }
    return raw;
  }

  void _writeReportData(String phase) {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    final reportData = binding.reportData ??= <String, dynamic>{};
    reportData["sign_in_programmatic_phase"] = phase;
    reportData["sign_in_programmatic_current_user"] =
        FirebaseAuth.instance.currentUser?.uid ?? "null";
    reportData["sign_in_programmatic_current_email"] =
        FirebaseAuth.instance.currentUser?.email ?? "null";
    reportData["sign_in_programmatic_visible_texts"] = visibleTexts();
    reportData["sign_in_programmatic_visible_keys"] = visibleKeys();
    reportData["sign_in_programmatic_nav_inbox_visible"] = find
        .byKey(keyOf(TestKeys.navInbox))
        .evaluate()
        .isNotEmpty;
  }

  void _writeUiReportData(String phase) {
    final binding = IntegrationTestWidgetsFlutterBinding.instance;
    final reportData = binding.reportData ??= <String, dynamic>{};
    reportData["sign_in_ui_phase"] = phase;
    reportData["sign_in_ui_current_user"] =
        FirebaseAuth.instance.currentUser?.uid ?? "null";
    reportData["sign_in_ui_current_email"] =
        FirebaseAuth.instance.currentUser?.email ?? "null";
    reportData["sign_in_ui_visible_texts"] = visibleTexts();
    reportData["sign_in_ui_visible_keys"] = visibleKeys();
    reportData["sign_in_ui_nav_inbox_visible"] = find
        .byKey(keyOf(TestKeys.navInbox))
        .evaluate()
        .isNotEmpty;
  }

  List<String> _safeVisibleTexts() {
    try {
      return visibleTexts();
    } catch (_) {
      return const ["<visibleTexts failed>"];
    }
  }

  List<String> _safeVisibleKeys() {
    try {
      return visibleKeys();
    } catch (_) {
      return const ["<visibleKeys failed>"];
    }
  }
}
