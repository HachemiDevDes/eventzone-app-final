import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  try {
    final response = await s
        .from('connections')
        .select()
        .eq('user_id', '2e7f1431-6e56-490b-ad5c-3dc117c62d93')
        .order('created_at', ascending: false);
    print('Connections loaded successfully: ${response.length}');
  } catch (e) {
    print("Error exactly as in app: $e");
  }
}
