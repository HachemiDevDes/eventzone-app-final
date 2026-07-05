import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  try {
    final response = await s
        .from('connections')
        .select('id, user_id', const FetchOptions(count: CountOption.exact));
    print('Response count: ${response.count}');
  } catch (e) {
    print("Error: $e");
  }
}
