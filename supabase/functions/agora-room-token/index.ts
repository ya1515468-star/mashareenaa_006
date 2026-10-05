import { RtcRole, RtcTokenBuilder } from 'npm:agora-token@2.0.5';
import { createClient } from 'jsr:@supabase/supabase-js@2';

// رموز Agora لصوت الغرف (كراسي المايك). منفصلة عن agora-token الخاصة بالمكالمات.
// قرار الوصول كله في دالة الخادم room_audio_access (صلاحيات كاملة):
//   'publisher'  → جالس على كرسي غير مكتوم والمايك مفعّل
//   'subscriber' → مستمع
//   'denied'     → محظور/مطرود أو غرفة غير موجودة
// أي فشل في الفحص يُرفض (fail closed)، فلا يُمنح رمز من غير تحقق.

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function deriveAgoraUid(userId: string): number {
  let hash = 2166136261;
  for (const ch of userId) {
    hash = (hash ^ ch.charCodeAt(0)) * 16777619;
    hash >>>= 0;
  }
  hash &= 0x7fffffff;
  return hash === 0 ? 1 : hash;
}

function json(message: unknown, status = 200) {
  return new Response(JSON.stringify(message), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);
    const authHeader = req.headers.get('Authorization');
    if (!authHeader?.startsWith('Bearer ')) return json({ error: 'AUTH_REQUIRED' }, 401);

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );
    const { data: { user }, error } = await supabase.auth.getUser();
    if (error || !user) return json({ error: 'AUTH_REQUIRED' }, 401);

    const body = await req.json().catch(() => ({}));
    const roomId = String(body.roomId ?? '').trim();
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(roomId)) {
      return json({ error: 'INVALID_ROOM' }, 400);
    }

    const { data: access, error: accessError } = await supabase.rpc('room_audio_access', { p_room: roomId });
    if (accessError || (access !== 'publisher' && access !== 'subscriber')) {
      return json({ error: 'ROOM_ACCESS_DENIED' }, 403);
    }
    const publisher = access === 'publisher';

    const since = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { count, error: rateError } = await supabase
      .from('agora_token_issues')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('issued_at', since);
    if (rateError) return json({ error: 'RATE_LIMIT_LOOKUP_FAILED' }, 500);
    if ((count ?? 0) >= 30) return json({ error: 'RATE_LIMIT' }, 429);

    const appId = Deno.env.get('AGORA_APP_ID');
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE');
    if (!appId || !appCertificate) return json({ error: 'AGORA_SERVER_NOT_CONFIGURED' }, 500);

    const uid = deriveAgoraUid(user.id);
    const channel = `room_${roomId.replace(/-/g, '')}`;
    const expiresIn = publisher ? 600 : 3600;
    const expireAt = Math.floor(Date.now() / 1000) + expiresIn;
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId, appCertificate, channel, uid,
      publisher ? RtcRole.PUBLISHER : RtcRole.SUBSCRIBER,
      expireAt,
    );

    const { error: auditError } = await supabase.from('agora_token_issues').insert({ user_id: user.id });
    if (auditError) return json({ error: 'TOKEN_AUDIT_FAILED' }, 500);

    return json({ appId, token, uid, channel, publisher, expiresAt: expireAt });
  } catch (e) {
    console.error('agora-room-token error', e);
    return json({ error: 'INTERNAL_ERROR' }, 500);
  }
});
