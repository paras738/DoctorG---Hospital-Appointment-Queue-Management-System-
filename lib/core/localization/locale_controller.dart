import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en', ''));

  void setLocale(Locale loc) {
    if (loc.languageCode == 'en' || loc.languageCode == 'hi') {
      state = loc;
    }
  }

  void toggleLanguage() {
    if (state.languageCode == 'en') {
      state = const Locale('hi', '');
    } else {
      state = const Locale('en', '');
    }
  }

  bool get isHindi => state.languageCode == 'hi';
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
