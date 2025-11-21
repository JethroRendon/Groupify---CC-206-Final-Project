import 'package:flutter/foundation.dart';

class ApiConfig {
  // When running on the web, use the current page origin so requests
  // are same-origin (avoids mixed-content when the page is served over HTTPS).
  // For mobile/desktop, default to localhost (change to your machine IP for real devices).
  static String get baseUrl {
    // NOTE: In development the Flutter web dev server runs on a different port
    // (e.g. 60879). Requesting the app origin will return the web app HTML
    // (index.html) instead of hitting the backend. Use the backend port
    // explicitly for web during development.
    if (kIsWeb) {
      return 'http://localhost:3000/api';
    }

    return 'http://localhost:3000/api';
  }

  // For Android Emulator, use: http://10.0.2.2:3000/api
  // For iOS Simulator, use: http://localhost:3000/api
  // For Real Device, use: http://YOUR_IP:3000/api

  // Reduced default timeout to mitigate long hangs when multiple parallel requests
  static const Duration timeout = Duration(seconds: 12);
}