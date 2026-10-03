-- Mashareena comprehensive production audit (read-only)
WITH required_tables(name) AS (
  VALUES
  ('profiles'),('roles'),('user_roles'),('chat_rooms'),('chat_room_members'),
  ('public_chat_messages'),('platform_broadcasts'),('platform_broadcast_deliveries'),
  ('platform_login_announcements'),('platform_login_announcement_views'),
  ('profile_service_catalog'),('user_profile_services'),('user_vip_entitlements'),
  ('profile_cosmetic_catalog'),('avatar_frame_catalog'),('profile_cosmetic_purchases'),
  ('animated_chat_badges')
),
required_functions(name) AS (
  VALUES
  ('get_active_login_announcement'),('record_login_announcement_view'),
  ('admin_list_login_announcements'),('admin_upsert_login_announcement'),
  ('admin_archive_login_announcement'),('publish_platform_broadcast'),
  ('purchase_profile_service'),('record_profile_service_use'),
  ('mute_room_member'),('unmute_room_member'),('ban_room_member'),('kick_room_member'),
  ('bury_room_member'),('unbury_room_member'),('promote_room_member'),('demote_room_member'),
  ('assign_role'),('update_role_permissions'),('set_avatar_frame'),('get_avatar_frame_catalog')
),
missing_tables AS (
  SELECT count(*) AS n FROM required_tables r WHERE to_regclass('public.'||r.name) IS NULL
),
missing_functions AS (
  SELECT count(*) AS n FROM required_functions r WHERE NOT EXISTS (
    SELECT 1 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
    WHERE n.nspname='public' AND p.proname=r.name
  )
),
rls_gaps AS (
  SELECT count(*) AS n FROM unnest(ARRAY[
    'profiles','roles','user_roles','chat_rooms','chat_room_members','public_chat_messages',
    'platform_broadcasts','platform_broadcast_deliveries','platform_login_announcements',
    'platform_login_announcement_views','profile_service_catalog','user_profile_services',
    'user_vip_entitlements','profile_cosmetic_catalog','avatar_frame_catalog','profile_cosmetic_purchases',
    'animated_chat_badges'
  ]) t(name)
  WHERE to_regclass('public.'||t.name) IS NOT NULL
    AND EXISTS (SELECT 1 FROM pg_class c WHERE c.oid=to_regclass('public.'||t.name) AND c.relrowsecurity=false)
),
invalid_equipped AS (
  SELECT count(*) AS n FROM public.profiles p
  WHERE p.avatar_frame_key IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM public.avatar_frame_catalog f WHERE f.frame_key=p.avatar_frame_key AND f.is_active=true)
),
realtime_missing AS (
  SELECT count(*) AS n FROM unnest(ARRAY[
    'profiles','chat_rooms','chat_room_members','public_chat_messages','chat_messages',
    'chat_threads','chat_typing','user_presence','animated_chat_badges'
  ]) t(name)
  WHERE to_regclass('public.'||t.name) IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname='supabase_realtime' AND schemaname='public' AND tablename=t.name)
),
announcement_schema AS (
  SELECT count(*) AS n FROM information_schema.columns
  WHERE table_schema='public' AND table_name='platform_login_announcements'
    AND column_name IN ('id','title','body','image_url','status','starts_at','ends_at','audience_type','audience_user_ids','display_mode','created_by','created_at','updated_at','priority')
),
non_owner_announcement_policies AS (
  SELECT count(*) AS n FROM pg_policies
  WHERE schemaname='public' AND tablename='platform_login_announcements'
    AND roles::text LIKE '%authenticated%' AND policyname NOT ILIKE '%owner%'
),
security_definer_anon AS (
  SELECT count(*) AS n FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='public' AND p.prosecdef AND has_function_privilege('anon',p.oid,'EXECUTE')
)
SELECT jsonb_build_object(
  'generated_at', now(),
  'missing_tables', (SELECT n FROM missing_tables),
  'missing_required_functions', (SELECT n FROM missing_functions),
  'rls_disabled_required_tables', (SELECT n FROM rls_gaps),
  'invalid_equipped_avatar_frames', (SELECT n FROM invalid_equipped),
  'realtime_missing_required_tables', (SELECT n FROM realtime_missing),
  'login_announcement_required_columns', (SELECT n FROM announcement_schema),
  'non_owner_direct_announcement_policies', (SELECT n FROM non_owner_announcement_policies),
  'anon_executable_security_definers', (SELECT n FROM security_definer_anon),
  'login_announcements', (SELECT count(*) FROM public.platform_login_announcements),
  'login_announcement_views', (SELECT count(*) FROM public.platform_login_announcement_views),
  'active_avatar_frames', (SELECT count(*) FROM public.avatar_frame_catalog WHERE is_active=true),
  'active_name_templates', (SELECT count(*) FROM public.profile_cosmetic_catalog WHERE is_active=true AND category='name_template'),
  'vip_catalog_services', (SELECT count(*) FROM public.profile_service_catalog WHERE is_active=true),
  'vip_entitlements', (SELECT count(*) FROM public.user_vip_entitlements),
  'roles', (SELECT jsonb_agg(jsonb_build_object('code',code,'name',name,'priority',priority) ORDER BY priority DESC) FROM public.roles),
  'migration_versions', (SELECT count(*) FROM supabase_migrations.schema_migrations),
  'latest_migration', (SELECT max(version) FROM supabase_migrations.schema_migrations)
) AS audit;
