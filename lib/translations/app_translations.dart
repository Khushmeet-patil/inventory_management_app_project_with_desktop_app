import 'package:get/get.dart';
import 'en_translations.dart';
import 'hi_translations.dart';
import 'gu_translations.dart';

class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
    'en': enTranslations,
    'hi': hiTranslations,
    'gu': guTranslations,
  };
}
