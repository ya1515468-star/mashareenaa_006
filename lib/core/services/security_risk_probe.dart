import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityRiskProbe {
  static Future<void> run() async {
    final client = Supabase.instance.client;
    final session = client.auth.currentSession;

    if (session == null) {
      debugPrint('SECURITY_RISK_PROBE: NO_SESSION');
      return;
    }

    try {
      final response = await client.functions.invoke(
        'security-risk',
        body: const <String, dynamic>{},
      );

      debugPrint(
        'SECURITY_RISK_PROBE: status=${response.status} data=${response.data}',
      );
    } catch (e) {
      debugPrint(
        'SECURITY_RISK_PROBE: ERROR=$e',
      );
    }
  }
}
