import 'agora_injection.dart';
import '../data/supabase_document_compat.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:get_it/get_it.dart';

import '../network/network_info.dart';
import '../services/media_upload_service.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/datasources/email_verification_remote_data_source.dart';
import '../../features/auth/data/datasources/username_credential_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/email_verification_repository_impl.dart';
import '../../features/auth/data/repositories/username_credential_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/repositories/email_verification_repository.dart';
import '../../features/auth/domain/repositories/username_credential_repository.dart';
import '../../features/auth/domain/usecases/check_username_available_usecase.dart';
import '../../features/auth/domain/usecases/create_username_pin_usecase.dart';
import '../../features/auth/domain/usecases/email_verification_usecases.dart';
import '../../features/auth/domain/usecases/get_current_user_usecase.dart';
import '../../features/auth/domain/usecases/reset_password_usecase.dart';
import '../../features/auth/domain/usecases/sign_in_usecase.dart';
import '../../features/auth/domain/usecases/sign_out_usecase.dart';
import '../../features/auth/domain/usecases/sign_up_usecase.dart';
import '../../features/auth/domain/usecases/verify_pin_usecase.dart';

import '../../features/chat/data/datasources/chat_remote_data_source.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/chat_interaction_usecases.dart';
import '../../features/chat/domain/usecases/mark_thread_read_usecase.dart';
import '../../features/chat/domain/usecases/send_message_usecase.dart';

import '../../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/domain/usecases/create_notification_usecase.dart';
import '../../features/notifications/domain/usecases/mark_notification_read_usecase.dart';

import '../../features/posts/data/datasources/post_remote_data_source.dart';
import '../../features/posts/data/repositories/post_repository_impl.dart';
import '../../features/posts/domain/repositories/post_repository.dart';
import '../../features/posts/domain/usecases/add_comment_usecase.dart';
import '../../features/posts/domain/usecases/create_post_usecase.dart';
import '../../features/posts/domain/usecases/delete_comment_usecase.dart';
import '../../features/posts/domain/usecases/delete_post_usecase.dart';
import '../../features/posts/domain/usecases/toggle_like_usecase.dart';

import '../../features/search/data/datasources/search_remote_data_source.dart';
import '../../features/search/data/repositories/search_repository_impl.dart';
import '../../features/search/domain/repositories/search_repository.dart';

import '../../features/social_graph/data/datasources/social_graph_remote_data_source.dart';
import '../../features/social_graph/data/repositories/social_graph_repository_impl.dart';
import '../../features/social_graph/domain/repositories/social_graph_repository.dart';
import '../../features/social_graph/domain/usecases/block_usecase.dart';
import '../../features/social_graph/domain/usecases/follow_usecase.dart';
import '../../features/social_graph/domain/usecases/unblock_usecase.dart';
import '../../features/social_graph/domain/usecases/unfollow_usecase.dart';

import '../../features/reports/data/datasources/report_remote_data_source.dart';
import '../../features/reports/data/repositories/report_repository_impl.dart';
import '../../features/reports/domain/repositories/report_repository.dart';
import '../../features/reports/domain/usecases/resolve_report_usecase.dart';
import '../../features/reports/domain/usecases/submit_report_usecase.dart';

import '../../features/admin/data/datasources/admin_remote_data_source.dart';
import '../../features/admin/data/repositories/admin_repository_impl.dart';
import '../../features/admin/domain/repositories/admin_repository.dart';
import '../../features/admin/domain/usecases/set_account_status_usecase.dart';

import '../../features/friends/data/datasources/friend_remote_data_source.dart';
import '../../features/friends/data/repositories/friend_repository_impl.dart';
import '../../features/friends/domain/repositories/friend_repository.dart';
import '../../features/friends/domain/usecases/respond_to_friend_request_usecase.dart';
import '../../features/friends/domain/usecases/send_friend_request_usecase.dart';

import '../../features/calls/data/datasources/call_remote_data_source.dart';
import '../../features/calls/data/repositories/call_repository_impl.dart';
import '../../features/calls/domain/repositories/call_repository.dart';
import '../../features/calls/domain/usecases/start_call_usecase.dart';

import '../../features/marketplace/data/datasources/marketplace_remote_data_source.dart';
import '../../features/marketplace/data/repositories/marketplace_repository_impl.dart';
import '../../features/marketplace/domain/repositories/marketplace_repository.dart';
import '../../features/marketplace/domain/usecases/create_listing_usecase.dart';
import '../../features/marketplace/domain/usecases/delete_listing_usecase.dart';
import '../../features/marketplace/domain/usecases/place_order_usecase.dart';
import '../../features/marketplace/domain/usecases/update_order_status_usecase.dart';

