import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/garment_business_profile_entity.dart';
import '../models/garment_business_profile_model.dart';

abstract class GarmentHubRemoteDataSource {
  Future<void> upsertBusinessProfile(GarmentBusinessProfileModel profile);
  Future<GarmentBusinessProfileModel?> getBusinessProfile(String uid);
  Stream<List<GarmentBusinessProfileModel>> watchDirectory(
      {GarmentBusinessType? businessType});
}

class GarmentHubRemoteDataSourceImpl implements GarmentHubRemoteDataSource {
  final SupabaseDocumentStore store;

  GarmentHubRemoteDataSourceImpl(this.store);

  CollectionReference<Map<String, dynamic>> get _accounts =>
      store.collection(BackendCollections.accounts);

  @override
  Future<void> upsertBusinessProfile(
      GarmentBusinessProfileModel profile) async {
    try {
      await _accounts
          .doc(profile.uid)
          .set(profile.toFieldMap(), const SetOptions(merge: true));
    } catch (e) {
      throw ServerException(message: 'تعذّر حفظ الملف التجاري: $e');
    }
  }

  @override
  Future<GarmentBusinessProfileModel?> getBusinessProfile(String uid) async {
    try {
      final doc = await store.collection('public_profiles').doc(uid).get();
      if (!doc.exists || doc.data()?['garmentBusiness'] == null) return null;
      return GarmentBusinessProfileModel.fromMap(uid, doc.data()!);
    } catch (e) {
      throw ServerException(message: 'تعذّر جلب الملف التجاري: $e');
    }
  }

  @override
  Stream<List<GarmentBusinessProfileModel>> watchDirectory(
      {GarmentBusinessType? businessType}) {
    Query<Map<String, dynamic>> query = store
        .collection('public_profiles')
        .where('garmentBusiness', isNotEqualTo: null);
    if (businessType != null) {
      query = query.where('garmentBusiness.businessType',
          isEqualTo: businessType.wire);
    }
    return query.snapshots().map(
          (snap) => snap.docs
              .map((d) => GarmentBusinessProfileModel.fromMap(
                  d.id, Map<String, dynamic>.from(d.data())))
              .toList(),
        );
  }
}
