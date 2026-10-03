import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';
import '../../../auth/domain/entities/user_entity.dart';

abstract class AdminRemoteDataSource {
  Future<void> setAccountStatus(
      {required String targetUid, required AccountStatus status});
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  final SupabaseDocumentStore store;

  AdminRemoteDataSourceImpl(this.store);

  @override
  Future<void> setAccountStatus(
      {required String targetUid, required AccountStatus status}) async {
    try {
      // كانت هذه كتابة مباشرة (owner_id=auth.uid() OR dragon فقط عبر RLS) —
      // اختبار حي كشف أن أي مستخدم يستطيع تغيير حالة حسابه هو نفسه بهذه
      // الطريقة، بما فيها فكّ حظر نفسه فورًا بعد حظره من مسؤول حقيقي. وحتى
      // لو مُنعت هذه الحالة، RLS نفسها كانت تمنع أي مسؤول (غير المالك) من
      // الوصول لصف حساب شخص آخر أصلًا، فتُفشل الإشراف الحقيقي صمتًا.
      // admin_set_account_status (SECURITY DEFINER) تتحقق من الصلاحية
      // الحقيقية بنفسها وتتجاوز RLS بأمان بعد ذلك.
      await store.rpc('admin_set_account_status', params: {
        'p_target_uid': targetUid,
        'p_status': status.wire,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث حالة الحساب: $e');
    }
  }
}
