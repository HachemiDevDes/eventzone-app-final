import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  try {
    final response = await s
        .from('connections')
        .select()
        .eq('id', '86b19da4-c481-424a-9dbf-1941df8073eb');
    print(response);
  } catch (e) {
    print("Error exactly as in app: $e");
  }
}
