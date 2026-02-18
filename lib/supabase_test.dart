import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> supabasePing() async {
  final supabase = Supabase.instance.client;

  try {
    // 1️⃣ Check if Supabase client exists
    final url = supabase.rest.url;
    print("Supabase REST URL: $url");

    // 2️⃣ Check current auth session
    final session = supabase.auth.currentSession;
    print("Auth session: ${session != null ? "ACTIVE" : "NONE"}");

    // 3️⃣ Try lightweight query
    final res = await supabase
        .from('profiles')
        .select('id')
        .limit(1);

    print("Database reachable ✅");
    print("Query result: $res");
  } catch (e) {
    print("Supabase ERROR ❌");
    print(e);
  }
}
