import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class Timestamp {
  final DateTime _value;
  Timestamp(this._value);
  factory Timestamp.now() => Timestamp(DateTime.now().toUtc());
  factory Timestamp.fromDate(DateTime value) => Timestamp(value.toUtc());
  factory Timestamp.fromMillis(int millis) =>
      Timestamp(DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true));
  DateTime toDate() => _value.toLocal();
  int toMillis() => _value.millisecondsSinceEpoch;
  @override
  String toString() => _value.toIso8601String();
}

class FieldValue {
  final String _op;
  final dynamic value;
  const FieldValue._(this._op, [this.value]);
  static const FieldValue _serverTimestamp = FieldValue._('serverTimestamp');
  static const FieldValue _delete = FieldValue._('delete');
  static FieldValue serverTimestamp() => _serverTimestamp;
  static FieldValue delete() => _delete;
  static FieldValue increment(num value) => FieldValue._('increment', value);
  static FieldValue arrayUnion(List<dynamic> value) =>
      FieldValue._('arrayUnion', value);
  static FieldValue arrayRemove(List<dynamic> value) =>
      FieldValue._('arrayRemove', value);
}

class SetOptions {
  final bool merge;
  const SetOptions({this.merge = false});
}

class QueryDocumentSnapshot<T extends Map<String, dynamic>>
    extends DocumentSnapshot<T> {
  final T _queryData;

  QueryDocumentSnapshot({
    required super.id,
    required T data,
    required super.reference,
  })  : _queryData = data,
        super(data: data);

  @override
  T data() => _queryData;
}

class DocumentSnapshot<T extends Map<String, dynamic>> {
  final String id;
  final T? _data;
  final DocumentReference<T> reference;
  DocumentSnapshot(
      {required this.id, required T? data, required this.reference})
      : _data = data;
  bool get exists => _data != null;
  T? data() => _data;
}

class QueryDocumentChange<T extends Map<String, dynamic>> {
  final QueryDocumentSnapshot<T> doc;
  final DocumentChangeType type;
  const QueryDocumentChange({required this.doc, required this.type});
}

enum DocumentChangeType { added, modified, removed }

class QuerySnapshot<T extends Map<String, dynamic>> {
  final List<QueryDocumentSnapshot<T>> docs;
  QuerySnapshot(this.docs);
  List<QueryDocumentChange<T>> get docChanges => docs
      .map((doc) =>
          QueryDocumentChange<T>(doc: doc, type: DocumentChangeType.added))
      .toList(growable: false);
}

class DocumentReference<T extends Map<String, dynamic>> {
  final SupabaseDocumentStore _store;
  final String collectionPath;
  final String id;
  DocumentReference(this._store, this.collectionPath, this.id);

  CollectionReference<T> collection(String child) =>
      CollectionReference<T>(_store, '$collectionPath/$id/$child');

  Future<DocumentSnapshot<T>> get() async {
    final row = await _store.getDoc(collectionPath, id);
    return DocumentSnapshot<T>(
        id: id,
        data: row == null ? null : Map<String, dynamic>.from(row) as T,
        reference: this);
  }

  Stream<DocumentSnapshot<T>> snapshots() async* {
    await for (final event in _store.watchCollection(collectionPath)) {
      final row = event.firstWhere((r) => r['doc_id']?.toString() == id,
          orElse: () => <String, dynamic>{});
      final data = row.isEmpty
          ? null
          : _store.decodeMap(Map<String, dynamic>.from(row['data'] as Map));
      yield DocumentSnapshot<T>(
          id: id,
          data: data == null ? null : Map<String, dynamic>.from(data) as T,
          reference: this);
    }
  }

  Future<void> set(Map<String, dynamic> data,
      [SetOptions options = const SetOptions()]) async {
    final current = options.merge
        ? await _store.getDoc(collectionPath, id) ?? <String, dynamic>{}
        : <String, dynamic>{};
    final resolved = await _store.resolveOperations(data, current);
    final merged = options.merge ? {...current, ...resolved} : resolved;
    await _store.putDoc(collectionPath, id, merged);
  }

