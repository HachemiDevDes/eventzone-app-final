import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  try {
    final response = await s
        .from('connections')
        .select('id, user_id, name')
        .eq('user_id', '0d3e48f0-b7c5-47db-a5c4-f3a08fc3d040');
    print('Connections loaded successfully: ${response.length} items');
    print(response);
  } catch (e) {
    print("Error loading connections: $e");
  }
}
