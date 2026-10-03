import '../../../../core/data/supabase_document_compat.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../models/user_subscription_model.dart';

abstract class SubscriptionRemoteDataSource {
  Future<UserSubscriptionModel> getCurrentSubscription(String uid);

  Stream<UserSubscriptionModel> watchSubscription(String uid);

  Future<Map<String, bool>> getFeatureOverrides(String uid);

  Future<void> setFeatureOverride({
    required String targetUid,
    required String featureKey,
    required bool enabled,
    required String grantedByUid,
  });
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final SupabaseDocumentStore store;

  SubscriptionRemoteDataSourceImpl(this.store);

  DocumentReference<Map<String, dynamic>> _doc(String uid) {
    return store.collection(BackendCollections.accounts).doc(uid);
  }

  @override
  Future<UserSubscriptionModel> getCurrentSubscription(String uid) async {
    try {
      final doc = await _doc(uid).get();

      if (!doc.exists) {
        return UserSubscriptionModel.fromMap(uid, const {});
      }

      return UserSubscriptionModel.fromMap(uid, doc.data()!);
    } catch (e) {
      throw ServerException(
        message: 'تعذّر جلب حالة الاشتراك: $e',
      );
    }
  }

  @override
  Stream<UserSubscriptionModel> watchSubscription(String uid) {
    return _doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        return UserSubscriptionModel.fromMap(uid, const {});
      }

      return UserSubscriptionModel.fromMap(
        uid,
        doc.data()!,
      );
    });
  }

  @override
  Future<Map<String, bool>> getFeatureOverrides(
    String uid,
  ) async {
    try {
      final doc = await _doc(uid).get();

      final raw =
          (doc.data()?['membershipOverrides'] as Map?) ?? <dynamic, dynamic>{};

      final result = <String, bool>{};

      for (final entry in raw.entries) {
        final key = entry.key.toString();
        final value = entry.value;

        if (value is bool) {
          result[key] = value;
        }
      }

      return result;
    } catch (_) {
      return {};
    }
  }

  @override
  Future<void> setFeatureOverride({
    required String targetUid,
    required String featureKey,
    required bool enabled,
    required String grantedByUid,
  }) async {
    try {
      final callable = SupabaseFunctionsCompat.instance
          .httpsCallable('adminGrantMembership');

      await callable.call({
        'targetUid': targetUid,
        'featureKey': featureKey,
        'enabled': enabled,
      });
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
        message: e.message ?? 'تعذّر منح المزية',
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر منح المزية: $e',
      );
    }
  }
}
