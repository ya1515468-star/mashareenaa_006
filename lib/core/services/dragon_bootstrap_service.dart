import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/entities/user_entity.dart';

/// يتحقق فقط من حالة حساب DRAGON الحالية في Supabase.
/// لا يمنح العميل أي دور ولا يعدّل RBAC من Flutter.
class DragonBootstrapService {
  static bool _checkedThisSession = false;

  static Future<void> ensureDragonRole(
    UserEntity user,
  ) async {
    if (_checkedThisSession || Supabase.instance.client.auth.currentSession == null) {
      return;
    }
    try {
      final result = await Supabase.instance.client.rpc('is_my_platform_owner');
      _checkedThisSession = result == true;
    } on PostgrestException {
      _checkedThisSession = false;
    } catch (_) {
      _checkedThisSession = false;
    }
  }
}
