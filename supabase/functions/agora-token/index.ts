import { RtcRole, RtcTokenBuilder } from 'npm:agora-token@2.0.5';
import { createClient } from 'jsr:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

// The UID is derived HERE, from the authenticated user id, and returned to the
// client — the client no longer computes it.
//
// Why the old UID_MISMATCH check was removed: the Dart client tried to
// reproduce this exact hash and could not. In JS `(hash ^ ch) * 16777619`
// exceeds 2^53 and loses precision before `>>> 0` truncates it, while Dart's
// 64-bit ints compute it exactly. The two languages therefore produced
// different numbers for the same user, so EVERY call failed with UID_MISMATCH.
// Security is unaffected: the uid still comes from the verified session, so a
// client still cannot choose its own uid — which was the check's only purpose.
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
    const channel = String(body.channel ?? '').trim();
    if (!/^call_[A-Za-z0-9_-]{1,58}$/.test(channel)) return json({ error: 'INVALID_CHANNEL' }, 400);

    const expectedUid = deriveAgoraUid(user.id);

    const callId = channel.substring('call_'.length);
    const { data: callDoc, error: callError } = await supabase
      .from('app_documents')
      .select('doc_id,data')
      .eq('collection_path', 'calls')
      .eq('doc_id', callId)
      .maybeSingle();
    if (callError || !callDoc) return json({ error: 'CALL_NOT_FOUND' }, 404);

    const call = (callDoc.data ?? {}) as Record<string, unknown>;
    const callerUid = String(call.callerUid ?? '');
    const calleeUid = String(call.calleeUid ?? '');
    const status = String(call.status ?? '');
    if (user.id !== callerUid && user.id !== calleeUid) return json({ error: 'FORBIDDEN' }, 403);
    if (!['ringing', 'accepted'].includes(status)) return json({ error: 'CALL_NOT_JOINABLE' }, 409);

    // Token issuance is a paid-feature boundary — but the feature belongs to the
    // CALLER (who starts and pays for the call), not to whoever answers.
    //
    // Proven cause of the 403s (edge logs 2026-10-11 21:01–21:03): this check
    // used to read only a directly-purchased row in user_profile_services for
    // the CURRENT user. So (1) a receiver without the paid feature could never
    // answer, and (2) a caller entitled through a membership — exactly what
    // start_call accepts via has_profile_service_for_user — was refused when
    // fetching the token. Both sides now use the same server function as
    // start_call, applied to the call's caller.
    const { data: callerEntitled, error: entitlementError } = await supabase.rpc(
      'has_profile_service_for_user',
      { p_user_id: callerUid, p_feature_key: 'voice_video_calls' },
    );
    if (entitlementError) {
      console.error('agora-token entitlement check failed', entitlementError);
      return json({ error: 'SERVICE_CHECK_FAILED' }, 500);
    }
    if (callerEntitled !== true) {
      let callerIsOwner = false;
      if (user.id === callerUid) {
        const { data: ownerRows } = await supabase.rpc('is_my_platform_owner');
        callerIsOwner = ownerRows === true;
      }
      if (!callerIsOwner) {
        console.warn('agora-token refused: caller lacks voice_video_calls', { callerUid, requester: user.id });
        return json({ error: 'FEATURE_REQUIRED_VOICE_VIDEO' }, 403);
      }
    }

    const since = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    const { count, error: rateError } = await supabase
      .from('agora_token_issues')
      .select('*', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('issued_at', since);
    if (rateError) return json({ error: 'RATE_LIMIT_LOOKUP_FAILED' }, 500);
    if ((count ?? 0) >= 10) return json({ error: 'RATE_LIMIT' }, 429);

    const appId = Deno.env.get('AGORA_APP_ID');
    const appCertificate = Deno.env.get('AGORA_APP_CERTIFICATE');
    if (!appId || !appCertificate) return json({ error: 'AGORA_SERVER_NOT_CONFIGURED' }, 500);

    // agora-token@2.x takes token/privilege expiry as SECONDS FROM NOW (not an
    // absolute timestamp) plus a 7th privilegeExpire argument. The old call
    // passed an absolute timestamp (~57 years) and omitted privilegeExpire
    // (defaults to 0 = never), so tokens effectively never expired. Now both
    // are a real hour; the app renews via onTokenPrivilegeWillExpire.
    const expiresIn = 3600;
    const expireAt = Math.floor(Date.now() / 1000) + expiresIn;
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channel,
      expectedUid,
      RtcRole.PUBLISHER,
      expiresIn,
      expiresIn,
    );

    const { error: auditError } = await supabase.from('agora_token_issues').insert({ user_id: user.id });
    if (auditError) return json({ error: 'TOKEN_AUDIT_FAILED' }, 500);

    return json({ appId, token, uid: expectedUid, expiresAt: expireAt });
  } catch (e) {
    console.error('agora-token error', e);
    return json({ error: 'INTERNAL_ERROR' }, 500);
  }
});
