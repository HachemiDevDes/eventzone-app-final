import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://awkreadldqmidcrrqukm.supabase.co',
    anonKey: 'sb_publishable_MluMrwkWs5-YedITa6ggNw_imK2nv8z', // Wait, the key was publishableKey in main.dart. Let's see.
  );
  // Just print the schema by trying to fetch a row
  final res = await Supabase.instance.client.from('profiles').select().limit(1);
  print(res);
}
