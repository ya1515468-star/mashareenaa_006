import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/error/exceptions.dart';
import '../models/gift_transaction_model.dart';

abstract class GiftRemoteDataSource {
  Future<GiftTransactionModel> recordGiftTransaction(
      {required String giftId,
      required String fromUid,
      required String toUid,
      required int pricePoints,
      String? roomId});
  Stream<GiftTransactionModel> watchIncomingGifts(String uid);
}

class GiftRemoteDataSourceImpl implements GiftRemoteDataSource {
  final SupabaseClient client;
  GiftRemoteDataSourceImpl(this.client);
  @override
  Future<GiftTransactionModel> recordGiftTransaction(
      {required String giftId,
      required String fromUid,
      required String toUid,
      required int pricePoints,
      String? roomId}) async {
    try {
      if (client.auth.currentUser?.id != fromUid) {
        throw const ServerException(message: 'FORBIDDEN', code: 'FORBIDDEN');
      }
      final data = Map<String, dynamic>.from(await client
          .rpc('send_gift_atomic', params: {
        'p_to_uid': toUid,
        'p_gift_id': giftId,
        'p_request_id': const Uuid().v4(),
        // معرّف الغرفة اختياري: عند إرساله ينشر الخادم إعلان الهدية في
        // الغرفة نفسها ("قام فلان بإرسال هدية إلى فلان") إضافةً لإشعار
        // المستقبِل. من محادثة خاصة يبقى null فلا يتغيّر أي سلوك قائم.
        'p_room_id': roomId,
      }) as Map);
      return GiftTransactionModel(
          id: data['transactionId'].toString(),
          giftId: giftId,
          fromUid: data['fromUid']?.toString() ?? fromUid,
          toUid: data['toUid']?.toString() ?? toUid,
          pricePoints: (data['pricePaid'] as num?)?.toInt() ?? pricePoints,
          createdAt: DateTime.now());
    } on PostgrestException catch (e) {
      throw ServerException(message: _err(e), code: e.code);
    }
  }

  @override
  Stream<GiftTransactionModel> watchIncomingGifts(String uid) => client
      .from('gift_transactions')
      .stream(primaryKey: ['id'])
      .eq('to_uid', uid)
      .order('created_at', ascending: true)
      .map((rows) => rows
          .map((r) => GiftTransactionModel(
              id: r['id'].toString(),
              giftId: r['gift_id'].toString(),
              fromUid: r['from_uid'].toString(),
              toUid: r['to_uid'].toString(),
              pricePoints: (r['price_points'] as num?)?.toInt() ?? 0,
              createdAt: DateTime.tryParse(r['created_at']?.toString() ?? '') ??
                  DateTime.now()))
          .toList())
      .expand((x) => x);
  String _err(PostgrestException e) => switch (e.message) {
        'INSUFFICIENT_POINTS' => 'رصيد النقاط غير كافٍ.',
        'GIFT_NOT_FOUND' => 'الهدية غير متاحة.',
        'INVALID_PARTICIPANT' => 'المستلم غير صالح.',
        'FORBIDDEN' => 'لا تملك صلاحية إرسال الهدية.',
        'REQUEST_ID_REQUIRED' => 'الطلب غير صالح.',
        'AUTH_REQUIRED' => 'انتهت جلسة الدخول.',
        _ => e.message
      };
}
