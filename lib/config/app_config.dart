import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  static bool _isPlaceholder(String value) {
    final v = value.trim();
    if (v.isEmpty) return true;
    final upper = v.toUpperCase();
    return upper.startsWith('YOUR_') ||
        upper.contains('CHANGE_ME') ||
        upper == 'REPLACE_ME';
  }

  static String _pick({
    required String defineValue,
    required String dotenvKey,
    String fallback = '',
  }) {
    if (defineValue.isNotEmpty && !_isPlaceholder(defineValue)) {
      return defineValue;
    }
    final envValue = dotenv.env[dotenvKey];
    if (envValue != null &&
        envValue.isNotEmpty &&
        !_isPlaceholder(envValue)) {
      return envValue;
    }
    return fallback;
  }

  static const String _geminiDefine =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  static const String _groqDefine =
      String.fromEnvironment('GROQ_API_KEY', defaultValue: '');
  static const String _adminEmailDefine =
      String.fromEnvironment('ADMIN_EMAIL', defaultValue: '');
  static const String _googleServerClientIdDefine =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID', defaultValue: '');

  static String get geminiApiKey => _pick(
        defineValue: _geminiDefine,
        dotenvKey: 'GEMINI_API_KEY',
      );

  static String get groqApiKey => _pick(
        defineValue: _groqDefine,
        dotenvKey: 'GROQ_API_KEY',
      );

  static String get adminEmail => _pick(
        defineValue: _adminEmailDefine,
        dotenvKey: 'ADMIN_EMAIL',
        fallback: 'pasumarthisaikumar6266@gmail.com',
      );

  static String get googleServerClientId => _pick(
        defineValue: _googleServerClientIdDefine,
        dotenvKey: 'GOOGLE_SERVER_CLIENT_ID',
        fallback:
            '16450323072-5u4bqmvvnkpf5bnds15lr7i4es6ko9dj.apps.googleusercontent.com',
      );

  static void debugPrintConfigSource() {
    if (!kDebugMode) return;
    debugPrint(
      '[AppConfig] Using dart-define for GEMINI_API_KEY: ${_geminiDefine.isNotEmpty}',
    );
    debugPrint(
      '[AppConfig] Using dart-define for GROQ_API_KEY: ${_groqDefine.isNotEmpty}',
    );
    debugPrint(
      '[AppConfig] Using dart-define for ADMIN_EMAIL: ${_adminEmailDefine.isNotEmpty}',
    );
    debugPrint(
      '[AppConfig] Using dart-define for GOOGLE_SERVER_CLIENT_ID: ${_googleServerClientIdDefine.isNotEmpty}',
    );
  }
}
