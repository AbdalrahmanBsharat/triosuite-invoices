import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../storage/secure_store.dart';

/// The light/dark preference, remembered between launches.
///
/// Separate from the settings screen's own controller because the choice has to outlive that
/// screen — it is read once at start-up, before any route exists.
class ThemeController extends GetxController {
  ThemeController(this._store);

  final SecureStore _store;

  final Rx<ThemeMode> mode = ThemeMode.system.obs;

  /// Reads the stored preference. Called before the app is built so the first frame is already in
  /// the right theme rather than flashing the wrong one.
  Future<void> load() async {
    mode.value = await _store.readThemeMode();
  }

  Future<void> setMode(ThemeMode value) async {
    if (mode.value == value) {
      return;
    }
    mode.value = value;
    Get.changeThemeMode(value);
    await _store.saveThemeMode(value);
  }

  /// The label shown on the settings row.
  String labelFor(ThemeMode value) => switch (value) {
        ThemeMode.system => 'Match the device',
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
      };
}