import '../../features/garment_hub/data/datasources/garment_hub_remote_data_source.dart';
import '../../features/garment_hub/data/repositories/garment_hub_repository_impl.dart';
import '../../features/garment_hub/domain/repositories/garment_hub_repository.dart';
import '../../features/garment_hub/domain/usecases/upsert_business_profile_usecase.dart';

import '../../features/pattern_studio/data/datasources/pattern_studio_remote_data_source.dart';
import '../../features/pattern_studio/data/repositories/pattern_studio_repository_impl.dart';
import '../../features/pattern_studio/domain/repositories/pattern_studio_repository.dart';
import '../../features/pattern_studio/domain/usecases/submit_pattern_request_usecase.dart';
import '../../features/pattern_studio/domain/usecases/submit_pattern_result_usecase.dart';
import '../../features/pattern_studio/domain/usecases/update_pattern_config_usecase.dart';

import '../../features/gamification/data/datasources/gamification_remote_data_source.dart';
import '../../features/gamification/data/repositories/gamification_repository_impl.dart';
import '../../features/gamification/domain/repositories/gamification_repository.dart';
import '../../features/gamification/domain/usecases/claim_daily_reward_usecase.dart';
import '../../features/gamification/domain/usecases/get_gamification_stats_usecase.dart';
import '../../features/gamification/domain/usecases/purchase_points_package_usecase.dart';
import '../../features/gamification/domain/usecases/spend_gems_usecase.dart';
import '../../features/gamification/domain/usecases/spend_points_usecase.dart';
import '../../features/broadcasts/data/datasources/broadcast_remote_data_source.dart';
import '../../features/broadcasts/data/repositories/broadcast_repository_impl.dart';
import '../../features/broadcasts/domain/repositories/broadcast_repository.dart';
import '../../features/broadcasts/domain/usecases/send_broadcast_usecase.dart';
import '../../features/gamification/domain/usecases/apply_referral_usecase.dart';
import '../../features/gamification/domain/usecases/transfer_points_usecase.dart';
import '../../features/store/data/datasources/store_remote_data_source.dart';
import '../../features/store/data/repositories/store_repository_impl.dart';
import '../../features/store/domain/repositories/store_repository.dart';
import '../../features/store/domain/usecases/store_usecases.dart';
import '../../features/gifts/data/datasources/gift_remote_data_source.dart';
import '../../features/gifts/data/repositories/gift_repository_impl.dart';
import '../../features/gifts/domain/repositories/gift_repository.dart';
import '../../features/gifts/domain/usecases/send_gift_usecase.dart';

import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/repositories/profile_repository.dart';
import '../../features/profile/domain/usecases/create_profile_usecase.dart';
import '../../features/profile/domain/usecases/get_profile_usecase.dart';
import '../../features/profile/domain/usecases/set_verified_usecase.dart';
import '../../features/profile/domain/usecases/update_profile_usecase.dart';

import '../../features/rbac/data/datasources/rbac_remote_data_source.dart';
import '../../features/rbac/data/repositories/rbac_repository_impl.dart';
import '../../features/rbac/domain/repositories/rbac_repository.dart';
import '../../features/rbac/domain/usecases/assign_role_usecase.dart';
import '../../features/rbac/domain/usecases/check_permission_usecase.dart';
import '../../features/rbac/domain/usecases/get_user_role_usecase.dart';
import '../../features/rbac/domain/usecases/manage_roles_usecases.dart';

import '../../features/subscriptions/data/datasources/subscription_remote_data_source.dart';
import '../../features/subscriptions/data/repositories/subscription_repository_impl.dart';
import '../../features/subscriptions/domain/repositories/subscription_repository.dart';
import '../../features/subscriptions/domain/usecases/get_current_subscription_usecase.dart';
import '../../features/subscriptions/domain/usecases/grant_membership_feature_usecase.dart';

import '../../features/wallet/data/datasources/wallet_remote_data_source.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/get_wallet_history_usecase.dart';
import '../../features/wallet/domain/usecases/transfer_usecase.dart';

