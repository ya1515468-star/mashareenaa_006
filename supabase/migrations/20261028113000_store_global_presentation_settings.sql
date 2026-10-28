-- Central, server-authoritative appearance settings for every chat-store section.
CREATE TABLE IF NOT EXISTS public.store_global_presentation_settings (
  singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
  font_scale numeric NOT NULL DEFAULT 1.00 CHECK (font_scale BETWEEN 0.70 AND 1.30),
  emoji_scale numeric NOT NULL DEFAULT 1.00 CHECK (emoji_scale BETWEEN 0.60 AND 1.50),
  card_scale numeric NOT NULL DEFAULT 1.00 CHECK (card_scale BETWEEN 0.70 AND 1.30),
  preview_scale numeric NOT NULL DEFAULT 1.00 CHECK (preview_scale BETWEEN 0.60 AND 1.40),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES auth.users(id) ON DELETE SET NULL
);
INSERT INTO public.store_global_presentation_settings (singleton)
VALUES (true) ON CONFLICT (singleton) DO NOTHING;

ALTER TABLE public.store_global_presentation_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.store_global_presentation_settings FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER
  ON TABLE public.store_global_presentation_settings FROM anon, authenticated;
GRANT SELECT ON TABLE public.store_global_presentation_settings TO anon, authenticated;
DROP POLICY IF EXISTS store_global_presentation_read ON public.store_global_presentation_settings;
CREATE POLICY store_global_presentation_read ON public.store_global_presentation_settings
  FOR SELECT TO anon, authenticated USING (singleton IS TRUE);

CREATE OR REPLACE FUNCTION public.get_store_global_presentation_settings()
RETURNS jsonb LANGUAGE sql STABLE SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
  SELECT jsonb_build_object(
    'font_scale', s.font_scale, 'emoji_scale', s.emoji_scale,
    'card_scale', s.card_scale, 'preview_scale', s.preview_scale,
    'updated_at', s.updated_at
  )
  FROM public.store_global_presentation_settings s WHERE s.singleton = true;
$function$;
REVOKE ALL ON FUNCTION public.get_store_global_presentation_settings() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_store_global_presentation_settings() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.owner_set_store_global_presentation_settings(
  p_font_scale numeric DEFAULT NULL, p_emoji_scale numeric DEFAULT NULL,
  p_card_scale numeric DEFAULT NULL, p_preview_scale numeric DEFAULT NULL
)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public', 'pg_temp'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_row public.store_global_presentation_settings;
BEGIN
  IF v_uid IS NULL OR NOT public._is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_font_scale IS NOT NULL AND p_font_scale NOT BETWEEN 0.70 AND 1.30 THEN RAISE EXCEPTION 'FONT_SCALE_OUT_OF_RANGE'; END IF;
  IF p_emoji_scale IS NOT NULL AND p_emoji_scale NOT BETWEEN 0.60 AND 1.50 THEN RAISE EXCEPTION 'EMOJI_SCALE_OUT_OF_RANGE'; END IF;
  IF p_card_scale IS NOT NULL AND p_card_scale NOT BETWEEN 0.70 AND 1.30 THEN RAISE EXCEPTION 'CARD_SCALE_OUT_OF_RANGE'; END IF;
  IF p_preview_scale IS NOT NULL AND p_preview_scale NOT BETWEEN 0.60 AND 1.40 THEN RAISE EXCEPTION 'PREVIEW_SCALE_OUT_OF_RANGE'; END IF;

  UPDATE public.store_global_presentation_settings
  SET font_scale = COALESCE(p_font_scale, font_scale),
      emoji_scale = COALESCE(p_emoji_scale, emoji_scale),
      card_scale = COALESCE(p_card_scale, card_scale),
      preview_scale = COALESCE(p_preview_scale, preview_scale),
      updated_at = now(), updated_by = v_uid
  WHERE singleton = true RETURNING * INTO v_row;

  RETURN jsonb_build_object('ok', true, 'font_scale', v_row.font_scale,
    'emoji_scale', v_row.emoji_scale, 'card_scale', v_row.card_scale,
    'preview_scale', v_row.preview_scale, 'updated_at', v_row.updated_at);
END;
$function$;
REVOKE ALL ON FUNCTION public.owner_set_store_global_presentation_settings(numeric, numeric, numeric, numeric) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.owner_set_store_global_presentation_settings(numeric, numeric, numeric, numeric) TO authenticated;

DO $publication$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (SELECT 1 FROM pg_publication_tables WHERE pubname = 'supabase_realtime'
       AND schemaname = 'public' AND tablename = 'store_global_presentation_settings') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.store_global_presentation_settings;
  END IF;
EXCEPTION WHEN insufficient_privilege OR undefined_object THEN NULL;
END;
$publication$;