  Future<void> update(Map<String, dynamic> data) async {
    final current =
        await _store.getDoc(collectionPath, id) ?? <String, dynamic>{};
    final resolved = await _store.resolveOperations(data, current);
    await _store.putDoc(collectionPath, id, {...current, ...resolved});
  }

  Future<void> delete() => _store.deleteDoc(collectionPath, id);
}

class CollectionReference<T extends Map<String, dynamic>> extends Query<T> {
  CollectionReference(super.store, super.path);
  DocumentReference<T> doc([String? id]) =>
      DocumentReference<T>(_store, path, id ?? _store.newId());
  Future<DocumentReference<T>> add(Map<String, dynamic> data) async {
    final ref = doc();
    await ref.set(data);
    return ref;
  }
}

enum FilterOp {
  equal,
  notEqual,
  arrayContains,
  arrayContainsAny,
  greaterThan,
  lessThan,
  greaterOrEqual,
  lessOrEqual
}

class Filter {
  final String field;
  final FilterOp op;
  final dynamic value;
  const Filter(this.field, this.op, this.value);
}

class Query<T extends Map<String, dynamic>> {
  final SupabaseDocumentStore _store;
  final String path;
  final List<Filter> _filters;
  final String? _orderField;
  final bool _descending;
  final int? _limit;
  final dynamic _startAt;
  final dynamic _endAt;

  Query(
    this._store,
    this.path, {
    List<Filter>? filters,
    String? orderField,
    bool descending = false,
    int? limit,
    dynamic startAt,
    dynamic endAt,
  })  : _filters = filters ?? const [],
        _orderField = orderField,
        _descending = descending,
        _limit = limit,
        _startAt = startAt,
        _endAt = endAt;

  Query<T> where(String field,
      {dynamic isEqualTo,
      dynamic isNotEqualTo,
      dynamic arrayContains,
      Iterable<dynamic>? arrayContainsAny,
      dynamic isGreaterThan,
      dynamic isLessThan,
      dynamic isGreaterThanOrEqualTo,
      dynamic isLessThanOrEqualTo}) {
    final additions = <Filter>[];
    if (isEqualTo != null) {
      additions.add(Filter(field, FilterOp.equal, isEqualTo));
    }
    if (isNotEqualTo != null) {
      additions.add(Filter(field, FilterOp.notEqual, isNotEqualTo));
    }
    if (arrayContains != null) {
      additions.add(Filter(field, FilterOp.arrayContains, arrayContains));
    }
    if (arrayContainsAny != null) {
      additions.add(Filter(field, FilterOp.arrayContainsAny,
          List<dynamic>.from(arrayContainsAny)));
    }
    if (isGreaterThan != null) {
      additions.add(Filter(field, FilterOp.greaterThan, isGreaterThan));
    }
    if (isLessThan != null) {
      additions.add(Filter(field, FilterOp.lessThan, isLessThan));
    }
    if (isGreaterThanOrEqualTo != null) {
      additions
          .add(Filter(field, FilterOp.greaterOrEqual, isGreaterThanOrEqualTo));
    }
    if (isLessThanOrEqualTo != null) {
      additions.add(Filter(field, FilterOp.lessOrEqual, isLessThanOrEqualTo));
    }
    return Query<T>(
      _store,
      path,
      filters: [..._filters, ...additions],
      orderField: _orderField,
      descending: _descending,
      limit: _limit,
      startAt: _startAt,
      endAt: _endAt,
    );
  }

  Query<T> orderBy(String field, {bool descending = false}) => Query<T>(
        _store,
        path,
        filters: _filters,
        orderField: field,
        descending: descending,
        limit: _limit,
        startAt: _startAt,
        endAt: _endAt,
      );

  Query<T> limit(int value) => Query<T>(
        _store,
        path,
        filters: _filters,
        orderField: _orderField,
        descending: _descending,
        limit: value,
        startAt: _startAt,
        endAt: _endAt,
      );

  Query<T> startAt(List<dynamic> values) => Query<T>(
        _store,
        path,
        filters: _filters,
        orderField: _orderField,
        descending: _descending,
        limit: _limit,
        startAt: values.isEmpty ? null : values.first,
        endAt: _endAt,
      );

