-- Mashareena production hardening:
-- 1) owner identity for VIP payouts comes from platform_owners (authoritative owner table)
-- 2) VIP purchases remain idempotent and activate the exact catalog key requested
-- 3) frame deletion remains owner-only and safe to retry; Storage is handled by the Edge Function

BEGIN;

CREATE OR REPLACE FUNCTION public.purchase_profile_service(
  p_feature_key text,
  p_currency text,
  p_request_id uuid DEFAULT gen_random_uuid()
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_key text := trim(coalesce(p_feature_key, ''));
  v_currency text := lower(trim(coalesce(p_currency, '')));
  v_price bigint;
  v_before bigint;
  v_after bigint;
  v_owner uuid;
  v_existing record;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF v_currency NOT IN ('points', 'gems') THEN RAISE EXCEPTION 'INVALID_CURRENCY'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.profile_service_catalog c WHERE c.feature_key = v_key) THEN
    RAISE EXCEPTION 'ITEM_NOT_FOUND';
  END IF;

  SELECT user_id INTO v_owner
  FROM public.platform_owners
  ORDER BY user_id
  LIMIT 1;
  IF v_owner IS NULL THEN RAISE EXCEPTION 'PLATFORM_OWNER_NOT_CONFIGURED'; END IF;

  SELECT * INTO v_existing
  FROM public.profile_service_orders
  WHERE request_id = p_request_id;
  IF FOUND THEN
    IF v_existing.buyer_uid <> v_uid
       OR v_existing.feature_key <> v_key
       OR v_existing.currency <> v_currency THEN
      RAISE EXCEPTION 'REQUEST_ID_REPLAY_FORBIDDEN';
    END IF;
    RETURN jsonb_build_object(
      'ok', true,
      'feature_key', v_key,
      'amount', v_existing.amount,
      'currency', v_currency,
      'request_id', p_request_id,
      'idempotent', true
    );
  END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text || ':vip:' || v_key, 0));

  IF public._is_platform_owner(v_uid) THEN
    INSERT INTO public.user_profile_services(
      user_id, feature_key, enabled, settings, purchased_at, updated_at, currency, amount
    ) VALUES (
      v_uid, v_key, true,
      CASE WHEN v_key = 'self_destruct_chat' THEN jsonb_build_object('seconds', 10) ELSE '{}'::jsonb END,
      now(), now(), 'owner_access', 0
    )
    ON CONFLICT(user_id, feature_key) DO UPDATE SET enabled = true, updated_at = now();

    RETURN jsonb_build_object(
      'ok', true,
      'feature_key', v_key,
      'owner_free', true,
      'request_id', p_request_id
    );
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_profile_services
    WHERE user_id = v_uid AND feature_key = v_key
  ) THEN
    UPDATE public.user_profile_services
    SET enabled = true, updated_at = now()
    WHERE user_id = v_uid AND feature_key = v_key;
    RETURN jsonb_build_object(
      'ok', true,
      'feature_key', v_key,
      'reactivated', true,
      'request_id', p_request_id
    );
  END IF;

  SELECT CASE WHEN v_currency = 'points' THEN price_points ELSE price_gems END
  INTO v_price
  FROM public.profile_service_catalog
  WHERE feature_key = v_key AND is_active = true;
  IF v_price IS NULL OR v_price <= 0 THEN RAISE EXCEPTION 'PRICE_NOT_SET'; END IF;

  PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text || ':wallet:' || v_currency, 0));

  IF v_currency = 'points' THEN
    INSERT INTO public.points_wallets(user_id, balance)
    VALUES(v_uid, 0)
    ON CONFLICT(user_id) DO NOTHING;
    INSERT INTO public.points_wallets(user_id, balance)
    VALUES(v_owner, 0)
    ON CONFLICT(user_id) DO NOTHING;

    SELECT balance INTO v_before
    FROM public.points_wallets
    WHERE user_id = v_uid
    FOR UPDATE;
    IF coalesce(v_before, 0) < v_price THEN RAISE EXCEPTION 'INSUFFICIENT_POINTS'; END IF;
    v_after := v_before - v_price;
    UPDATE public.points_wallets
    SET balance = v_after,
        lifetime_spent = lifetime_spent + v_price,
        version = version + 1,
        updated_at = now()
    WHERE user_id = v_uid;
    UPDATE public.points_wallets
    SET balance = balance + v_price,
        lifetime_earned = lifetime_earned + v_price,
        version = version + 1,
        updated_at = now()
    WHERE user_id = v_owner;
  ELSE
    INSERT INTO public.gems_wallets(user_id, balance)
    VALUES(v_uid, 0)
    ON CONFLICT(user_id) DO NOTHING;
    INSERT INTO public.gems_wallets(user_id, balance)
    VALUES(v_owner, 0)
    ON CONFLICT(user_id) DO NOTHING;

    SELECT balance INTO v_before
    FROM public.gems_wallets
    WHERE user_id = v_uid
    FOR UPDATE;
    IF coalesce(v_before, 0) < v_price THEN RAISE EXCEPTION 'INSUFFICIENT_GEMS'; END IF;
    v_after := v_before - v_price;
    UPDATE public.gems_wallets
    SET balance = v_after,
        lifetime_spent = lifetime_spent + v_price,
        version = version + 1,
        updated_at = now()
    WHERE user_id = v_uid;
    UPDATE public.gems_wallets
    SET balance = balance + v_price,
        lifetime_earned = lifetime_earned + v_price,
        version = version + 1,
        updated_at = now()
    WHERE user_id = v_owner;
  END IF;

  INSERT INTO public.user_profile_services(
    user_id, feature_key, enabled, settings, purchased_at, updated_at, currency, amount
  ) VALUES (
    v_uid, v_key, true,
    CASE WHEN v_key = 'self_destruct_chat' THEN jsonb_build_object('seconds', 10) ELSE '{}'::jsonb END,
    now(), now(), v_currency, v_price
  );

  INSERT INTO public.profile_service_orders(buyer_uid, feature_key, currency, amount, request_id)
  VALUES(v_uid, v_key, v_currency, v_price, p_request_id);

  INSERT INTO public.wallet_transactions(
    user_id, currency, amount, balance_before, balance_after,
    transaction_type, reference_type, reference_id, idempotency_key, metadata, created_by
  ) VALUES(
    v_uid, v_currency, -v_price, v_before, v_after,
    'profile_service_purchase', 'profile_service', v_key, p_request_id,
    jsonb_build_object('feature_key', v_key), v_uid
  );

  RETURN jsonb_build_object(
    'ok', true,
    'feature_key', v_key,
    'amount', v_price,
    'currency', v_currency,
    'request_id', p_request_id,
    'owner_uid', v_owner::text
  );
END;
$function$;

REVOKE ALL ON FUNCTION public.purchase_profile_service(text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.purchase_profile_service(text, text, uuid) TO authenticated;

COMMIT;
