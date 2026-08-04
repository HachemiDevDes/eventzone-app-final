import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

void main() async {
  await Supabase.initialize(
    url: 'https://awkreadldqmidcrrqukm.supabase.co',
    publishableKey: 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z',
  );

  try {
    await Supabase.instance.client.from('support_messages').insert({
      'user_id': '00000000-0000-0000-0000-000000000000',
      'subject': 'test',
      'message': 'test',
    });
    print("Insert success");
  } catch (e) {
    print("Error during insert: $e");
  }
}