  Query<T> endAt(List<dynamic> values) => Query<T>(
        _store,
        path,
        filters: _filters,
        orderField: _orderField,
        descending: _descending,
        limit: _limit,
        startAt: _startAt,
        endAt: values.isEmpty ? null : values.first,
      );

  Future<QuerySnapshot<T>> get() async {
    final rows = await _store.getCollection(path);
    final docs = _apply(rows).map((row) {
      final data =
          _store.decodeMap(Map<String, dynamic>.from(row['data'] as Map));
      return QueryDocumentSnapshot<T>(
          id: row['doc_id']?.toString() ?? '',
          data: Map<String, dynamic>.from(data) as T,
          reference: DocumentReference<T>(
              _store, path, row['doc_id']?.toString() ?? ''));
    }).toList();
    return QuerySnapshot<T>(docs);
  }

  Stream<QuerySnapshot<T>> snapshots() async* {
    await for (final rows in _store.watchCollection(path)) {
      final docs = _apply(rows).map((row) {
        final data =
            _store.decodeMap(Map<String, dynamic>.from(row['data'] as Map));
        return QueryDocumentSnapshot<T>(
            id: row['doc_id']?.toString() ?? '',
            data: Map<String, dynamic>.from(data) as T,
            reference: DocumentReference<T>(
                _store, path, row['doc_id']?.toString() ?? ''));
      }).toList();
      yield QuerySnapshot<T>(docs);
    }
  }

  Stream<int> count() async* {
    await for (final snap in snapshots()) {
      yield snap.docs.length;
    }
  }

  List<Map<String, dynamic>> _apply(List<Map<String, dynamic>> input) {
    var rows = input
        .where((row) => _filters.every((f) => _matches(
            _store.getField(
                _store.decodeMap(Map<String, dynamic>.from(row['data'] as Map)),
                f.field),
            f)))
        .toList();
    if (_orderField != null) {
      final field = _orderField;
      rows.sort((a, b) {
        final av = _store.getField(
            _store.decodeMap(Map<String, dynamic>.from(a['data'] as Map)),
            field);
        final bv = _store.getField(
            _store.decodeMap(Map<String, dynamic>.from(b['data'] as Map)),
            field);
        final c = _compareValues(av, bv);
        return _descending ? -c : c;
      });

      if (_startAt != null) {
        rows = rows.where((row) {
          final value = _store.getField(
            _store.decodeMap(Map<String, dynamic>.from(row['data'] as Map)),
            field,
          );
          return _compareValues(value, _startAt) >= 0;
        }).toList();
      }
      if (_endAt != null) {
        rows = rows.where((row) {
          final value = _store.getField(
            _store.decodeMap(Map<String, dynamic>.from(row['data'] as Map)),
            field,
          );
          return _compareValues(value, _endAt) <= 0;
        }).toList();
      }
    }
    if (_limit != null && rows.length > _limit) {
      rows = rows.take(_limit).toList();
    }
    return rows;
  }

  bool _matches(dynamic actual, Filter f) {
    switch (f.op) {
      case FilterOp.equal:
        return _equivalent(actual, f.value);
      case FilterOp.notEqual:
        return !_equivalent(actual, f.value);
      case FilterOp.arrayContains:
        return actual is List && actual.any((e) => _equivalent(e, f.value));
      case FilterOp.arrayContainsAny:
        return actual is List &&
            f.value is List &&
            actual.any((e) => (f.value as List).any((x) => _equivalent(e, x)));
      case FilterOp.greaterThan:
        return _compareValues(actual, f.value) > 0;
      case FilterOp.lessThan:
        return _compareValues(actual, f.value) < 0;
      case FilterOp.greaterOrEqual:
        return _compareValues(actual, f.value) >= 0;
      case FilterOp.lessOrEqual:
        return _compareValues(actual, f.value) <= 0;
    }
  }

  bool _equivalent(dynamic a, dynamic b) {
    if (a is Timestamp && b is Timestamp) return a.toMillis() == b.toMillis();
    if (a is Timestamp && b is DateTime) {
      return a.toMillis() == b.millisecondsSinceEpoch;
    }
    if (a is DateTime && b is Timestamp) {
      return a.millisecondsSinceEpoch == b.toMillis();
    }
    return a.toString() == b.toString();
  }

