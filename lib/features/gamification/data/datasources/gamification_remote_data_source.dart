import 'dart:async';
import '../../../../core/data/supabase_document_compat.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/points_package_entity.dart';
import '../models/gamification_stats_model.dart';

abstract class GamificationRemoteDataSource {
  Future<GamificationStatsModel> getStats(String uid);

  Stream<GamificationStatsModel> watchStats(String uid);

  Future<GamificationStatsModel> addXp(
    String uid, {
    required String eventType,
    String? referenceType,
    String? referenceId,
  });

  Future<GamificationStatsModel> claimDailyReward(
    String uid, {
    required int multiplier,
  });

  Future<void> spendPoints({
    required String uid,
    required int amount,
    required bool unlimited,
  });

  Future<void> spendGems({
    required String uid,
    required int amount,
    required bool unlimited,
  });

  Future<void> creditGems({
    required String uid,
    required int amount,
  });

  Future<void> creditPoints({
    required String uid,
    required int amount,
  });

  Future<void> unlockBadge({
    required String uid,
    required String badgeId,
  });

  Future<int> spinMysteryBox(String uid);

  Future<void> transferPoints({
    required String fromUid,
    required String toUid,
    required int amount,
    required bool bypassChecks,
  });

  Future<List<PointsPackageEntity>> listPointsPackages();

  Future<void> updatePointsPackagePrice({
    required String packageId,
    required int priceMinorUnits,
    required bool enabled,
    required String updatedBy,
  });

  Future<GamificationStatsModel> purchasePointsPackage({
    required String uid,
    required String packageId,
  });
}

class GamificationRemoteDataSourceImpl implements GamificationRemoteDataSource {
  final SupabaseClient supabase;

  GamificationRemoteDataSourceImpl(this.supabase);

  Future<Map<String, dynamic>> _loadState(String uid) async {
    final responses = await Future.wait([
      supabase
          .from('gamification_stats')
          .select(
            'user_id, xp, rank_level, rank_id, badges, username_effect, '
            'daily_reward_streak, last_daily_reward_at',
          )
          .eq('user_id', uid)
          .maybeSingle(),
      supabase
          .from('points_wallets')
          .select('user_id, balance')
          .eq('user_id', uid)
          .maybeSingle(),
      supabase
          .from('gems_wallets')
          .select('user_id, balance')
          .eq('user_id', uid)
          .maybeSingle(),
    ]);

    final stats = responses[0];
    final points = responses[1];
    final gems = responses[2];

    if (stats == null && points == null && gems == null) {
      throw const ServerException(
        message: 'الحساب غير موجود',
      );
    }

    return {
      'xp': stats?['xp'] ?? 0,
      'rankLevel': stats?['rank_level'] ?? 1,
      'rankId': stats?['rank_id'] ?? 'rookie',
      'badges': stats?['badges'] ?? const [],
      'usernameEffect': stats?['username_effect'],
      'dailyRewardStreak': stats?['daily_reward_streak'] ?? 0,
      'lastDailyRewardAt': stats?['last_daily_reward_at'],
      'points': points?['balance'] ?? 0,
      'gems': gems?['balance'] ?? 0,
    };
  }

  Future<GamificationStatsModel> _stateFor(
    String uid,
  ) async {
    final map = await _loadState(uid);

    return GamificationStatsModel.fromMap(
      uid,
      map,
    );
  }

  @override
  Future<GamificationStatsModel> getStats(
    String uid,
  ) async {
    try {
      return await _stateFor(uid);
    } on ServerException {
      rethrow;
    } on PostgrestException catch (e) {
      throw ServerException(
        message: 'تعذّر جلب إحصائيات التلعيب: ${e.message}',
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر جلب إحصائيات التلعيب: $e',
      );
    }
  }

