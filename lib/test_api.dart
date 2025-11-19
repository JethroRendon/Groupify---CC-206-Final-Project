import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> testBackendConnection() async {
  try {
    print('Testing connection to http://localhost:3000/health');
    
    final response = await http.get(
      Uri.parse('http://localhost:3000/health'),
    );
    
    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
    
    if (response.statusCode == 200) {
      print('✅ Backend connection successful!');
    } else {
      print('❌ Backend returned error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error connecting to backend: $e');
  }
}