  int _compareValues(dynamic a, dynamic b) {
    dynamic normalize(dynamic value) {
      if (value is Timestamp) return value.toMillis();
      if (value is DateTime) return value.millisecondsSinceEpoch;
      if (value is num) return value;
      return value == null ? '' : value.toString();
    }

    final av = normalize(a);
    final bv = normalize(b);
    if (av is num && bv is num) return av.compareTo(bv);
    return av.toString().compareTo(bv.toString());
  }
}

class Transaction {
  final List<Future<void> Function()> _ops = [];
  Transaction(SupabaseDocumentStore _);
  Future<DocumentSnapshot<T>> get<T extends Map<String, dynamic>>(
          DocumentReference<T> ref) =>
      ref.get();
  void update<T extends Map<String, dynamic>>(
          DocumentReference<T> ref, Map<String, dynamic> data) =>
      _ops.add(() => ref.update(data));
  void set<T extends Map<String, dynamic>>(
          DocumentReference<T> ref, Map<String, dynamic> data,
          [SetOptions options = const SetOptions()]) =>
      _ops.add(() => ref.set(data, options));
  void delete<T extends Map<String, dynamic>>(DocumentReference<T> ref) =>
      _ops.add(ref.delete);
  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class WriteBatch {
  final List<Future<void> Function()> _ops = [];
  WriteBatch(SupabaseDocumentStore _);
  void set<T extends Map<String, dynamic>>(
          DocumentReference<T> ref, Map<String, dynamic> data,
          [SetOptions options = const SetOptions()]) =>
      _ops.add(() => ref.set(data, options));
  void update<T extends Map<String, dynamic>>(
          DocumentReference<T> ref, Map<String, dynamic> data) =>
      _ops.add(() => ref.update(data));
  void delete<T extends Map<String, dynamic>>(DocumentReference<T> ref) =>
      _ops.add(ref.delete);
  Future<void> commit() async {
    for (final op in _ops) {
      await op();
    }
  }
}

class SupabaseDocumentStore {
  static final SupabaseDocumentStore instance = SupabaseDocumentStore._();
  SupabaseDocumentStore._();
  SupabaseClient get _client => Supabase.instance.client;
  String? get currentUserId => _client.auth.currentUser?.id;
  Future<dynamic> rpc(String fn, {Map<String, dynamic>? params}) =>
      _client.rpc(fn, params: params ?? const <String, dynamic>{});
  String newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Object.hash(DateTime.now(), this).abs()}';

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      CollectionReference<Map<String, dynamic>>(this, path);
  WriteBatch batch() => WriteBatch(this);
  Future<T> runTransaction<T>(Future<T> Function(Transaction tx) action) async {
    final tx = Transaction(this);
    final result = await action(tx);
    await tx.commit();
    return result;
  }

