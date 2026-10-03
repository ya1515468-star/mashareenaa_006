import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/subscription_tier_entity.dart';
import '../../domain/entities/user_subscription_entity.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_data_source.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  SubscriptionRepositoryImpl(
      {required this.remoteDataSource, required this.networkInfo});

  @override
  Future<Either<Failure, UserSubscriptionEntity>> getCurrentSubscription(
      String uid) async {
    if (!await networkInfo.isConnected) return const Left(NetworkFailure());
    try {
      final sub = await remoteDataSource.getCurrentSubscription(uid);
      return Right(sub);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Stream<UserSubscriptionEntity> watchSubscription(String uid) =>
      remoteDataSource.watchSubscription(uid);

  @override
  Future<Either<Failure, MembershipFeatures>> getEffectiveFeatures(
      String uid) async {
    try {
      final sub = await remoteDataSource.getCurrentSubscription(uid);
      final overrides = await remoteDataSource.getFeatureOverrides(uid);
      // Was sub.effectiveTier.features — a purely client-side lookup against
      // five hardcoded template ids. A custom tier id matched none of them
      // and silently fell back to zero features. get_membership_tier_features
      // is the one server-side resolver for this now, for every tier alike.
      // sub.effectiveTier.id would still be wrong here: effectiveTier falls
      // back to SubscriptionCatalog.free (id 'free') for any tierId that
      // matches none of the five hardcoded templates — passing THAT id to
      // the server would ask it for the free tier's features instead of the
      // real custom tier's. The raw tierId (with the same expiry check
      // effectiveTier itself does) is what must be sent.
      final effectiveTierId =
          sub.isActive ? sub.tierId : SubscriptionCatalog.freeTierId;
      final raw = await Supabase.instance.client.rpc(
        'get_membership_tier_features',
        params: {'p_tier_id': effectiveTierId},
      );
      final base = MembershipFeatures.fromMap(
        raw is Map ? Map<String, dynamic>.from(raw) : const {},
      );
      return Right(base.mergeOverrides(overrides));
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> setFeatureOverride({
    required String targetUid,
    required String featureKey,
    required bool enabled,
    required String grantedByUid,
  }) async {
    try {
      await remoteDataSource.setFeatureOverride(
        targetUid: targetUid,
        featureKey: featureKey,
        enabled: enabled,
        grantedByUid: grantedByUid,
      );
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
