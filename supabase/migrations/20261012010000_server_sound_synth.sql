-- مولّد نغمات خادمي: يبني ملف WAV (16-bit mono) من وصف طبقات قصير ويخزّنه
-- في app_sounds — فلا تُرفع ملفات صوت كبيرة ولا تدخل الأصول في المشروع.
-- كل طبقة: {"w":"sine|square|tri|noise","f0":Hz,"f1":Hz,"at":ثانية,"dur":ثانية,
--            "vol":0..1,"decay":معامل تخامد أُسّي,"am":تردد ارتعاش اختياري}
create or replace function private.synth_wav_b64(p_layers jsonb, p_total numeric default null, p_rate int default 16000)
returns text language sql volatile set search_path to '' as $$
with lay as (
  select l, coalesce((l->>'at')::float8,0) as at_s, (l->>'dur')::float8 as dur,
         coalesce(l->>'w','sine') as w, coalesce((l->>'f0')::float8,440) as f0,
         coalesce((l->>'f1')::float8,(l->>'f0')::float8,440) as f1,
         coalesce((l->>'vol')::float8,0.5) as vol, coalesce((l->>'decay')::float8,0) as dk,
         coalesce((l->>'am')::float8,0) as am
  from jsonb_array_elements(p_layers) l
), smp as (
  select (round(lay.at_s*p_rate)::int + i) as idx,
         lay.vol
         * least(1.0, (i::float8/p_rate)/0.004)
         * least(1.0, greatest(0.0, (lay.dur - i::float8/p_rate)/0.012))
         * exp(-lay.dk * i::float8/p_rate)
         * (case when lay.am>0 then 0.55+0.45*sin(2*pi()*lay.am*i::float8/p_rate) else 1 end)
         * (case lay.w
              when 'noise' then random()*2-1
              when 'square' then sign(sin(2*pi()*(lay.f0*(i::float8/p_rate) + (lay.f1-lay.f0)*(i::float8/p_rate)^2/(2*lay.dur))))*0.6
              when 'tri' then (2/pi())*asin(sin(2*pi()*(lay.f0*(i::float8/p_rate) + (lay.f1-lay.f0)*(i::float8/p_rate)^2/(2*lay.dur))))
              else sin(2*pi()*(lay.f0*(i::float8/p_rate) + (lay.f1-lay.f0)*(i::float8/p_rate)^2/(2*lay.dur))) end) as v
  from lay, generate_series(0, greatest(1, ceil(lay.dur*p_rate)::int) - 1) i
), total as (
  select greatest(coalesce(max(idx),0)+1, coalesce(ceil(p_total*p_rate)::int,0)) as n from smp
), mixed as (
  select g as idx, coalesce(sum(s.v),0) as v
  from total, generate_series(0, total.n-1) g left join smp s on s.idx=g
  group by g
), pcm as (
  select string_agg(
           lpad(to_hex((round(greatest(-1,least(1,v))*32000)::int & 65535) & 255),2,'0') ||
           lpad(to_hex(((round(greatest(-1,least(1,v))*32000)::int & 65535) >> 8) & 255),2,'0'),
           '' order by idx) as hex,
         count(*)*2 as nbytes
  from mixed
)
select translate(encode(
  convert_to('RIFF','UTF8')
  || decode(lpad(to_hex((36+nbytes) & 255),2,'0')||lpad(to_hex(((36+nbytes)>>8)&255),2,'0')||lpad(to_hex(((36+nbytes)>>16)&255),2,'0')||lpad(to_hex(((36+nbytes)>>24)&255),2,'0'),'hex')
  || convert_to('WAVEfmt ','UTF8')
  || decode('10000000'||'0100'||'0100','hex')
  || decode(lpad(to_hex(p_rate & 255),2,'0')||lpad(to_hex((p_rate>>8)&255),2,'0')||'0000','hex')
  || decode(lpad(to_hex((p_rate*2) & 255),2,'0')||lpad(to_hex(((p_rate*2)>>8)&255),2,'0')||lpad(to_hex(((p_rate*2)>>16)&255),2,'0')||'00','hex')
  || decode('0200'||'1000','hex')
  || convert_to('data','UTF8')
  || decode(lpad(to_hex(nbytes & 255),2,'0')||lpad(to_hex((nbytes>>8)&255),2,'0')||lpad(to_hex((nbytes>>16)&255),2,'0')||lpad(to_hex((nbytes>>24)&255),2,'0'),'hex')
  || decode(hex,'hex'), 'base64'), E'\n', '')
from pcm;
$$;
revoke all on function private.synth_wav_b64(jsonb, numeric, int) from public, anon, authenticated;

create or replace function private.upsert_synth_sound(p_key text, p_label text, p_layers jsonb, p_total numeric default null)
returns integer language plpgsql security definer set search_path to '' as $$
declare b text;
begin
  b := private.synth_wav_b64(p_layers, p_total);
  insert into public.app_sounds(key, label, mime, data_b64, updated_at)
  values (p_key, p_label, 'audio/wav', b, now())
  on conflict (key) do update set label = excluded.label, mime = excluded.mime,
    data_b64 = excluded.data_b64, updated_at = now();
  return length(b);
end $$;
revoke all on function private.upsert_synth_sound(text, text, jsonb, numeric) from public, anon, authenticated;