  Future<List<Map<String, dynamic>>> getCollection(String path) async {
    final response = await _client
        .from('app_documents')
        .select('doc_id,data')
        .eq('collection_path', path);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> watchCollection(String path) {
    return _client
        .from('app_documents')
        .stream(primaryKey: ['id'])
        .eq('collection_path', path)
        .map((rows) => rows.map((r) => Map<String, dynamic>.from(r)).toList());
  }

  Future<Map<String, dynamic>?> getDoc(String path, String id) async {
    final row = await _client
        .from('app_documents')
        .select('data')
        .eq('collection_path', path)
        .eq('doc_id', id)
        .maybeSingle();
    if (row == null) return null;
    return decodeMap(Map<String, dynamic>.from(row['data'] as Map));
  }

  Future<void> putDoc(String path, String id, Map<String, dynamic> data) async {
    await _client.from('app_documents').upsert({
      'collection_path': path,
      'doc_id': id,
      'owner_id': Supabase.instance.client.auth.currentUser?.id,
      'data': encodeValue(data),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'collection_path,doc_id');
  }

  Future<void> deleteDoc(String path, String id) async => _client
      .from('app_documents')
      .delete()
      .eq('collection_path', path)
      .eq('doc_id', id);

  dynamic getField(Map<String, dynamic> data, String field) {
    dynamic current = data;
    for (final part in field.split('.')) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  Future<Map<String, dynamic>> resolveOperations(
      Map<String, dynamic> data, Map<String, dynamic> current) async {
    final out = <String, dynamic>{};
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is FieldValue) {
        switch (value._op) {
          case 'serverTimestamp':
            out[entry.key] = Timestamp.now();
            break;
          case 'delete':
            out.remove(entry.key);
            break;
          case 'increment':
            out[entry.key] =
                ((current[entry.key] as num?) ?? 0) + (value.value as num);
            break;
          case 'arrayUnion':
            final list = List<dynamic>.from(current[entry.key] is List
                ? current[entry.key] as List
                : const []);
            for (final x in (value.value as List)) {
              if (!list.any((e) => e.toString() == x.toString())) list.add(x);
            }
            out[entry.key] = list;
            break;
          case 'arrayRemove':
            final remove =
                (value.value as List).map((e) => e.toString()).toSet();
            final list = List<dynamic>.from(current[entry.key] is List
                ? current[entry.key] as List
                : const []);
            out[entry.key] =
                list.where((e) => !remove.contains(e.toString())).toList();
            break;
        }
      } else {
        out[entry.key] = _resolveNested(value);
      }
    }
    return out;
  }

  dynamic _resolveNested(dynamic value) {
    if (value is FieldValue) return Timestamp.now();
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _resolveNested(v)));
    }
    if (value is List) return value.map(_resolveNested).toList();
    return value;
  }

  dynamic encodeValue(dynamic value) {
    if (value is Timestamp) {
      return {'__timestamp': value.toDate().toUtc().toIso8601String()};
    }
    if (value is DateTime) {
      return {'__timestamp': value.toUtc().toIso8601String()};
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), encodeValue(v)));
    }
    if (value is List) return value.map(encodeValue).toList();
    return value;
  }

  dynamic decodeValue(dynamic value) {
    if (value is Map && value.length == 1 && value['__timestamp'] is String) {
      return Timestamp.fromDate(DateTime.parse(value['__timestamp'] as String));
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), decodeValue(v)));
    }
    if (value is List) return value.map(decodeValue).toList();
    return value;
  }

  Map<String, dynamic> decodeMap(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(decodeValue(data) as Map);
}

class SupabaseAuthUserCompat {
  final String uid;
  final String? email;
  SupabaseAuthUserCompat({required this.uid, this.email});
}

class SupabaseAuthCompat {
  static final SupabaseAuthCompat instance = SupabaseAuthCompat._();
  SupabaseAuthCompat._();
  SupabaseAuthUserCompat? get currentUser {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    return SupabaseAuthUserCompat(uid: user.id, email: user.email);
  }
}

class SupabaseFunctionException implements Exception {
  final String code;
  final String? message;
  SupabaseFunctionException({required this.code, this.message});
  @override
  String toString() => message ?? code;
}

class HttpsCallableResult {
  final dynamic data;
  HttpsCallableResult(this.data);
}

