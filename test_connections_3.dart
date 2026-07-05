import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  try {
    final response = await s
        .from('connections')
        .select('id, user_id, name');
    print('Total connections: ${response.length}');
    for (var c in response) {
      print('user_id: ${c['user_id']}');
    }
  } catch (e) {
    print("Error: $e");
  }
}
