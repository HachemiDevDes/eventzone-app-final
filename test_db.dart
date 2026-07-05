import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  final res = await s.from('connections').select().limit(1);
  print(res);
}
