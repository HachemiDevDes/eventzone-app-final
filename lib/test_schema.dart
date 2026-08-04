import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final url = 'https://awkreadldqmidcrrqukm.supabase.co/rest/v1/';
  final key = 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'apikey': key,
        'Authorization': 'Bearer $key'
      },
    );
    
    print("Response status: ${response.statusCode}");
    if (response.statusCode != 200) {
       print("Response body: ${response.body}");
       return;
    }
    
    final Map<String, dynamic> data = jsonDecode(response.body);
    final definitions = data['definitions'] as Map<String, dynamic>?;
    if (definitions != null) {
      print("Tables:");
      for (final table in definitions.keys) {
        print(" - $table");
      }
    } else {
      print("No definitions found. Full data: $data");
    }
  } catch (e) {
    print("Error: $e");
  }
}
