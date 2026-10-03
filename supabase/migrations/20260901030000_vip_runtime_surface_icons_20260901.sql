BEGIN;
ALTER TABLE public.profile_service_catalog
  ADD COLUMN IF NOT EXISTS icon_key text,
  ADD COLUMN IF NOT EXISTS action_key text,
  ADD COLUMN IF NOT EXISTS runtime_surface text;

UPDATE public.profile_service_catalog SET icon_key='visibility', action_key='open_profile_visitors', runtime_surface='profile' WHERE feature_key='profile_visitors';
UPDATE public.profile_service_catalog SET icon_key='verified', action_key='activate_account_verification', runtime_surface='profile' WHERE feature_key='account_verification';
UPDATE public.profile_service_catalog SET icon_key='login', action_key='toggle_join_announcement', runtime_surface='chat' WHERE feature_key='hide_join_announcement';
UPDATE public.profile_service_catalog SET icon_key='visibility_off', action_key='toggle_profile_visibility', runtime_surface='profile' WHERE feature_key='hide_profile';
UPDATE public.profile_service_catalog SET icon_key='music_note', action_key='edit_profile_music', runtime_surface='profile' WHERE feature_key='profile_music';
UPDATE public.profile_service_catalog SET icon_key='person_off', action_key='toggle_anonymous_chat', runtime_surface='chat' WHERE feature_key='anonymous_chat';
UPDATE public.profile_service_catalog SET icon_key='share', action_key='edit_social_links', runtime_surface='profile' WHERE feature_key='social_links';
UPDATE public.profile_service_catalog SET icon_key='photo_library', action_key='create_profile_product', runtime_surface='profile' WHERE feature_key='profile_products';
UPDATE public.profile_service_catalog SET icon_key='video_call', action_key='toggle_voice_video_calls', runtime_surface='chat' WHERE feature_key='voice_video_calls';
UPDATE public.profile_service_catalog SET icon_key='storefront', action_key='create_mini_store_item', runtime_surface='profile' WHERE feature_key='profile_mini_store';
UPDATE public.profile_service_catalog SET icon_key='campaign', action_key='create_targeted_ad', runtime_surface='profile' WHERE feature_key='profile_targeted_ads';
UPDATE public.profile_service_catalog SET icon_key='poll', action_key='create_profile_poll', runtime_surface='profile' WHERE feature_key='advanced_profile_polls';
UPDATE public.profile_service_catalog SET icon_key='workspace_premium', action_key='open_achievement_badges', runtime_surface='profile' WHERE feature_key='achievement_badges';
UPDATE public.profile_service_catalog SET icon_key='timer_off', action_key='configure_self_destruct_chat', runtime_surface='chat' WHERE feature_key='self_destruct_chat';
UPDATE public.profile_service_catalog SET icon_key='grid_4x4', action_key='upload_pattern', runtime_surface='both' WHERE feature_key='pattern_sharing';
UPDATE public.profile_service_catalog SET icon_key='calculate', action_key='calculate_production_cost', runtime_surface='chat' WHERE feature_key='production_cost_calculator';
UPDATE public.profile_service_catalog SET icon_key='palette', action_key='configure_profile_theme', runtime_surface='profile' WHERE feature_key='profile_theme_plus';
UPDATE public.profile_service_catalog SET icon_key='badge_outlined', action_key='configure_profile_card', runtime_surface='profile' WHERE feature_key='profile_card_plus';
UPDATE public.profile_service_catalog SET icon_key='highlight', action_key='toggle_profile_highlight', runtime_surface='profile' WHERE feature_key='profile_highlight';
UPDATE public.profile_service_catalog SET icon_key='notifications_active', action_key='toggle_profile_visitor_alerts', runtime_surface='profile' WHERE feature_key='profile_visitor_alerts';
UPDATE public.profile_service_catalog SET icon_key='contact_page', action_key='configure_profile_contact', runtime_surface='profile' WHERE feature_key='profile_contact_button';
UPDATE public.profile_service_catalog SET icon_key='qr_code_2', action_key='open_profile_qr_card', runtime_surface='profile' WHERE feature_key='profile_qr_card';
UPDATE public.profile_service_catalog SET icon_key='workspace_premium', action_key='configure_profile_custom_badge', runtime_surface='profile' WHERE feature_key='profile_custom_badge';
UPDATE public.profile_service_catalog SET icon_key='manage_search', action_key='enable_search_priority', runtime_surface='profile' WHERE feature_key='profile_priority_search';
UPDATE public.profile_service_catalog SET icon_key='gradient', action_key='configure_chat_name_gradient', runtime_surface='chat' WHERE feature_key='chat_name_gradient';
UPDATE public.profile_service_catalog SET icon_key='flare', action_key='configure_chat_message_glow', runtime_surface='chat' WHERE feature_key='chat_message_glow';
UPDATE public.profile_service_catalog SET icon_key='priority_high', action_key='enable_chat_priority_badge', runtime_surface='chat' WHERE feature_key='chat_priority_badge';
UPDATE public.profile_service_catalog SET icon_key='alternate_email', action_key='configure_mention_highlight', runtime_surface='chat' WHERE feature_key='chat_mention_highlight';
UPDATE public.profile_service_catalog SET icon_key='link', action_key='enable_link_preview_plus', runtime_surface='chat' WHERE feature_key='chat_link_preview_plus';
UPDATE public.profile_service_catalog SET icon_key='perm_media', action_key='enable_media_plus', runtime_surface='chat' WHERE feature_key='chat_media_plus';
UPDATE public.profile_service_catalog SET icon_key='star', action_key='configure_chat_favorites', runtime_surface='chat' WHERE feature_key='chat_favorites_plus';
UPDATE public.profile_service_catalog SET icon_key='online_prediction', action_key='configure_chat_presence', runtime_surface='chat' WHERE feature_key='chat_presence_plus';
UPDATE public.profile_service_catalog SET icon_key='notifications_off', action_key='configure_smart_mute', runtime_surface='chat' WHERE feature_key='chat_smart_mute';
UPDATE public.profile_service_catalog SET icon_key='volunteer_activism', action_key='open_creator_tip', runtime_surface='both' WHERE feature_key='creator_tip_button';
UPDATE public.profile_service_catalog SET icon_key='analytics', action_key='open_profile_analytics', runtime_surface='profile' WHERE feature_key='profile_analytics_plus';
UPDATE public.profile_service_catalog SET icon_key='content_cut', action_key='highlight_tailor_patterns', runtime_surface='both' WHERE feature_key='tailor_pattern_highlight';