  @override
  Stream<GamificationStatsModel> watchStats(
    String uid,
  ) {
    final controller = StreamController<GamificationStatsModel>.broadcast();

    Map<String, dynamic> statsMap = const {};
    Map<String, dynamic> pointsMap = const {};
    Map<String, dynamic> gemsMap = const {};

    StreamSubscription<List<Map<String, dynamic>>>? statsSub;
    StreamSubscription<List<Map<String, dynamic>>>? pointsSub;
    StreamSubscription<List<Map<String, dynamic>>>? gemsSub;

    Future<void> emit() async {
      if (controller.isClosed) {
        return;
      }

      try {
        final combined = <String, dynamic>{
          'xp': statsMap['xp'] ?? 0,
          'rankLevel': statsMap['rank_level'] ?? 1,
          'rankId': statsMap['rank_id'] ?? 'rookie',
          'badges': statsMap['badges'] ?? const [],
          'usernameEffect': statsMap['username_effect'],
          'dailyRewardStreak': statsMap['daily_reward_streak'] ?? 0,
          'lastDailyRewardAt': statsMap['last_daily_reward_at'],
          'points': pointsMap['balance'] ?? 0,
          'gems': gemsMap['balance'] ?? 0,
        };

        controller.add(
          GamificationStatsModel.fromMap(
            uid,
            combined,
          ),
        );
      } catch (e) {
        controller.addError(e);
      }
    }

    statsSub = supabase
        .from('gamification_stats')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .listen((rows) {
          statsMap = rows.isEmpty ? const {} : rows.first;
          emit();
        });

    pointsSub = supabase
        .from('points_wallets')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .listen((rows) {
          pointsMap = rows.isEmpty ? const {} : rows.first;
          emit();
        });

    gemsSub = supabase
        .from('gems_wallets')
        .stream(primaryKey: ['user_id'])
        .eq('user_id', uid)
        .listen((rows) {
          gemsMap = rows.isEmpty ? const {} : rows.first;
          emit();
        });

    controller.onCancel = () async {
      await statsSub?.cancel();
      await pointsSub?.cancel();
      await gemsSub?.cancel();
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Future<void> spendPoints({
    required String uid,
    required int amount,
    required bool unlimited,
  }) async {
    try {
      await supabase.rpc(
        'spend_points',
        params: {
          'p_amount': amount,
          'p_reference_type': 'gamification',
          'p_reference_id': 'spend_points',
          'p_idempotency_key': const Uuid().v4(),
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر خصم النقاط: $e',
      );
    }
  }

  @override
  Future<void> spendGems({
    required String uid,
    required int amount,
    required bool unlimited,
  }) async {
    try {
      await supabase.rpc(
        'spend_gems',
        params: {
          'p_amount': amount,
          'p_reference_type': 'gamification',
          'p_reference_id': 'spend_gems',
          'p_idempotency_key': const Uuid().v4(),
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر خصم الجواهر: $e',
      );
    }
  }

  @override
  Future<void> creditPoints({
    required String uid,
    required int amount,
  }) async {
    try {
      await supabase.rpc(
        'dragon_credit_points',
        params: {
          'p_target_user_id': uid,
          'p_amount': amount,
          'p_reference_type': 'admin_grant',
          'p_reference_id': 'gamification',
          'p_idempotency_key': const Uuid().v4(),
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر إضافة النقاط: $e',
      );
    }
  }

  @override
  Future<void> creditGems({
    required String uid,
    required int amount,
  }) async {
    try {
      await supabase.rpc(
        'dragon_credit_gems',
        params: {
          'p_target_user_id': uid,
          'p_amount': amount,
          'p_reference_type': 'admin_grant',
          'p_reference_id': 'gamification',
          'p_idempotency_key': const Uuid().v4(),
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر إضافة الجواهر: $e',
      );
    }
  }

  @override
  Future<void> transferPoints({
    required String fromUid,
    required String toUid,
    required int amount,
    required bool bypassChecks,
  }) async {
    try {
      await supabase.rpc(
        'transfer_points',
        params: {
          'p_to_user_id': toUid,
          'p_amount': amount,
          'p_idempotency_key': const Uuid().v4(),
          'p_room_id': null,
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر تحويل النقاط: $e',
      );
    }
  }

  // ==========================================================
  // LEGACY Supabase OPERATIONS
  // Pending Supabase migration:
  // XP / Daily Reward / Username Effect / Badge / Mystery Box
  // Points Packages / Package Purchase
  // ==========================================================

  @override
  Future<GamificationStatsModel> addXp(
    String uid, {
    required String eventType,
    String? referenceType,
    String? referenceId,
  }) async {
    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw const ServerException(
          message: 'جلسة Supabase غير موجودة.',
          code: 'AUTH_REQUIRED',
        );
      }

      final response = await supabase.functions.invoke(
        'add-xp',
        body: {
          'eventType': eventType,
          'referenceType': referenceType,
          'referenceId': referenceId,
          'idempotencyKey': const Uuid().v4(),
        },
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
        },
      );

      final data = response.data;

      if (response.status < 200 || response.status >= 300) {
        if (data is Map) {
          final error = data['error']?.toString();
          final message = data['message']?.toString();

          throw ServerException(
            message: message ?? error ?? 'تعذّر تحديث نقاط الخبرة',
            code: error,
          );
        }

        throw const ServerException(
          message: 'تعذّر تحديث نقاط الخبرة.',
          code: 'XP_GRANT_FAILED',
        );
      }

      return await getStats(uid);
    } on ServerException {
      rethrow;
    } on FunctionException catch (e) {
      throw ServerException(
        message: 'تعذّر تحديث نقاط الخبرة: ${e.details}',
        code: e.status.toString(),
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر تحديث نقاط الخبرة: $e',
      );
    }
  }

  @override
  Future<GamificationStatsModel> claimDailyReward(
    String uid, {
    required int multiplier,
  }) async {
    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw const ServerException(
          message: 'جلسة Supabase غير موجودة.',
          code: 'AUTH_REQUIRED',
        );
      }

      final idempotencyKey = const Uuid().v4();

      await supabase.rpc(
        'claim_daily_reward',
        params: {
          'p_multiplier': multiplier,
          'p_idempotency_key': idempotencyKey,
        },
      );

      return await getStats(uid);
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException(
        message: 'تعذّر منح المكافأة اليومية: $e',
      );
    }
  }

  @override
  Future<void> unlockBadge({
    required String uid,
    required String badgeId,
  }) async {
    try {
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw const ServerException(
          message: 'جلسة Supabase غير موجودة.',
          code: 'AUTH_REQUIRED',
        );
      }

      await supabase.rpc(
        'unlock_badge',
        params: {
          'p_badge_id': badgeId,
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
        message: 'تعذّر منح الوسام: $e',
      );
    }
  }

  @override
  Future<int> spinMysteryBox(
    String uid,
  ) async {
    try {
      final result = await SupabaseFunctionsCompat.instance
          .httpsCallable('gamificationAction')
          .call({
        'action': 'spinMysteryBox',
        'requestId': const Uuid().v4(),
      });

      final data = Map<String, dynamic>.from(
        result.data as Map,
      );

      return (data['reward'] as num).toInt();
    } on SupabaseFunctionException catch (e) {
      throw ServerException(
        message: e.message ?? 'تعذّر تدوير عجلة الحظ',
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر تدوير عجلة الحظ: $e',
      );
    }
  }

  @override
  Future<List<PointsPackageEntity>> listPointsPackages() async {
    throw const ServerException(
      message: 'حزم النقاط لم تُنقل إلى Supabase بعد.',
      code: 'SUPABASE_MIGRATION_PENDING',
    );
  }

  @override
  Future<void> updatePointsPackagePrice({
    required String packageId,
    required int priceMinorUnits,
    required bool enabled,
    required String updatedBy,
  }) async {
    try {
      await supabase.rpc(
        'dragon_update_points_package_price',
        params: {
          'p_package_id': packageId,
          'p_price_minor_units': priceMinorUnits,
          'p_currency': 'shamCash',
          'p_enabled': enabled,
        },
      );
    } on PostgrestException catch (e) {
      throw ServerException(
        message: e.message,
        code: e.code,
      );
    } catch (e) {
      throw ServerException(
        message: 'تعذّر تحديث سعر الحزمة: $e',
      );
    }
  }

  @override
  Future<GamificationStatsModel> purchasePointsPackage({
    required String uid,
    required String packageId,
  }) async {
    throw const ServerException(
      message: 'شراء حزم النقاط لم يُنقل إلى Supabase بعد.',
      code: 'SUPABASE_MIGRATION_PENDING',
    );
  }
}
