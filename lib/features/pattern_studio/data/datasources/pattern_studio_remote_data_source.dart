import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';
import '../../../wallet/domain/entities/currency.dart';
import '../../domain/entities/pattern_enums.dart';
import '../models/pattern_request_model.dart';

abstract class PatternStudioRemoteDataSource {
  Future<PatternStudioConfigEntity> getConfig();
  Future<void> updateConfig(PatternStudioConfigEntity config);
  Future<void> createRequest(PatternRequestModel request);
  Stream<List<PatternRequestModel>> watchMyRequests(String uid);
  Stream<List<PatternRequestModel>> watchAllRequests(
      {PatternRequestStatus? status});
  Future<void> submitResult({
    required String requestId,
    String? resultImageUrl,
    String? resultVideoUrl,
    String? reviewerNote,
  });
  Future<void> rejectRequest(
      {required String requestId, required String reason});
}

class PatternStudioRemoteDataSourceImpl
    implements PatternStudioRemoteDataSource {
  final SupabaseDocumentStore store;

  PatternStudioRemoteDataSourceImpl(this.store);

  DocumentReference<Map<String, dynamic>> get _configDoc =>
      store.collection('app_config').doc('pattern_studio');

  CollectionReference<Map<String, dynamic>> get _requests =>
      store.collection('pattern_requests');

  @override
  Future<PatternStudioConfigEntity> getConfig() async {
    try {
      final doc = await _configDoc.get();
      if (!doc.exists) return PatternStudioConfigEntity.fallback();
      final data = doc.data()!;
      return PatternStudioConfigEntity(
        enabled: data['enabled'] as bool? ?? true,
        price: Money(
          minorUnits: data['priceMinorUnits'] as int? ??
              PatternStudioConfigEntity.fallback().price.minorUnits,
          currency: CurrencyX.fromWire(data['currency'] as String?),
        ),
      );
    } catch (e) {
      throw ServerException(message: 'تعذّر جلب إعدادات الميزة: $e');
    }
  }

  @override
  Future<void> updateConfig(PatternStudioConfigEntity config) async {
    try {
      await _configDoc.set({
        'enabled': config.enabled,
        'priceMinorUnits': config.price.minorUnits,
        'currency': config.price.currency.wire,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث إعدادات الميزة: $e');
    }
  }

  @override
  Future<void> createRequest(PatternRequestModel request) async {
    try {
      await _requests.add(request.toMap());
    } catch (e) {
      throw ServerException(message: 'تعذّر إنشاء الطلب: $e');
    }
  }

  @override
  Stream<List<PatternRequestModel>> watchMyRequests(String uid) {
    return _requests
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PatternRequestModel.fromMap(
                d.id, Map<String, dynamic>.from(d.data())))
            .toList());
  }

  @override
  Stream<List<PatternRequestModel>> watchAllRequests(
      {PatternRequestStatus? status}) {
    Query<Map<String, dynamic>> query =
        _requests.orderBy('createdAt', descending: true).limit(100);
    if (status != null) {
      query = _requests
          .where('status', isEqualTo: status.wire)
          .orderBy('createdAt', descending: true);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) => PatternRequestModel.fromMap(
            d.id, Map<String, dynamic>.from(d.data())))
        .toList());
  }

  @override
  Future<void> submitResult({
    required String requestId,
    String? resultImageUrl,
    String? resultVideoUrl,
    String? reviewerNote,
  }) async {
    try {
      await _requests.doc(requestId).update({
        'status': PatternRequestStatus.completed.wire,
        if (resultImageUrl != null) 'resultImageUrl': resultImageUrl,
        if (resultVideoUrl != null) 'resultVideoUrl': resultVideoUrl,
        if (reviewerNote != null) 'reviewerNote': reviewerNote,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر رفع النتيجة: $e');
    }
  }

  @override
  Future<void> rejectRequest(
      {required String requestId, required String reason}) async {
    try {
      await _requests.doc(requestId).update({
        'status': PatternRequestStatus.rejected.wire,
        'reviewerNote': reason,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر رفض الطلب: $e');
    }
  }
}
