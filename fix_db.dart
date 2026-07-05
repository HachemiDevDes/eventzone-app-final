import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  final conns = await s.from('connections').select();
  for (var c in conns) {
    if (c['linked_profile_id'] != null && c['tags'] == null) {
      final p = await s.from('profiles').select('interests').eq('id', c['linked_profile_id']).maybeSingle();
      if (p != null && p['interests'] != null) {
        await s.from('connections').update({'tags': p['interests']}).eq('id', c['id']);
        print('Updated ' + c['id']);
      }
    }
  }
  print('Done');
}
