import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageController extends GetxController {
  static const String LANGUAGE_KEY = 'selected_language';
  
  final RxString currentLanguage = 'en'.obs;
  final List<Map<String, dynamic>> availableLanguages = [
    {'code': 'en', 'name': 'English', 'flag': '🇺🇸'},
    {'code': 'hi', 'name': 'हिंदी', 'flag': '🇮🇳'},
    {'code': 'gu', 'name': 'ગુજરાતી', 'flag': '🇮🇳'},
  ];

  @override
  void onInit() {
    super.onInit();
    loadSavedLanguage();
  }

  Future<void> loadSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLanguage = prefs.getString(LANGUAGE_KEY);
    
    if (savedLanguage != null) {
      currentLanguage.value = savedLanguage;
      updateLocale(savedLanguage);
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(LANGUAGE_KEY, languageCode);
    
    currentLanguage.value = languageCode;
    updateLocale(languageCode);
  }

  void updateLocale(String languageCode) {
    final locale = Locale(languageCode);
    Get.updateLocale(locale);
  }

  String getLanguageName(String code) {
    final language = availableLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'code': code, 'name': code, 'flag': '🏳️'},
    );
    return language['name'];
  }

  String getLanguageFlag(String code) {
    final language = availableLanguages.firstWhere(
      (lang) => lang['code'] == code,
      orElse: () => {'code': code, 'name': code, 'flag': '🏳️'},
    );
    return language['flag'];
  }
}
