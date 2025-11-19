class ApiConfig {
  // CHANGE THIS to your computer's IP address
  static const String baseUrl = 'http://localhost:3000/api';
  
  // For Android Emulator, use: http://10.0.2.2:3000/api
  // For iOS Simulator, use: http://localhost:3000/api
  // For Real Device, use: http://YOUR_IP:3000/api
  
  static const Duration timeout = Duration(seconds: 30);
}