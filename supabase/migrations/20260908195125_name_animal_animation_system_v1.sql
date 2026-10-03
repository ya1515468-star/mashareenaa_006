-- MASHAREENA: Name Animal Animation system v1.0
-- Independent from avatar frames, username effects, templates and VIP services.
-- Server-authoritative catalog, ownership, purchase and activation.
BEGIN;

CREATE TABLE IF NOT EXISTS public.name_animation_catalog (
  effect_key text PRIMARY KEY,
  name_ar text NOT NULL,
  category text NOT NULL DEFAULT 'animal',
  asset_path text,
  asset_url text,
  storage_path text,
  size_bytes bigint NOT NULL DEFAULT 0,
  animation_type text NOT NULL DEFAULT 'lottie',
  fps integer NOT NULL DEFAULT 24 CHECK (fps BETWEEN 1 AND 30),
  duration_ms integer NOT NULL DEFAULT 1800 CHECK (duration_ms BETWEEN 1200 AND 2400),
  max_width double precision NOT NULL DEFAULT 46 CHECK (max_width BETWEEN 24 AND 52),
  max_height double precision NOT NULL DEFAULT 36 CHECK (max_height BETWEEN 20 AND 42),
  transparent boolean NOT NULL DEFAULT true,
  loop boolean NOT NULL DEFAULT true,
  price_points bigint NOT NULL DEFAULT 5000 CHECK (price_points >= 0),
  price_gems bigint NOT NULL DEFAULT 50 CHECK (price_gems >= 0),
  owner_free boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_name_animation_effects (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  effect_key text NOT NULL REFERENCES public.name_animation_catalog(effect_key) ON DELETE CASCADE,
  purchased_at timestamptz NOT NULL DEFAULT now(),
  is_active boolean NOT NULL DEFAULT false,
  activated_at timestamptz,
  source_order_id uuid,
  PRIMARY KEY (user_id, effect_key)
);
CREATE INDEX IF NOT EXISTS user_name_animation_effects_active_idx ON public.user_name_animation_effects(user_id,is_active);

ALTER TABLE public.name_animation_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_name_animation_effects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS name_animation_catalog_read ON public.name_animation_catalog;
CREATE POLICY name_animation_catalog_read ON public.name_animation_catalog FOR SELECT TO authenticated USING (is_active = true OR public.is_platform_owner(auth.uid()));
DROP POLICY IF EXISTS name_animation_ownership_self ON public.user_name_animation_effects;
CREATE POLICY name_animation_ownership_self ON public.user_name_animation_effects FOR SELECT TO authenticated USING (user_id = auth.uid() OR public.is_platform_owner(auth.uid()));

INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types)
VALUES ('name-animations','name-animations',true,512000,ARRAY['application/json','text/json']::text[])
ON CONFLICT (id) DO UPDATE SET public=true,file_size_limit=512000,allowed_mime_types=ARRAY['application/json','text/json']::text[];

DROP POLICY IF EXISTS name_animations_public_read ON storage.objects;
CREATE POLICY name_animations_public_read ON storage.objects FOR SELECT TO anon,authenticated USING (bucket_id='name-animations');
DROP POLICY IF EXISTS name_animations_owner_insert ON storage.objects;
CREATE POLICY name_animations_owner_insert ON storage.objects FOR INSERT TO authenticated WITH CHECK (
  bucket_id='name-animations' AND (storage.foldername(name))[1]='catalog'
  AND lower(storage.extension(name))='json' AND private.is_platform_owner_storage()
);
DROP POLICY IF EXISTS name_animations_owner_update ON storage.objects;
CREATE POLICY name_animations_owner_update ON storage.objects FOR UPDATE TO authenticated USING (bucket_id='name-animations' AND private.is_platform_owner_storage()) WITH CHECK (bucket_id='name-animations' AND private.is_platform_owner_storage() AND lower(storage.extension(name))='json');
DROP POLICY IF EXISTS name_animations_owner_delete ON storage.objects;
CREATE POLICY name_animations_owner_delete ON storage.objects FOR DELETE TO authenticated USING (bucket_id='name-animations' AND private.is_platform_owner_storage());

CREATE OR REPLACE FUNCTION public.get_name_animation_catalog()
RETURNS SETOF public.name_animation_catalog
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT * FROM public.name_animation_catalog
  WHERE is_active=true OR public.is_platform_owner(auth.uid())
  ORDER BY sort_order,effect_key;
