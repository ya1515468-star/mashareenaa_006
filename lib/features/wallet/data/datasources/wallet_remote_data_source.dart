import '../../../../core/data/supabase_document_compat.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/currency.dart';
import '../../domain/entities/ledger_entry_entity.dart';
import '../models/ledger_entry_model.dart';
import '../models/wallet_model.dart';

abstract class WalletRemoteDataSource {
  Future<WalletModel> getWallet(String uid);
  Stream<WalletModel> watchWallet(String uid);
  Future<List<LedgerEntryModel>> getHistory(String uid, {int limit = 50});
  Future<void> transfer({
    required String fromUid,
    required String toUid,
    required Money amount,
    String? note,
  });
  Future<void> credit({
    required String uid,
    required Money amount,
    required LedgerEntryType type,
    String? note,
  });
  Future<void> debit({
    required String uid,
    required Money amount,
    required LedgerEntryType type,
    String? note,
  });
}

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final SupabaseDocumentStore store;

  WalletRemoteDataSourceImpl(this.store);

  DocumentReference<Map<String, dynamic>> _accountDoc(String uid) =>
      store.collection(BackendCollections.accounts).doc(uid);

  CollectionReference<Map<String, dynamic>> _ledger(String uid) =>
      _accountDoc(uid).collection('ledger');

  @override
  Future<WalletModel> getWallet(String uid) async {
    try {
      final doc = await _accountDoc(uid).get();
      if (!doc.exists) return WalletModel.fromMap(uid, const {});
      return WalletModel.fromMap(uid, doc.data()!);
    } catch (e) {
      throw ServerException(message: 'تعذّر جلب المحفظة: $e');
    }
  }

  @override
  Stream<WalletModel> watchWallet(String uid) {
    return _accountDoc(uid).snapshots().map((doc) {
      if (!doc.exists) return WalletModel.fromMap(uid, const {});
      return WalletModel.fromMap(uid, doc.data()!);
    });
  }

  @override
  Future<List<LedgerEntryModel>> getHistory(String uid,
      {int limit = 50}) async {
    try {
      final snap = await _ledger(uid)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs
          .map((d) => LedgerEntryModel.fromMap(
              d.id, Map<String, dynamic>.from(d.data())))
          .toList();
    } catch (e) {
      throw ServerException(message: 'تعذّر جلب سجل المعاملات: $e');
    }
  }

  @override
  Future<void> transfer(
      {required String fromUid,
      required String toUid,
      required Money amount,
      String? note}) async {
    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('walletOperation')
          .call({
        'operation': 'transfer',
        'targetUid': toUid,
        'currency': amount.currency == Currency.shamCash ? 'shamCash' : 'usd',
        'amountMinorUnits': amount.minorUnits,
        'note': note,
        'type': 'transfer',
        'requestId': const Uuid().v4(),
      });
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'تعذّر إتمام التحويل', code: e.code);
    }
  }

  @override
  Future<void> credit(
      {required String uid,
      required Money amount,
      required LedgerEntryType type,
      String? note}) async {
    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('walletOperation')
          .call({
        'operation': 'credit',
        'targetUid': uid,
        'currency': amount.currency == Currency.shamCash ? 'shamCash' : 'usd',
        'amountMinorUnits': amount.minorUnits,
        'note': note,
        'type': type.name,
        'requestId': const Uuid().v4(),
      });
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'تعذّر إضافة الرصيد', code: e.code);
    }
  }

  @override
  Future<void> debit(
      {required String uid,
      required Money amount,
      required LedgerEntryType type,
      String? note}) async {
    try {
      await SupabaseFunctionsCompat.instance
          .httpsCallable('walletOperation')
          .call({
        'operation': 'debit',
        'targetUid': uid,
        'currency': amount.currency == Currency.shamCash ? 'shamCash' : 'usd',
        'amountMinorUnits': amount.minorUnits,
        'note': note,
        'type': type.name,
        'requestId': const Uuid().v4(),
      });
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
          message: e.message ?? 'لم تكتمل عملية الخصم', code: e.code);
    }
  }
}
