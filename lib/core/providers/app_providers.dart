import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// SharedPreferences instance (override in tests).
final sharedPrefsProvider =
    FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

/// Whether onboarding has been completed.
final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(sharedPrefsProvider.future);
  return prefs.getBool(AppConstants.onboardingSeenKey) ?? false;
});

Future<void> setOnboardingSeen(WidgetRef ref) async {
  final prefs = await ref.read(sharedPrefsProvider.future);
  await prefs.setBool(AppConstants.onboardingSeenKey, true);
  ref.invalidate(onboardingSeenProvider);
}

/// Light/dark/system theme mode, persisted.
final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref);
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(this._ref) : super(ThemeMode.system) {
    _load();
  }
  final Ref _ref;

  Future<void> _load() async {
    final prefs = await _ref.read(sharedPrefsProvider.future);
    final raw = prefs.getString(AppConstants.themeModeKey);
    switch (raw) {
      case 'light':
        state = ThemeMode.light;
        break;
      case 'dark':
        state = ThemeMode.dark;
        break;
      default:
        state = ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await _ref.read(sharedPrefsProvider.future);
    await prefs.setString(AppConstants.themeModeKey, mode.name);
  }
}
