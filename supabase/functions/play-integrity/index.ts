// التحقّق من نزاهة التطبيق عبر Google Play Integrity API.
//
// المبدأ: العميل لا يُصدِّق على نفسه. العميل يطلب nonce من الخادم، يطلب من
// Google رمز نزاهة مرتبطًا به، ويرسله هنا. هذه الدالة وحدها تفكّ الرمز عند
// Google بمفتاح حساب خدمة لا يملكه العميل، ثم تخزّن الحكم.
//
// ما يكشفه فعلًا:
//  • تطبيق معدَّل أو مُعاد توقيعه  ⇒ appRecognitionVerdict ≠ PLAY_RECOGNIZED
//  • جهاز مكسور الحماية أو محاكٍ    ⇒ غياب MEETS_DEVICE_INTEGRITY
//  • نسخة مقرصنة بلا ترخيص Play    ⇒ appLicensingVerdict ≠ LICENSED
//
// ⚠️ لا يعمل حكم PLAY_RECOGNIZED إلا لنسخة مثبَّتة من Google Play (ولو على
// مسار اختبار داخلي). النسخ الجانبية تعطي UNRECOGNIZED_VERSION دائمًا.
// لذلك الوضع الافتراضي «مراقبة»: يُسجَّل الحكم ولا يُمنع أحد، حتى تضبط
// INTEGRITY_ENFORCE=true بعد نشر التطبيق على Play.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const PACKAGE = Deno.env.get('ANDROID_PACKAGE_NAME') ?? 'com.mashareena.mashareena';
const ENFORCE = (Deno.env.get('INTEGRITY_ENFORCE') ?? 'false').toLowerCase() === 'true';

// ───────── توقيع JWT لحساب الخدمة (RS256) للحصول على رمز وصول Google ─────────
function b64url(data: ArrayBuffer | Uint8Array): string {
  const bytes = data instanceof Uint8Array ? data : new Uint8Array(data);
  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
  return btoa(bin).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

function pemToPkcs8(pem: string): Uint8Array {
  const body = pem.replace(/-----BEGIN PRIVATE KEY-----/, '')
                  .replace(/-----END PRIVATE KEY-----/, '')
                  .replace(/\s+/g, '');
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function googleAccessToken(sa: { client_email: string; private_key: string }): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = b64url(new TextEncoder().encode(JSON.stringify({ alg: 'RS256', typ: 'JWT' })));
  const claims = b64url(new TextEncoder().encode(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/playintegrity',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  })));
  const signingInput = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemToPkcs8(sa.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const sig = await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(signingInput));
  const assertion = `${signingInput}.${b64url(sig)}`;

  const r = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!r.ok) throw new Error(`GOOGLE_TOKEN_${r.status}:${(await r.text()).slice(0, 200)}`);
  return (await r.json()).access_token as string;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

  const url = Deno.env.get('SUPABASE_URL')!;
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: req.headers.get('Authorization') ?? '' } },
  });

  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: 'AUTH_REQUIRED' }, 401);
  const uid = userData.user.id;

  let body: { token?: string; nonce?: string };
  try { body = await req.json(); } catch { return json({ error: 'INVALID_JSON' }, 400); }
  const token = (body.token ?? '').toString();
  const nonce = (body.nonce ?? '').toString();
  if (!token || !nonce) return json({ error: 'TOKEN_AND_NONCE_REQUIRED' }, 400);

  // الـnonce يجب أن يخصّ هذا المستخدم، غير مستهلَك، وعمره أقل من دقيقتين.
  const { data: nrow } = await admin.from('integrity_nonces')
    .select('nonce,user_id,created_at,used_at').eq('nonce', nonce).maybeSingle();
  if (!nrow || nrow.user_id !== uid) return json({ error: 'NONCE_INVALID' }, 400);
  if (nrow.used_at) return json({ error: 'NONCE_ALREADY_USED' }, 400);
  if (Date.now() - new Date(nrow.created_at).getTime() > 120_000) {
    return json({ error: 'NONCE_EXPIRED' }, 400);
  }
  await admin.from('integrity_nonces').update({ used_at: new Date().toISOString() }).eq('nonce', nonce);

  const saRaw = Deno.env.get('GOOGLE_SERVICE_ACCOUNT_JSON');
  if (!saRaw) {
    // غير مهيّأ بعد: نسجّل المحاولة ولا نمنع أحدًا.
    await admin.from('integrity_attestations').insert({
      user_id: uid, passed: !ENFORCE, app_verdict: 'UNCONFIGURED',
      raw: { error: 'GOOGLE_SERVICE_ACCOUNT_JSON missing' },
    });
    return json({ ok: !ENFORCE, configured: false, enforced: ENFORCE, verdict: 'UNCONFIGURED' });
  }

  try {
    const sa = JSON.parse(saRaw);
    const access = await googleAccessToken(sa);
    const r = await fetch(
      `https://playintegrity.googleapis.com/v1/${encodeURIComponent(PACKAGE)}:decodeIntegrityToken`,
      {
        method: 'POST',
        headers: { Authorization: `Bearer ${access}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({ integrity_token: token }),
      },
    );
    if (!r.ok) throw new Error(`DECODE_${r.status}:${(await r.text()).slice(0, 300)}`);
    const payload = (await r.json())?.tokenPayloadExternal ?? {};

    const appVerdict: string = payload?.appIntegrity?.appRecognitionVerdict ?? 'UNEVALUATED';
    const deviceVerdict: string[] = payload?.deviceIntegrity?.deviceRecognitionVerdict ?? [];
    const licensing: string = payload?.accountDetails?.appLicensingVerdict ?? 'UNEVALUATED';
    const pkg: string = payload?.appIntegrity?.packageName ?? '';
    // الـnonce المُعاد من Google يجب أن يطابق ما أصدرناه — هذا ما يمنع
    // إعادة استخدام رمز نزاهة التُقط من جهاز سليم آخر.
    const echoed: string = payload?.requestDetails?.requestHash
      ?? payload?.requestDetails?.nonce ?? '';

    const nonceOk = echoed === nonce;
    const strictPass =
      nonceOk &&
      pkg === PACKAGE &&
      appVerdict === 'PLAY_RECOGNIZED' &&
      deviceVerdict.includes('MEETS_DEVICE_INTEGRITY') &&
      licensing === 'LICENSED';

    // في وضع المراقبة نسجّل الحكم الحقيقي لكن لا نمنع.
    const passed = ENFORCE ? strictPass : true;

    await admin.from('integrity_attestations').insert({
      user_id: uid,
      app_verdict: appVerdict,
      device_verdict: deviceVerdict,
      licensing_verdict: licensing,
      package_name: pkg,
      passed,
      raw: { strictPass, nonceOk, enforced: ENFORCE, payload },
    });

    return json({
      ok: passed, enforced: ENFORCE, strictPass, configured: true,
      verdict: { app: appVerdict, device: deviceVerdict, licensing, nonceOk },
    });
  } catch (e) {
    const msg = String((e as Error)?.message ?? e).slice(0, 300);
    await admin.from('integrity_attestations').insert({
      user_id: uid, passed: !ENFORCE, app_verdict: 'ERROR', raw: { error: msg },
    });
    console.error('play-integrity', msg);
    return json({ ok: !ENFORCE, enforced: ENFORCE, error: 'VERIFY_FAILED', detail: msg }, ENFORCE ? 403 : 200);
  }
});
