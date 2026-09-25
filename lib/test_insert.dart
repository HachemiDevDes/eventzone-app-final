import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  await Supabase.initialize(
    url: 'https://gknglowozpewwrtjumuc.supabase.co',
    publishableKey: 'sb_publishable_0bdK2TAGnlyUKCnloX1Dug_Sg5uedKc',
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
