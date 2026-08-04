import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://awkreadldqmidcrrqukm.supabase.co/rest/v1/support_messages';
  final key = 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z';
  
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
        'Prefer': 'return=representation'
      },
      body: jsonEncode({
        'user_id': '00000000-0000-0000-0000-000000000000',
        'name': 'Test User',
        'email': 'test@test.com',
        'subject': 'test',
        'message': 'test',
      }),
    );
    
    print("Response status: ${response.statusCode}");
    print("Response body: ${response.body}");
  } catch (e) {
    print("Error: $e");
  }
}
