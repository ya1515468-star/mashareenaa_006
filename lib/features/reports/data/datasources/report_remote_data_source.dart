import '../../../../core/data/supabase_document_compat.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/report_entity.dart';
import '../models/report_model.dart';

abstract class ReportRemoteDataSource {
  Future<void> submitReport(ReportModel report);
  Stream<List<ReportModel>> watchAllReports({ReportStatus? status});
  Future<void> resolveReport({
    required String reportId,
    required ReportStatus newStatus,
    required String resolvedBy,
  });
}

class ReportRemoteDataSourceImpl implements ReportRemoteDataSource {
  final SupabaseDocumentStore store;

  ReportRemoteDataSourceImpl(this.store);

  CollectionReference<Map<String, dynamic>> get _reports =>
      store.collection('reports');

  @override
  Future<void> submitReport(ReportModel report) async {
    try {
      await _reports.add(report.toMap());
    } catch (e) {
      throw ServerException(message: 'تعذّر إرسال البلاغ: $e');
    }
  }

  @override
  Stream<List<ReportModel>> watchAllReports({ReportStatus? status}) {
    Query<Map<String, dynamic>> query =
        _reports.orderBy('createdAt', descending: true).limit(100);
    if (status != null) {
      query = _reports
          .where('status', isEqualTo: status.wire)
          .orderBy('createdAt', descending: true);
    }
    return query.snapshots().map((snap) => snap.docs
        .map((d) =>
            ReportModel.fromMap(d.id, Map<String, dynamic>.from(d.data())))
        .toList());
  }

  @override
  Future<void> resolveReport({
    required String reportId,
    required ReportStatus newStatus,
    required String resolvedBy,
  }) async {
    try {
      // كانت كتابة مباشرة (owner_id=auth.uid() OR dragon فقط) — نفس عطل
      // الإشراف المعكوس في المنشورات وحالة الحساب: مشرف حقيقي غير المُبلِّغ
      // ولا المالك كان يحصل على "نجاح" بلا أي تعديل فعلي. moderator_resolve
      // _report تتحقق من صلاحية chat.moderate الحقيقية وتتجاوز RLS بأمان.
      await store.rpc('moderator_resolve_report', params: {
        'p_report_id': reportId,
        'p_new_status': newStatus.wire,
      });
    } catch (e) {
      throw ServerException(message: 'تعذّر تحديث حالة البلاغ: $e');
    }
  }
}
