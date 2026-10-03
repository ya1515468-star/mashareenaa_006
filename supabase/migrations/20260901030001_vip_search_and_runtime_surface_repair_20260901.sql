BEGIN;
CREATE OR REPLACE FUNCTION public.search_public_profiles(p_query text DEFAULT ''::text, p_limit integer DEFAULT 8)
RETURNS TABLE(id uuid, username text, display_name text, avatar_url text)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public AS $function$
 SELECT p.id,p.username,p.display_name,p.avatar_url
 FROM public.profiles p
 WHERE p.is_active=true AND p.is_suspended=false AND coalesce(p.visibility,'public')='public'
   AND NOT public.has_profile_service_for_user(p.id,'hide_profile')
   AND (nullif(trim(p_query),'') IS NULL OR p.username ILIKE '%'||trim(p_query)||'%' OR p.display_name ILIKE '%'||trim(p_query)||'%')
 ORDER BY CASE WHEN public.has_profile_service_for_user(p.id,'profile_priority_search') THEN 0 ELSE 1 END,
          coalesce(nullif(trim(p.display_name),''),nullif(trim(p.username),''),'عضو')
 LIMIT greatest(1,least(coalesce(p_limit,8),25));
$function$;
REVOKE ALL ON FUNCTION public.search_public_profiles(text,integer) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.search_public_profiles(text,integer) TO authenticated;
COMMIT;