/// Service Locator موحّد لكامل المشروع. كل وحدة جديدة تُضاف لاحقًا
/// (المشاريع، المنشورات، الرسائل، السوق، المحفظة...) تُسجَّل هنا
/// بنفس النمط، وتستطيع الوصول مباشرة إلى RbacRepository الموجود
/// للتكامل الفوري مع نظام الصلاحيات دون إعادة بنائه.
final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  registerAgoraDependencies(sl);
  // ------------------------- External / Supabase -------------------------
  // Supabase backend — initialized in main.dart before initDependencies().
  sl.registerLazySingleton<SupabaseClient>(
    () => Supabase.instance.client,
  );
  sl.registerLazySingleton<SupabaseDocumentStore>(
      () => SupabaseDocumentStore.instance);
  sl.registerLazySingleton<SupabaseFunctionsCompat>(
      () => SupabaseFunctionsCompat.instance);
  sl.registerLazySingleton<SupabaseAuthCompat>(
      () => SupabaseAuthCompat.instance);

  sl.registerLazySingleton<Connectivity>(() => Connectivity());
  sl.registerLazySingleton<NetworkInfo>(() => NetworkInfoImpl(sl()));
  sl.registerLazySingleton<MediaUploadService>(() => MediaUploadService());

  // ------------------------------- RBAC ------------------------------------
  // تُسجَّل أولًا لأن Auth وProfile يعتمدان عليها.
  sl.registerLazySingleton<RbacRemoteDataSource>(
      () => RbacRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<RbacRepository>(
    () => RbacRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => ListRolesUseCase(sl()));
  sl.registerLazySingleton(() => UpdateRolePermissionsUseCase(sl()));
  sl.registerLazySingleton(() => WatchAuditLogsUseCase(sl()));
  sl.registerLazySingleton(() => GetUserRoleUseCase(sl()));
  sl.registerLazySingleton(() => CheckPermissionUseCase(sl()));
  sl.registerLazySingleton(() => AssignRoleUseCase(sl()));

  // ------------------------------- Auth -----------------------------------
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(
      sl<SupabaseClient>(),
    ),
  );
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => SignInUseCase(sl()));
  sl.registerLazySingleton(() => SignOutUseCase(sl()));
  sl.registerLazySingleton(() => ResetPasswordUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));

  // ---------------------- Auth Phase 1 Additions ----------------------------
  // اسم مستخدم + PIN
  sl.registerLazySingleton<UsernameCredentialRemoteDataSource>(
    () => UsernameCredentialRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<UsernameCredentialRepository>(
    () => UsernameCredentialRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => CheckUsernameAvailableUseCase(sl()));
  sl.registerLazySingleton(() => CreateUsernamePinUseCase(sl()));
  sl.registerLazySingleton(() => VerifyPinUseCase(sl()));

  // كود تأكيد البريد الإلكتروني
  sl.registerLazySingleton<EmailVerificationRemoteDataSource>(
    () => EmailVerificationRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<EmailVerificationRepository>(
    () => EmailVerificationRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => SendVerificationCodeUseCase(sl()));
  sl.registerLazySingleton(() => ConfirmVerificationCodeUseCase(sl()));

  // ------------------------------ Profile ----------------------------------
  sl.registerLazySingleton<ProfileRemoteDataSource>(
      () => ProfileRemoteDataSourceImpl());
  sl.registerLazySingleton<ProfileRepository>(
    () => ProfileRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => CreateProfileUseCase(sl()));
  sl.registerLazySingleton(() => GetProfileUseCase(sl()));
  sl.registerLazySingleton(
    () => UpdateProfileUseCase(profileRepository: sl()),
  );
  sl.registerLazySingleton(
    () => SetVerifiedUseCase(profileRepository: sl(), rbacRepository: sl()),
  );

  // SignUpUseCase مسجَّل أخيرًا لأنه يعتمد على الوحدات الثلاث معًا.
  sl.registerLazySingleton(
    () => SignUpUseCase(
        authRepository: sl(), profileRepository: sl(), rbacRepository: sl()),
  );

  // --------------------------- Subscriptions ---------------------------------
  // تُسجَّل قبل Gamification لأن ClaimDailyRewardUseCase يعتمد عليها.
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetCurrentSubscriptionUseCase(sl()));
  sl.registerLazySingleton(() => GrantMembershipFeatureUseCase(
      subscriptionRepository: sl(), rbacRepository: sl()));

  // --------------------------- Gamification ---------------------------------
  sl.registerLazySingleton<GamificationRemoteDataSource>(
    () => GamificationRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<GamificationRepository>(
    () => GamificationRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetGamificationStatsUseCase(sl()));
  sl.registerLazySingleton(
    () => ClaimDailyRewardUseCase(
        gamificationRepository: sl(), subscriptionRepository: sl()),
  );
  sl.registerLazySingleton(
    () =>
        SpendPointsUseCase(gamificationRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(
    () => SpendGemsUseCase(gamificationRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(
    () => TransferPointsUseCase(
        gamificationRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(
    () => ApplyReferralUseCase(
        usernameCredentialRepository: sl(), gamificationRepository: sl()),
  );
  sl.registerLazySingleton<StoreRemoteDataSource>(
      () => StoreRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<StoreRepository>(
      () => StoreRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton(() => ListStoreCatalogUseCase(sl()));
  sl.registerLazySingleton(
    () => PurchaseStoreItemUseCase(storeRepository: sl()),
  );
  sl.registerLazySingleton(
    () => UpdateStoreItemUseCase(storeRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(() => CreateStoreItemUseCase(sl(), sl()));
  sl.registerLazySingleton(() => GrantStoreItemUseCase(sl(), sl()));
  sl.registerLazySingleton(() => PurchasePointsPackageUseCase(sl()));
  sl.registerLazySingleton(() => ListPointsPackagesUseCase(sl()));
  sl.registerLazySingleton(() => UpdatePointsPackagePriceUseCase(sl(), sl()));

  // ------------------------------- Gifts ------------------------------------
  sl.registerLazySingleton<GiftRemoteDataSource>(
      () => GiftRemoteDataSourceImpl(Supabase.instance.client));
  sl.registerLazySingleton<GiftRepository>(
      () => GiftRepositoryImpl(remoteDataSource: sl()));
  sl.registerLazySingleton(
    () => SendGiftUseCase(
      gamificationRepository: sl(),
      rbacRepository: sl(),
      giftRepository: sl(),
    ),
  );

  // ---------------------------- Broadcasts ------------------------------------
  sl.registerLazySingleton<BroadcastRemoteDataSource>(
    () => BroadcastRemoteDataSourceImpl(
      sl<SupabaseClient>(),
    ),
  );

  sl.registerLazySingleton<BroadcastRepository>(
    () => BroadcastRepositoryImpl(
      remoteDataSource: sl<BroadcastRemoteDataSource>(),
    ),
  );

  sl.registerLazySingleton(
    () => SendBroadcastUseCase(
      broadcastRepository: sl<BroadcastRepository>(),
      rbacRepository: sl<RbacRepository>(),
    ),
  );

  // ------------------------------ Wallet ------------------------------------
  sl.registerLazySingleton<WalletRemoteDataSource>(
      () => WalletRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<WalletRepository>(
    () => WalletRepositoryImpl(remoteDataSource: sl(), networkInfo: sl()),
  );
  sl.registerLazySingleton(() => GetWalletHistoryUseCase(sl()));
  sl.registerLazySingleton(() => TransferUseCase(sl()));

  // --------------------------- Notifications ---------------------------------
  // تُسجَّل قبل Chat وPosts لأنهما يعتمدان عليها.
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(Supabase.instance.client),
  );
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => CreateNotificationUseCase(sl()));
  sl.registerLazySingleton(() => MarkNotificationReadUseCase(sl()));

  // ------------------------------- Chat --------------------------------------
  sl.registerLazySingleton<ChatRemoteDataSource>(
      () => ChatRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<ChatRepository>(
    () => ChatRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => SendMessageUseCase(
      chatRepository: sl(),
      notificationRepository: sl(),
      socialGraphRepository: sl(),
    ),
  );
  sl.registerLazySingleton(() => MarkThreadReadUseCase(sl()));
  sl.registerLazySingleton(() => EditMessageUseCase(sl()));
  sl.registerLazySingleton(() => DeleteMessageUseCase(sl()));
  sl.registerLazySingleton(() => ToggleReactionUseCase(sl()));
  sl.registerLazySingleton(() => SetPinnedMessageUseCase(sl()));
  sl.registerLazySingleton(() => SetTypingUseCase(sl()));
  sl.registerLazySingleton(() => WatchTypingUseCase(sl()));
  sl.registerLazySingleton(() => WatchPresenceUseCase(sl()));
  sl.registerLazySingleton(() => SetPresenceUseCase(sl()));

  // ------------------------------- Posts --------------------------------------
  sl.registerLazySingleton<PostRemoteDataSource>(
      () => PostRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<PostRepository>(
    () => PostRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => CreatePostUseCase(sl()));
  sl.registerLazySingleton(
    () => DeletePostUseCase(postRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(
    () => ToggleLikeUseCase(postRepository: sl(), notificationRepository: sl()),
  );
  sl.registerLazySingleton(
    () => AddCommentUseCase(postRepository: sl(), notificationRepository: sl()),
  );
  sl.registerLazySingleton(
    () => DeleteCommentUseCase(postRepository: sl(), rbacRepository: sl()),
  );

  // ------------------------------- Search --------------------------------------
  sl.registerLazySingleton<SearchRemoteDataSource>(
      () => SearchRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<SearchRepository>(() => SearchRepositoryImpl(sl()));

  // --------------------------- Social Graph ----------------------------------
  // ملاحظة: GetIt Lazy Singleton لا يتطلب ترتيبًا معينًا للتسجيل —
  // الاعتماديات تُحل عند أول استخدام فعلي، وليس عند التسجيل نفسه.
  sl.registerLazySingleton<SocialGraphRemoteDataSource>(
    () => SocialGraphRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<SocialGraphRepository>(
    () => SocialGraphRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => FollowUseCase(sl()));
  sl.registerLazySingleton(() => UnfollowUseCase(sl()));
  sl.registerLazySingleton(() => BlockUseCase(sl()));
  sl.registerLazySingleton(() => UnblockUseCase(sl()));

  // -------------------------------- Reports ------------------------------------
  sl.registerLazySingleton<ReportRemoteDataSource>(
      () => ReportRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<ReportRepository>(
    () => ReportRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => SubmitReportUseCase(sl()));
  sl.registerLazySingleton(
    () => ResolveReportUseCase(reportRepository: sl(), rbacRepository: sl()),
  );

  // -------------------------------- Admin --------------------------------------
  sl.registerLazySingleton<AdminRemoteDataSource>(
      () => AdminRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<AdminRepository>(
    () => AdminRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => SetAccountStatusUseCase(adminRepository: sl(), rbacRepository: sl()),
  );

  // ------------------------------- Friends --------------------------------------
  sl.registerLazySingleton<FriendRemoteDataSource>(
      () => FriendRemoteDataSourceImpl(Supabase.instance.client));
  sl.registerLazySingleton<FriendRepository>(
    () => FriendRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => SendFriendRequestUseCase(
      friendRepository: sl(),
      socialGraphRepository: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => RespondToFriendRequestUseCase(friendRepository: sl()),
  );

  // -------------------------------- Calls ----------------------------------------
  sl.registerLazySingleton<CallRemoteDataSource>(
      () => CallRemoteDataSourceImpl(sl()));
  sl.registerLazySingleton<CallRepository>(
    () => CallRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => StartCallUseCase(callRepository: sl(), socialGraphRepository: sl()),
  );

  // ----------------------------- Marketplace --------------------------------------
  sl.registerLazySingleton<MarketplaceRemoteDataSource>(
    () => MarketplaceRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<MarketplaceRepository>(
    () => MarketplaceRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => CreateListingUseCase(sl()));
  sl.registerLazySingleton(
    () =>
        DeleteListingUseCase(marketplaceRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(
    () => const PlaceOrderUseCase(),
  );
  sl.registerLazySingleton(() => UpdateOrderStatusUseCase(sl()));

  // ----------------------------- Garment Hub ---------------------------------------
  sl.registerLazySingleton<GarmentHubRemoteDataSource>(
    () => GarmentHubRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<GarmentHubRepository>(
    () => GarmentHubRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => UpsertBusinessProfileUseCase(
        garmentHubRepository: sl(), rbacRepository: sl()),
  );

  // --------------------------- Pattern Studio --------------------------------------
  sl.registerLazySingleton<PatternStudioRemoteDataSource>(
    () => PatternStudioRemoteDataSourceImpl(sl()),
  );
  sl.registerLazySingleton<PatternStudioRepository>(
    () => PatternStudioRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(
    () => const SubmitPatternRequestUseCase(),
  );
  sl.registerLazySingleton(
    () => UpdatePatternConfigUseCase(
        patternRepository: sl(), rbacRepository: sl()),
  );
  sl.registerLazySingleton(
    () => SubmitPatternResultUseCase(
      patternRepository: sl(),
      rbacRepository: sl(),
      notificationRepository: sl(),
    ),
  );
}