CREATE OR REPLACE FUNCTION public.get_public_vip_effects(p_user_id uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path=public AS $function$
DECLARE v_requester uuid:=auth.uid(); v_owner boolean; v_result jsonb;
BEGIN
 IF v_requester IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
 IF p_user_id IS NULL THEN RAISE EXCEPTION 'USER_REQUIRED'; END IF;
 v_owner:=public._is_platform_owner(p_user_id);
 SELECT coalesce(jsonb_object_agg(c.feature_key,jsonb_build_object(
   'enabled',CASE WHEN v_owner THEN true ELSE coalesce(s.enabled,false) END,
   'icon_key',coalesce(c.icon_key,'auto_awesome'),
   'action_key',coalesce(c.action_key,'configure_service'),
   'runtime_surface',coalesce(c.runtime_surface,c.usage_surface),
   'settings',CASE WHEN c.feature_key IN (
     'chat_name_gradient','chat_message_glow','chat_priority_badge','chat_mention_highlight','chat_link_preview_plus','chat_media_plus','chat_favorites_plus','chat_presence_plus','chat_smart_mute','creator_tip_button',
     'profile_highlight','profile_contact_button','profile_custom_badge','profile_priority_search','profile_theme_plus','profile_card_plus','profile_visitor_alerts','profile_qr_card','profile_analytics_plus','tailor_pattern_highlight'
   ) THEN coalesce(s.settings,'{}'::jsonb) ELSE '{}'::jsonb END
 ) ORDER BY c.sort_order),'{}'::jsonb) INTO v_result
 FROM public.profile_service_catalog c
 LEFT JOIN public.user_profile_services s ON s.user_id=p_user_id AND s.feature_key=c.feature_key
 WHERE c.is_active=true;
 RETURN v_result;
END;$function$;

REVOKE ALL ON FUNCTION public.get_public_vip_effects(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_public_vip_effects(uuid) TO authenticated;
COMMIT;
