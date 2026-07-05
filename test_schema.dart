import 'package:supabase/supabase.dart';
void main() async {
  final client = SupabaseClient('YOUR_SUPABASE_URL', 'YOUR_SUPABASE_ANON_KEY');
  final res = await client.from('connections').select().limit(1);
  print(res);
}
