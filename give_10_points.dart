import 'package:supabase/supabase.dart';
void main() async {
  final s = SupabaseClient('https://awkreadldqmidcrrqukm.supabase.co', 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z');
  final profiles = await s.from('profiles').select('id, points_balance');
  int count = 0;
  for (var p in profiles) {
    if (p['points_balance'] == null || p['points_balance'] == 0) {
      try {
        await s.from('profiles').update({'points_balance': 10}).eq('id', p['id']);
        count++;
      } catch (e) {
        print('Error updating ${p['id']}: $e');
      }
    }
  }
  print('Done. Updated $count profiles.');
}
