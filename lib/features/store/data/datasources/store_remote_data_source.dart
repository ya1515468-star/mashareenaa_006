import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/store_item_entity.dart';
import '../models/store_item_model.dart';

abstract class StoreRemoteDataSource {
  Future<List<StoreItemModel>> listCatalog();

  Future<void> updateItem({
    required String itemId,
    required int pricePoints,
    required int priceGems,
    required bool enabled,
    required String updatedBy,
  });

  Future<void> purchaseItem({
    required String uid,
    required String itemId,
  });

  Future<void> createItem({
    required StoreItemEntity item,
    required String createdBy,
  });

  Future<void> grantItem({
    required String targetUid,
    required String itemId,
    required String performedBy,
  });

  Stream<List<String>> watchOwnedItemIds(String uid);

  Stream<List<StoreItemModel>> watchCatalog();
}

class StoreRemoteDataSourceImpl implements StoreRemoteDataSource {
  final SupabaseClient supabase;

  StoreRemoteDataSourceImpl(this.supabase);
  @override
  Future<void> updateItem({
    required String itemId,
    required int pricePoints,
    required int priceGems,
    required bool enabled,
    required String updatedBy,
  }) async {
    try {
      final parsedId = int.tryParse(itemId);

      var itemDbId = parsedId;

      if (itemDbId == null) {
        final row = await supabase
            .from('store_items')
            .select('id')
            .eq('code', itemId)
            .maybeSingle();

        if (row == null || row['id'] is! num) {
          throw const ServerException(
            message: 'عنصر المتجر غير موجود.',
            code: 'ITEM_NOT_FOUND',
          );
        }

        itemDbId = (row['id'] as num).toInt();
      }

      await supabase.rpc(
        'dragon_update_store_item',
        params: {
          'p_item_id': itemDbId,
          'p_price_points': pricePoints,
          'p_price_gems': priceGems,
          'p_enabled': enabled,
        },
      );
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر تحديث عنصر المتجر: $e',
      );
    }
  }

  String? _stringValue(dynamic value) {
    if (value == null) {
      return null;
    }

    return value.toString();
  }

  Map<String, dynamic> _normalizeItem(
    Map<String, dynamic> row,
  ) {
    final result = <String, dynamic>{
      ...row,
    };

    result['id'] = row['id'];
    result['sku'] = row['sku'] ?? row['code'];

    final metadata = row['metadata'];

    if (metadata is Map) {
      for (final entry in metadata.entries) {
        result.putIfAbsent(
          entry.key.toString(),
          () => entry.value,
        );
      }
    }

    final sectionRaw = row['store_sections'];

    String? sectionCode;

    if (sectionRaw is Map) {
      sectionCode = sectionRaw['code']?.toString().trim().toLowerCase();
    }

    if (sectionRaw is List && sectionRaw.isNotEmpty) {
      final first = sectionRaw.first;

      if (first is Map) {
        sectionCode = first['code']?.toString().trim().toLowerCase();
      }
    }

    final derivedCategory = switch (sectionCode) {
      'glows' => 'usernameGlow',
      'frames' => 'avatarFrame',
      'backgrounds' => 'animatedBackground',
      'points_gems' => 'currency',
      'features_addons' => 'membership',
      _ => null,
    };

    if (derivedCategory != null) {
      result['category'] = derivedCategory;
    }
    final prices = row['store_item_prices'];

    if (prices is List && prices.isNotEmpty) {
      for (final raw in prices) {
        if (raw is! Map) {
          continue;
        }

        final currency = raw['currency']?.toString();
        final amount = (raw['amount'] as num?)?.toInt();

        if (currency == 'points' && amount != null) {
          result['pricePoints'] = amount;
        }

        if (currency == 'gems' && amount != null) {
          result['priceGems'] = amount;
        }
      }
    }

    result['enabled'] = row['is_active'] ?? row['enabled'] ?? true;

    result['limited'] = row['is_limited'] ?? row['limited'] ?? false;

    result['stock'] = row['stock_quantity'] ?? row['stock'];

    result['nameAr'] = row['nameAr'] ?? row['name'] ?? '';

    result['assetUrl'] = row['asset_url'] ?? row['assetUrl'];

    result['assetType'] = row['asset_type'] ?? row['assetType'] ?? 'gif';

    result['previewAsset'] =
        row['preview_asset'] ?? row['previewAsset'] ?? result['assetUrl'];

    return result;
  }

  @override
  Future<List<StoreItemModel>> listCatalog() async {
    try {
      final response = await supabase.from('store_items').select('''
            id,
            code,
            name,
            description,
            item_type,
            asset_url,
            metadata,
            is_active,
            is_limited,
            stock_quantity,
            sort_order,
            store_sections(
              id,
              code,
              name
            ),
            store_item_prices(
              id,
              currency,
              amount,
              is_active,
              effective_from,
              effective_until
            )
          ''').eq('is_active', true).order('sort_order');

      final rows = List<Map<String, dynamic>>.from(
        response,
      );

      if (rows.isEmpty) {
        return const <StoreItemModel>[];
      }

      return rows.map((row) {
        final normalized = _normalizeItem(row);

        final code = _stringValue(row['code']) ?? _stringValue(row['id']) ?? '';

        return StoreItemModel.fromMap(
          code,
          normalized,
        );
      }).toList(growable: false);
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'تعذّر جلب كتالوج المتجر: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر جلب كتالوج المتجر: $e',
      );
    }
  }

  @override
  Future<void> purchaseItem({
    required String uid,
    required String itemId,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        throw const ServerException(
          message: 'جلسة Supabase غير موجودة.',
          code: 'AUTH_REQUIRED',
        );
      }

      final row = await Supabase.instance.client
          .from('store_items')
          .select('id')
          .eq('code', itemId)
          .eq('is_active', true)
          .maybeSingle();

      if (row == null) {
        throw const ServerException(
          message: 'عنصر المتجر غير موجود.',
          code: 'ITEM_NOT_FOUND',
        );
      }

      final rawId = row['id'];

      if (rawId is! num) {
        throw const ServerException(
          message: 'معرّف عنصر المتجر غير صالح.',
          code: 'INVALID_ITEM_ID',
        );
      }

      await Supabase.instance.client.rpc(
        'purchase_store_item',
        params: {
          'p_item_id': rawId.toInt(),
          'p_quantity': 1,
          'p_request_id': const Uuid().v4(),
        },
      );
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      final message = switch (e.message) {
        'INSUFFICIENT_POINTS' => 'رصيد النقاط غير كافٍ.',
        'INSUFFICIENT_GEMS' => 'رصيد الجواهر غير كافٍ.',
        'ITEM_NOT_AVAILABLE' => 'العنصر غير متاح حاليًا.',
        'PRICE_NOT_AVAILABLE' => 'سعر العنصر غير متاح حاليًا.',
        'INSUFFICIENT_STOCK' => 'المخزون غير كافٍ.',
        'POINTS_WALLET_NOT_FOUND' => 'محفظة النقاط غير موجودة.',
        'GEMS_WALLET_NOT_FOUND' => 'محفظة الجواهر غير موجودة.',
        _ => e.message,
      };

      throw ServerException(
        message: message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر شراء عنصر المتجر: $e',
      );
    }
  }

  @override
  Future<void> createItem({
    required StoreItemEntity item,
    required String createdBy,
  }) async {
    try {
      final section = await supabase
          .from('store_sections')
          .select('id')
          .eq('code', item.category.wire)
          .maybeSingle();

      if (section == null) {
        throw const ServerException(
          message: 'قسم المتجر غير موجود.',
          code: 'SECTION_NOT_FOUND',
        );
      }

      await supabase.rpc(
        'dragon_create_store_item',
        params: {
          'p_section_id': section['id'],
          'p_code': item.id,
          'p_name': item.nameAr,
          'p_description': null,
          'p_item_type': item.assetType,
          'p_asset_url': item.assetUrl,
          'p_metadata': StoreItemModel.fromEntity(item).toMap(),
          'p_is_active': item.enabled,
          'p_is_limited': item.limited,
          'p_stock_quantity': item.stock,
          'p_sort_order': item.sortOrder,
          'p_price_points': item.pricePoints,
          'p_price_gems': item.priceGems,
        },
      );
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر إنشاء عنصر المتجر: $e',
      );
    }
  }

  @override
  Future<void> grantItem({
    required String targetUid,
    required String itemId,
    required String performedBy,
  }) async {
    try {
      final item = await supabase
          .from('store_items')
          .select('id')
          .eq('code', itemId)
          .maybeSingle();

      if (item == null) {
        throw const ServerException(
          message: 'عنصر المتجر غير موجود.',
          code: 'ITEM_NOT_FOUND',
        );
      }

      await supabase.rpc(
        'dragon_grant_store_item',
        params: {
          'p_target_user_id': targetUid,
          'p_item_id': item['id'],
        },
      );
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر إهداء العنصر: $e',
      );
    }
  }

  @override
  Stream<List<StoreItemModel>> watchCatalog() async* {
    yield await listCatalog();

    await for (final _ in supabase
        .from('store_items')
        .stream(primaryKey: ['id']).eq('is_active', true)) {
      // Keep the catalog query as the single source of truth so nested
      // section/price relations are always refreshed after a Realtime event.
      yield await listCatalog();
    }
  }

  @override
  Stream<List<String>> watchOwnedItemIds(String uid) {
    return supabase
        .from('user_inventory')
        .stream(primaryKey: ['user_id', 'item_id'])
        .eq('user_id', uid)
        .asyncMap((rows) async {
          if (rows.isEmpty) {
            return const <String>[];
          }

          final itemIds = rows
              .map((row) => row['item_id'])
              .whereType<num>()
              .map((value) => value.toInt())
              .toList(growable: false);

          if (itemIds.isEmpty) {
            return const <String>[];
          }

          final items = await supabase
              .from('store_items')
              .select('id, code')
              .inFilter('id', itemIds);

          final codes = <String>[];

          for (final item in items) {
            final code = item['code']?.toString();

            if (code != null && code.isNotEmpty) {
              codes.add(code);
            }
          }

          return codes;
        });
  }
}