class HttpsCallable {
  final String name;
  HttpsCallable(this.name);
  Future<HttpsCallableResult> call([dynamic data]) async {
    final client = Supabase.instance.client;
    final payload =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    try {
      dynamic result;
      switch (name) {
        case 'purchaseStoreItem':
          result = await client.rpc('purchase_store_item',
              params: _params(
                  payload, {'p_item_id': 'itemId', 'p_quantity': 'quantity'}));
          break;
        case 'purchaseMembership':
          result = await client.rpc('purchase_membership',
              params: _params(payload,
                  {'p_tier_id': 'tierId', 'p_request_id': 'requestId'}));
          break;
        case 'adminGrantMembershipTier':
          result = await client.rpc('admin_grant_membership_tier',
              params: _params(payload,
                  {'p_target_uid': 'targetUid', 'p_tier_id': 'tierId', 'p_request_id': 'requestId'}));
          break;
        case 'adminUpdateMembershipPrice':
          result = await client.rpc('admin_update_membership_price',
              params: _params(payload, {
                'p_tier_id': 'tierId',
                'p_price_minor_units': 'priceMinorUnits'
              }));
          break;
        case 'adminGrantMembership':
          result = await client.rpc('admin_grant_membership',
              params: _params(payload, {
                'p_target_uid': 'targetUid',
                'p_feature_key': 'featureKey',
                'p_enabled': 'enabled'
              }));
          break;
        case 'adminGrantStoreItem':
          result = await client.rpc('dragon_grant_store_item',
              params: _params(payload,
                  {'p_target_user_id': 'targetUid', 'p_item_id': 'itemId'}));
          break;
        case 'adminGrantPointsPackage':
          result = await client.rpc(
            'admin_grant_points_package',
            params: {
              'p_target_user_id': payload['targetUid'],
              'p_package_id': payload['packageId'],
              'p_request_id': payload['requestId'] ?? const Uuid().v4(),
            },
          );
          break;
        case 'adminCreatePointsPackage':
          result = await client.rpc(
            'admin_create_points_package',
            params: {
              'p_package_id': payload['id'],
              'p_title': payload['title'],
              'p_points_granted': payload['pointsGranted'],
              'p_category': payload['category'],
              'p_rarity': payload['rarity'],
              'p_icon': payload['icon'],
              'p_is_featured': payload['isFeatured'] ?? false,
              'p_enabled': payload['enabled'] ?? true,
              'p_price_minor_units': payload['priceMinorUnits'],
              'p_currency': payload['currency'] ?? 'shamCash',
            },
          );
          break;
        case 'applyReferral':
          result = await client.rpc('apply_referral', params: {
            'p_referrer_username': payload['referrerUsername'],
            'p_request_id': payload['requestId'] ?? const Uuid().v4(),
          });
          break;
        case 'sendGift':
          result = await client.rpc('send_gift', params: {
            'p_to_uid': payload['toUid'],
            'p_gift_id': payload['giftId'],
            'p_request_id': payload['requestId'] ?? const Uuid().v4(),
          });
          break;
        case 'gamificationAction':
          result = await client.rpc('gamification_action', params: {
            'p_action': payload['action'],
            'p_request_id': payload['requestId'] ?? const Uuid().v4(),
          });
          break;
        case 'usernameCredentialAction':
          result = await client.rpc('username_credential_action', params: {
            'p_action': payload['action'],
            'p_username': payload['username'],
            'p_pin': payload['pin'],
            'p_request_id': payload['requestId'] ?? const Uuid().v4(),
          });
          break;
        case 'sendVerificationCode':
          await client.auth.resend(
            type: OtpType.signup,
            email: (payload['email'] ?? '').toString(),
          );
          result = {'sent': true};
          break;
        case 'confirmVerificationCode':
          final user = client.auth.currentUser;
          result = {'verified': user?.emailConfirmedAt != null};
          break;
        case 'walletOperation':
          result = await client.rpc('wallet_operation', params: {
            'p_operation': payload['operation'],
            'p_target_uid': payload['targetUid'],
            'p_currency': payload['currency'] ?? 'shamCash',
            'p_amount_minor_units': payload['amountMinorUnits'],
            'p_note': payload['note'],
            'p_type': payload['type'] ?? 'manual',
            'p_request_id': payload['requestId'] ?? const Uuid().v4(),
          });
          break;

        default:
          throw SupabaseFunctionException(
              code: 'unimplemented', message: 'عملية الخادم غير مهيأة: $name');
      }
      return HttpsCallableResult(result);
    } on PostgrestException catch (e) {
      throw SupabaseFunctionException(
          code: e.code ?? 'unknown', message: e.message);
    }
  }

  static Map<String, dynamic> _params(
      Map<String, dynamic> payload, Map<String, String> mapping) {
    final out = <String, dynamic>{};
    for (final e in mapping.entries) {
      out[e.key] = payload[e.value];
    }
    return out;
  }
}

class SupabaseFunctionsCompat {
  static final SupabaseFunctionsCompat instance = SupabaseFunctionsCompat._();
  SupabaseFunctionsCompat._();
  HttpsCallable httpsCallable(String name) => HttpsCallable(name);
}