$$;

CREATE OR REPLACE FUNCTION public.get_my_name_animation_effects()
RETURNS TABLE(effect_key text,purchased_at timestamptz,is_active boolean,activated_at timestamptz)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT e.effect_key,e.purchased_at,e.is_active,e.activated_at
  FROM public.user_name_animation_effects e
  WHERE e.user_id=auth.uid()
  ORDER BY e.purchased_at,e.effect_key;
$$;

CREATE OR REPLACE FUNCTION public.get_active_name_animation(p_user_id uuid)
RETURNS jsonb
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=''
AS $$
  SELECT CASE WHEN c.effect_key IS NULL THEN NULL ELSE jsonb_build_object(
    'effect_key',c.effect_key,'name_ar',c.name_ar,'category',c.category,'asset_path',c.asset_path,
    'asset_url',c.asset_url,'storage_path',c.storage_path,'size_bytes',c.size_bytes,
    'animation_type',c.animation_type,'fps',c.fps,'duration_ms',c.duration_ms,'max_width',c.max_width,
    'max_height',c.max_height,'transparent',c.transparent,'loop',c.loop,'price_points',c.price_points,
    'price_gems',c.price_gems,'owner_free',c.owner_free,'is_active',c.is_active,'sort_order',c.sort_order,
    'metadata',c.metadata
  ) END
  FROM public.user_name_animation_effects e
  JOIN public.name_animation_catalog c ON c.effect_key=e.effect_key AND c.is_active=true
  WHERE e.user_id=p_user_id AND e.is_active=true
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.purchase_name_animation(p_effect_key text,p_currency text,p_request_id uuid default gen_random_uuid())
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE
  v_uid uuid:=auth.uid(); v_key text:=lower(trim(coalesce(p_effect_key,''))); v_currency text:=lower(trim(coalesce(p_currency,'')));
  v_item public.name_animation_catalog%rowtype; v_price bigint:=0; v_before bigint:=0; v_after bigint:=0; v_owner boolean:=false;
  v_existing public.idempotency_requests%rowtype; v_response jsonb;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  IF p_request_id IS NULL THEN RAISE EXCEPTION 'REQUEST_ID_REQUIRED'; END IF;
  IF v_currency NOT IN ('points','gems') THEN RAISE EXCEPTION 'INVALID_CURRENCY'; END IF;
  PERFORM pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
  SELECT * INTO v_existing FROM public.idempotency_requests WHERE request_id=p_request_id FOR UPDATE;
  IF FOUND THEN
    IF v_existing.user_id<>v_uid OR v_existing.operation<>'purchase_name_animation' OR coalesce(v_existing.response->>'effect_key','')<>v_key THEN RAISE EXCEPTION 'REQUEST_ID_REPLAY_FORBIDDEN'; END IF;
    RETURN v_existing.response;
  END IF;
  SELECT * INTO v_item FROM public.name_animation_catalog WHERE effect_key=v_key AND is_active=true FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'ANIMATION_NOT_FOUND'; END IF;
  IF v_item.transparent=false THEN RAISE EXCEPTION 'ANIMATION_NOT_TRANSPARENT'; END IF;
  v_owner:=coalesce(public.is_platform_owner(v_uid),false);
  IF EXISTS(SELECT 1 FROM public.user_name_animation_effects e WHERE e.user_id=v_uid AND e.effect_key=v_key) THEN
    v_response:=jsonb_build_object('ok',true,'effect_key',v_key,'currency',v_currency,'amount',0,'already_owned',true,'request_id',p_request_id);
    INSERT INTO public.idempotency_requests(request_id,user_id,operation,response) VALUES(p_request_id,v_uid,'purchase_name_animation',v_response);
    RETURN v_response;
  END IF;
  v_price:=CASE WHEN v_currency='points' THEN v_item.price_points ELSE v_item.price_gems END;
  IF v_owner OR v_item.owner_free THEN
    INSERT INTO public.user_name_animation_effects(user_id,effect_key) VALUES(v_uid,v_key);
    v_response:=jsonb_build_object('ok',true,'effect_key',v_key,'currency','owner_free','amount',0,'request_id',p_request_id);
    INSERT INTO public.idempotency_requests(request_id,user_id,operation,response) VALUES(p_request_id,v_uid,'purchase_name_animation',v_response);
    RETURN v_response;
  END IF;
  IF v_price<=0 THEN RAISE EXCEPTION 'PRICE_NOT_SET'; END IF;
  IF v_currency='points' THEN
    PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text||':name_animation:points',0));
    INSERT INTO public.points_wallets(user_id,balance) VALUES(v_uid,0) ON CONFLICT(user_id) DO NOTHING;
    SELECT balance INTO v_before FROM public.points_wallets WHERE user_id=v_uid FOR UPDATE;
    IF coalesce(v_before,0)<v_price THEN RAISE EXCEPTION 'INSUFFICIENT_POINTS'; END IF;
    v_after:=v_before-v_price;
    UPDATE public.points_wallets SET balance=v_after,lifetime_spent=lifetime_spent+v_price,version=version+1,updated_at=now() WHERE user_id=v_uid;
  ELSE
    PERFORM pg_advisory_xact_lock(hashtextextended(v_uid::text||':name_animation:gems',0));
    INSERT INTO public.gems_wallets(user_id,balance) VALUES(v_uid,0) ON CONFLICT(user_id) DO NOTHING;
    SELECT balance INTO v_before FROM public.gems_wallets WHERE user_id=v_uid FOR UPDATE;
    IF coalesce(v_before,0)<v_price THEN RAISE EXCEPTION 'INSUFFICIENT_GEMS'; END IF;
    v_after:=v_before-v_price;
    UPDATE public.gems_wallets SET balance=v_after,lifetime_spent=lifetime_spent+v_price,version=version+1,updated_at=now() WHERE user_id=v_uid;
  END IF;
  INSERT INTO public.user_name_animation_effects(user_id,effect_key) VALUES(v_uid,v_key);
  INSERT INTO public.wallet_transactions(user_id,currency,amount,balance_before,balance_after,transaction_type,reference_type,reference_id,idempotency_key,metadata,created_by)
  VALUES(v_uid,v_currency,-v_price,v_before,v_after,'name_animation_purchase','name_animation',v_key,p_request_id,jsonb_build_object('effect_key',v_key),v_uid);
  v_response:=jsonb_build_object('ok',true,'effect_key',v_key,'currency',v_currency,'amount',v_price,'request_id',p_request_id);
  INSERT INTO public.idempotency_requests(request_id,user_id,operation,response) VALUES(p_request_id,v_uid,'purchase_name_animation',v_response);
  RETURN v_response;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_name_animation(p_effect_key text)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_uid uuid:=auth.uid(); v_key text:=nullif(lower(trim(coalesce(p_effect_key,''))),''); v_owner boolean:=false;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'AUTH_REQUIRED'; END IF;
  v_owner:=coalesce(public.is_platform_owner(v_uid),false);
  IF v_key IS NULL THEN
    UPDATE public.user_name_animation_effects SET is_active=false,activated_at=null WHERE user_id=v_uid;
    RETURN jsonb_build_object('ok',true,'effect_key',null);
  END IF;
  IF NOT EXISTS(SELECT 1 FROM public.name_animation_catalog c WHERE c.effect_key=v_key AND c.is_active=true AND c.transparent=true) THEN RAISE EXCEPTION 'ANIMATION_NOT_AVAILABLE'; END IF;
  IF NOT v_owner AND NOT EXISTS(SELECT 1 FROM public.user_name_animation_effects e WHERE e.user_id=v_uid AND e.effect_key=v_key) THEN RAISE EXCEPTION 'ANIMATION_NOT_OWNED'; END IF;
  UPDATE public.user_name_animation_effects SET is_active=false,activated_at=null WHERE user_id=v_uid;
  INSERT INTO public.user_name_animation_effects(user_id,effect_key,is_active,activated_at) VALUES(v_uid,v_key,true,now())
  ON CONFLICT(user_id,effect_key) DO UPDATE SET is_active=true,activated_at=excluded.activated_at;
  RETURN jsonb_build_object('ok',true,'effect_key',v_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_create_name_animation(
  p_effect_key text,p_name_ar text,p_category text,p_asset_url text,p_storage_path text,p_size_bytes bigint,
  p_fps integer,p_duration_ms integer,p_max_width double precision,p_max_height double precision,
  p_price_points bigint,p_price_gems bigint,p_owner_free boolean,p_metadata jsonb default '{}'::jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
DECLARE v_uid uuid:=auth.uid(); v_key text:=lower(trim(coalesce(p_effect_key,''))); v_sort integer;
BEGIN
  IF v_uid IS NULL OR NOT public.is_platform_owner(v_uid) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF v_key='' OR v_key !~ '^[a-z0-9_]+$' THEN RAISE EXCEPTION 'INVALID_EFFECT_KEY'; END IF;
  IF trim(coalesce(p_name_ar,''))='' THEN RAISE EXCEPTION 'NAME_REQUIRED'; END IF;
  IF p_asset_url IS NULL OR p_asset_url !~ '^https?://' THEN RAISE EXCEPTION 'INVALID_ASSET_URL'; END IF;
  IF p_storage_path IS NULL OR p_storage_path !~ '^catalog/[A-Za-z0-9_-]+[.]json$' THEN RAISE EXCEPTION 'INVALID_STORAGE_PATH'; END IF;
  IF p_size_bytes IS NULL OR p_size_bytes<1 OR p_size_bytes>512000 THEN RAISE EXCEPTION 'INVALID_SIZE'; END IF;
  IF p_fps<1 OR p_fps>30 OR p_duration_ms<1200 OR p_duration_ms>2400 THEN RAISE EXCEPTION 'INVALID_ANIMATION_TIMING'; END IF;
  IF p_max_width<24 OR p_max_width>52 OR p_max_height<20 OR p_max_height>42 THEN RAISE EXCEPTION 'INVALID_ANIMATION_BOUNDS'; END IF;
  IF p_price_points<0 OR p_price_gems<0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;
  SELECT coalesce(max(sort_order),0)+1 INTO v_sort FROM public.name_animation_catalog;
  INSERT INTO public.name_animation_catalog(effect_key,name_ar,category,asset_url,storage_path,size_bytes,animation_type,fps,duration_ms,max_width,max_height,transparent,loop,price_points,price_gems,owner_free,is_active,sort_order,metadata)
  VALUES(v_key,left(trim(p_name_ar),160),coalesce(nullif(trim(p_category),''),'animal'),p_asset_url,p_storage_path,p_size_bytes,'lottie',p_fps,p_duration_ms,p_max_width,p_max_height,true,true,p_price_points,p_price_gems,coalesce(p_owner_free,false),true,v_sort,coalesce(p_metadata,'{}'::jsonb))
  ON CONFLICT(effect_key) DO UPDATE SET name_ar=excluded.name_ar,category=excluded.category,asset_url=excluded.asset_url,storage_path=excluded.storage_path,size_bytes=excluded.size_bytes,fps=excluded.fps,duration_ms=excluded.duration_ms,max_width=excluded.max_width,max_height=excluded.max_height,price_points=excluded.price_points,price_gems=excluded.price_gems,owner_free=excluded.owner_free,is_active=true,metadata=excluded.metadata,updated_at=now();
  RETURN jsonb_build_object('ok',true,'effect_key',v_key);
END;
$$;

CREATE OR REPLACE FUNCTION public.update_name_animation_price(p_effect_key text,p_price_points bigint,p_price_gems bigint,p_is_active boolean default true)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path=''
AS $$
BEGIN
  IF NOT public.is_platform_owner(auth.uid()) THEN RAISE EXCEPTION 'FORBIDDEN'; END IF;
  IF p_price_points<0 OR p_price_gems<0 THEN RAISE EXCEPTION 'INVALID_PRICE'; END IF;
  UPDATE public.name_animation_catalog SET price_points=p_price_points,price_gems=p_price_gems,is_active=coalesce(p_is_active,true),updated_at=now() WHERE effect_key=lower(trim(p_effect_key));
  IF NOT FOUND THEN RAISE EXCEPTION 'ANIMATION_NOT_FOUND'; END IF;
  RETURN jsonb_build_object('ok',true,'effect_key',lower(trim(p_effect_key)),'price_points',p_price_points,'price_gems',p_price_gems);
END;
$$;

REVOKE ALL ON FUNCTION public.get_name_animation_catalog() FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.get_name_animation_catalog() TO authenticated;
REVOKE ALL ON FUNCTION public.get_my_name_animation_effects() FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.get_my_name_animation_effects() TO authenticated;
REVOKE ALL ON FUNCTION public.get_active_name_animation(uuid) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.get_active_name_animation(uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.purchase_name_animation(text,text,uuid) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.purchase_name_animation(text,text,uuid) TO authenticated;
REVOKE ALL ON FUNCTION public.set_name_animation(text) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.set_name_animation(text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_create_name_animation(text,text,text,text,text,bigint,integer,integer,double precision,double precision,bigint,bigint,boolean,jsonb) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.admin_create_name_animation(text,text,text,text,text,bigint,integer,integer,double precision,double precision,bigint,bigint,boolean,jsonb) TO authenticated;
REVOKE ALL ON FUNCTION public.update_name_animation_price(text,bigint,bigint,boolean) FROM PUBLIC,anon; GRANT EXECUTE ON FUNCTION public.update_name_animation_price(text,bigint,bigint,boolean) TO authenticated;

-- First 40 launch keys. The JSON files are bundled separately and loaded lazily by Flutter.
INSERT INTO public.name_animation_catalog(effect_key,name_ar,category,asset_path,price_points,price_gems,owner_free,is_active,sort_order,metadata)
VALUES
('lion_animal','أسد','land','assets/name_animations/animals/animal_lion.json',5000,50,false,true,1,'{"placement":"above_name","anchor":"bottom_center"}'),
('cheetah_animal','فهد','land','assets/name_animations/animals/animal_cheetah.json',5200,52,false,true,2,'{"placement":"above_name","anchor":"bottom_center"}'),
('tiger_animal','نمر','land','assets/name_animations/animals/animal_tiger.json',5400,54,false,true,3,'{"placement":"above_name","anchor":"bottom_center"}'),
('wolf_animal','ذئب','land','assets/name_animations/animals/animal_wolf.json',5600,56,false,true,4,'{"placement":"above_name","anchor":"bottom_center"}'),
('fox_animal','ثعلب','land','assets/name_animations/animals/animal_fox.json',5800,58,false,true,5,'{"placement":"above_name","anchor":"bottom_center"}'),
('bear_animal','دب','land','assets/name_animations/animals/animal_bear.json',6000,60,false,true,6,'{"placement":"above_name","anchor":"bottom_center"}'),
('panda_animal','باندا','land','assets/name_animations/animals/animal_panda.json',6200,62,false,true,7,'{"placement":"above_name","anchor":"bottom_center"}'),
('cat_animal','قطة','home','assets/name_animations/animals/animal_cat.json',4500,45,false,true,8,'{"placement":"above_name","anchor":"bottom_center"}'),
('dog_animal','كلب','home','assets/name_animations/animals/animal_dog.json',4500,45,false,true,9,'{"placement":"above_name","anchor":"bottom_center"}'),
('horse_animal','حصان','land','assets/name_animations/animals/animal_horse.json',6500,65,false,true,10,'{"placement":"above_name","anchor":"bottom_center"}'),
('deer_animal','غزال','land','assets/name_animations/animals/animal_deer.json',6700,67,false,true,11,'{"placement":"above_name","anchor":"bottom_center"}'),
('rabbit_animal','أرنب','land','assets/name_animations/animals/animal_rabbit.json',4700,47,false,true,12,'{"placement":"above_name","anchor":"bottom_center"}'),
('monkey_animal','قرد','land','assets/name_animations/animals/animal_monkey.json',6900,69,false,true,13,'{"placement":"above_name","anchor":"bottom_center"}'),
('gorilla_animal','غوريلا','land','assets/name_animations/animals/animal_gorilla.json',7100,71,false,true,14,'{"placement":"above_name","anchor":"bottom_center"}'),
('elephant_animal','فيل','land','assets/name_animations/animals/animal_elephant.json',7300,73,false,true,15,'{"placement":"above_name","anchor":"bottom_center"}'),
('giraffe_animal','زرافة','land','assets/name_animations/animals/animal_giraffe.json',7500,75,false,true,16,'{"placement":"above_name","anchor":"bottom_center"}'),
('zebra_animal','حمار وحشي','land','assets/name_animations/animals/animal_zebra.json',7700,77,false,true,17,'{"placement":"above_name","anchor":"bottom_center"}'),
('rhino_animal','وحيد القرن','land','assets/name_animations/animals/animal_rhino.json',7900,79,false,true,18,'{"placement":"above_name","anchor":"bottom_center"}'),
('hippo_animal','فرس النهر','land','assets/name_animations/animals/animal_hippo.json',8100,81,false,true,19,'{"placement":"above_name","anchor":"bottom_center"}'),
('crocodile_animal','تمساح','reptile','assets/name_animations/animals/animal_crocodile.json',8300,83,false,true,20,'{"placement":"above_name","anchor":"bottom_center"}'),
('snake_animal','أفعى','reptile','assets/name_animations/animals/animal_snake.json',8500,85,false,true,21,'{"placement":"above_name","anchor":"bottom_center"}'),
('chameleon_animal','حرباء','reptile','assets/name_animations/animals/animal_chameleon.json',8700,87,false,true,22,'{"placement":"above_name","anchor":"bottom_center"}'),
('turtle_animal','سلحفاة','reptile','assets/name_animations/animals/animal_turtle.json',4900,49,false,true,23,'{"placement":"above_name","anchor":"bottom_center"}'),
('lizard_animal','سحلية','reptile','assets/name_animations/animals/animal_lizard.json',5100,51,false,true,24,'{"placement":"above_name","anchor":"bottom_center"}'),
('eagle_animal','نسر','bird','assets/name_animations/animals/animal_eagle.json',9000,90,false,true,25,'{"placement":"above_name","anchor":"bottom_center"}'),
('hawk_animal','صقر','bird','assets/name_animations/animals/animal_hawk.json',9200,92,false,true,26,'{"placement":"above_name","anchor":"bottom_center"}'),
('owl_animal','بومة','bird','assets/name_animations/animals/animal_owl.json',9400,94,false,true,27,'{"placement":"above_name","anchor":"bottom_center"}'),
('parrot_animal','ببغاء','bird','assets/name_animations/animals/animal_parrot.json',5600,56,false,true,28,'{"placement":"above_name","anchor":"bottom_center"}'),
('peacock_animal','طاووس','bird','assets/name_animations/animals/animal_peacock.json',9600,96,false,true,29,'{"placement":"above_name","anchor":"bottom_center"}'),
('raven_animal','غراب','bird','assets/name_animations/animals/animal_raven.json',9800,98,false,true,30,'{"placement":"above_name","anchor":"bottom_center"}'),
('dove_animal','حمامة','bird','assets/name_animations/animals/animal_dove.json',4300,43,false,true,31,'{"placement":"above_name","anchor":"bottom_center"}'),
('penguin_animal','بطريق','bird','assets/name_animations/animals/animal_penguin.json',5700,57,false,true,32,'{"placement":"above_name","anchor":"bottom_center"}'),
('butterfly_animal','فراشة','insect','assets/name_animations/animals/animal_butterfly.json',4000,40,false,true,33,'{"placement":"above_name","anchor":"bottom_center"}'),
('bee_animal','نحلة','insect','assets/name_animations/animals/animal_bee.json',4100,41,false,true,34,'{"placement":"above_name","anchor":"bottom_center"}'),
('beetle_animal','خنفساء','insect','assets/name_animations/animals/animal_beetle.json',4200,42,false,true,35,'{"placement":"above_name","anchor":"bottom_center"}'),
('scorpion_animal','عقرب','insect','assets/name_animations/animals/animal_scorpion.json',8800,88,false,true,36,'{"placement":"above_name","anchor":"bottom_center"}'),
('spider_animal','عنكبوت','insect','assets/name_animations/animals/animal_spider.json',6200,62,false,true,37,'{"placement":"above_name","anchor":"bottom_center"}'),
('dolphin_animal','دولفين','marine','assets/name_animations/animals/animal_dolphin.json',6100,61,false,true,38,'{"placement":"above_name","anchor":"bottom_center"}'),
('shark_animal','قرش','marine','assets/name_animations/animals/animal_shark.json',8800,88,false,true,39,'{"placement":"above_name","anchor":"bottom_center"}'),
('whale_animal','حوت','marine','assets/name_animations/animals/animal_whale.json',9300,93,false,true,40,'{"placement":"above_name","anchor":"bottom_center"}')
ON CONFLICT(effect_key) DO UPDATE SET name_ar=excluded.name_ar,category=excluded.category,asset_path=excluded.asset_path,price_points=excluded.price_points,price_gems=excluded.price_gems,is_active=true,sort_order=excluded.sort_order,metadata=excluded.metadata,updated_at=now();

COMMIT;
