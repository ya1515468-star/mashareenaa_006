update public.profile_service_catalog
set icon_key='military_tech', updated_at=now()
where feature_key='profile_custom_badge' and icon_key='workspace_premium';
