import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  // Production backend URL - deployed on Render
  static const String defaultBaseUrl = 'https://groupify-cc-206-final-project.onrender.com/api';
  
  // For local testing, use: 'http://192.168.1.40:3000/api'
  
  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('backend_url') ?? defaultBaseUrl;
  }
  
  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_url', url);
  }
  
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }

    // Use production URL for released app
    return defaultBaseUrl;
  }

  // For Android Emulator, use: http://10.0.2.2:3000/api
  // For iOS Simulator, use: http://localhost:3000/api
  // For Real Device, use: http://YOUR_IP:3000/api

  // Reduced default timeout to mitigate long hangs when multiple parallel requests
  static const Duration timeout = Duration(seconds: 12);
}