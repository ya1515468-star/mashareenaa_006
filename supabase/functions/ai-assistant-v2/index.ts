// المساعد الذكي — نسخة "يفهم السياق وينفّذ".
//
// ما تغيّر جذريًا عن النسخة السابقة:
//  1) ذاكرة محادثة: العميل يرسل آخر أدوار المحادثة (history)، فيفهم
//     "عدّلها" و"أريد مثلها لكن أحمر" و"وكم سعرها؟".
//  2) موجِّه نوايا بالذكاء نفسه (route): بدل كلمات مفتاحية ثابتة في العميل
//     وأزرار يضغطها المستخدم، يقرّر النموذج ماذا يُنفَّذ:
//       answer         — إجابة/حل مشكلة/شرح/كتابة.
//       web_search     — معلومة حديثة أو أسعار أو أخبار (بحث Google مؤسَّس).
//       find_photos    — صورة حقيقية لشيء موجود (أي موضوع، لا الخياطة فقط).
//       generate_image — رسم/تصميم/توليد صورة جديدة، أو تعديل صورة سابقة.
//  3) جلب الصور عام: أُزيل فلتر "ماكينات الخياطة فقط" الذي كان يرفض أي صورة
//     خارجها؛ النموذج يكتب كلمات بحث إنجليزية دقيقة للصورة المطلوبة.
//  4) تعديل الصورة السابقة: العميل يرسل آخر صورة مولَّدة (last_image)، ويقرّر
//     الموجِّه إن كان الطلب تعديلًا لها فتُمرَّر للنموذج مع الوصف.
// الدفع يبقى خادميًا (ai_assistant_begin): يُحسَم بعد التوجيه، فلا تُخصم كلفة
// الصورة إلا إن كان التنفيذ فعلًا توليد صورة. أي فشل يُعاد فيه الرصيد.
import { createClient } from 'npm:@supabase/supabase-js@2';

const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};
const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { ...cors, 'Content-Type': 'application/json' } });

const MAX_TEXT = 2000;
const MAX_IMAGES = 4;
const MAX_B64 = 6_000_000;
const MAX_HISTORY = 12;
const MAX_TURN = 1500;
const GEMINI_MODEL_ENV = Deno.env.get('AI_GEMINI_MODEL') ?? '';
const GEMINI_IMAGE_MODEL_ENV = Deno.env.get('AI_GEMINI_IMAGE_MODEL') ?? '';
const CHAT_MODEL = Deno.env.get('AI_CHAT_MODEL') ?? 'gpt-4o-mini';
const STT_MODEL = Deno.env.get('AI_STT_MODEL') ?? 'whisper-1';
const GEMINI_BASE = 'https://generativelanguage.googleapis.com/v1beta';
const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36';

const SYSTEM = `أنت مساعد ذكي عام داخل تطبيق "مشاريعنا" (مجتمع للخياطة والملابس وأصحاب المشاريع، فيه دردشة وسوق منتجين).
تجيب عن أي موضوع: حل المشكلات التقنية والحياتية، الشرح، الكتابة والصياغة، الحساب، البرمجة، الترجمة، النصائح، وأنت خبير أيضًا في ماكينات الخياطة وأعطالها والأقمشة والقص.
- افهم السياق من المحادثة السابقة: الإشارات مثل "هي" و"عدّلها" و"وكم سعرها" تعود لما سبق.
- أجب بلغة المستخدم ولهجته، بوضوح ودقة. في حل المشكلات: خطوات مرقّمة تبدأ بالسبب الأرجح.
- إن كانت هناك صور مرفقة فحلّلها بدقة واذكر ما تراه.
- لا تخترع معلومات. إن كان الطلب غامضًا فعلًا فاسأل سؤالًا توضيحيًا واحدًا.
- لا تطلب من المستخدم الضغط على أي زر؛ التطبيق ينفّذ البحث والصور تلقائيًا.`;

const WEB_SYSTEM = `أنت مساعد بحث داخل تطبيق "مشاريعنا". أجب بلغة المستخدم بإيجاز ودقة، مع الأسماء والأرقام والأسعار والتواريخ إن وُجدت. لا تخترع معلومات، وإن اختلفت المصادر فاذكر ذلك. لا تضع روابط داخل النص (تُعرض المصادر منفصلة). لا تطلب الضغط على أزرار.`;

const ROUTER = `أنت موجِّه نوايا لمساعد ذكي. اقرأ المحادثة السابقة والرسالة الأخيرة وقرّر الإجراء الواحد الأنسب:
- "answer": سؤال، شرح، حل مشكلة، كتابة، حساب، ترجمة، تحليل صورة مرفقة، دردشة عادية.
- "web_search": يحتاج معلومة حديثة أو متغيرة: أسعار، أخبار، نتائج، مواعيد، مواصفات منتج حالي، "ابحث عن".
- "find_photos": يريد رؤية صورة حقيقية لشيء موجود فعلًا (منتج، مكان، شخص عام، حيوان، موديل، شعار...): "أرني صورة"، "اعطني صورة"، "كيف يبدو".
- "generate_image": يريد صورة جديدة مرسومة/مصمّمة/مولّدة، أو تعديل صورة سابقة أو مرفقة: "ارسم"، "صمّم"، "ولّد"، "اعمل لي شعار"، "غيّر لونها"، "خلّيها".
املأ:
- search_query: صيغة بحث دقيقة مستقلة عن السياق (تحلّ الضمائر من المحادثة).
- photo_query: كلمات بحث إنجليزية قصيرة ودقيقة للصورة المطلوبة (مثلًا "Juki DDL-8700 industrial sewing machine").
- image_prompt: وصف إنجليزي مفصّل للصورة المطلوب توليدها، يدمج كل ما سبق من تفاصيل في المحادثة.
- edit_previous_image: true إن كان الطلب تعديلًا للصورة المولَّدة السابقة.
- edit_attached_image: true إن كان الطلب تعديلًا لصورة أرفقها المستخدم الآن.`;

function b64ToBytes(b64: string): Uint8Array<ArrayBuffer> {
  const bin = atob(b64);
  const out = new Uint8Array(new ArrayBuffer(bin.length));
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
function bytesToB64(bytes: Uint8Array): string {
  let bin = '';
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) bin += String.fromCharCode(...bytes.subarray(i, i + chunk));
  return btoa(bin);
}

type Img = { mime: string; b64: string };
type Photo = { b64: string; mime: string; title: string; page: string };
type Source = { title: string; url: string };
type Turn = { role: 'user' | 'assistant'; text: string };
type Action = 'answer' | 'web_search' | 'find_photos' | 'generate_image';
type Route = {
  action: Action;
  search_query: string;
  photo_query: string;
  image_prompt: string;
  edit_previous_image: boolean;
  edit_attached_image: boolean;
};
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

// ---------- اختيار نماذج Gemini (مخزّن ساعة) ----------
let cachedModels: { text: string[]; image: string[]; at: number } | null = null;
async function resolveGeminiModels(key: string, force = false): Promise<{ text: string[]; image: string[] }> {
  if (!force && cachedModels && Date.now() - cachedModels.at < 3_600_000) return cachedModels;
  const flash: { id: string; v: number }[] = [];
  const lite: { id: string; v: number }[] = [];
  const img: { id: string; v: number }[] = [];
  try {
    const r = await fetch(`${GEMINI_BASE}/models?pageSize=200`, { headers: { 'x-goog-api-key': key } });
    if (r.ok) {
      const list: any[] = (await r.json())?.models ?? [];
      for (const m of list) {
        const id = (m?.name ?? '').toString().replace(/^models\//, '');
        const ok = Array.isArray(m?.supportedGenerationMethods) && m.supportedGenerationMethods.includes('generateContent');
        if (!ok) continue;
        let mt = /^gemini-(\d+(?:\.\d+)?)-flash$/.exec(id);
        if (mt) { flash.push({ id, v: parseFloat(mt[1]) }); continue; }
        mt = /^gemini-(\d+(?:\.\d+)?)-flash-lite$/.exec(id);
        if (mt) { lite.push({ id, v: parseFloat(mt[1]) }); continue; }
        mt = /^gemini-(\d+(?:\.\d+)?)-flash-image(?:-preview)?$/.exec(id);
        if (mt) img.push({ id, v: parseFloat(mt[1]) });
      }
    } else {
      console.error('listModels failed', r.status);
    }
  } catch (e) { console.error('listModels error', e); }
  const byVer = (a: { v: number }, b: { v: number }) => b.v - a.v;
  flash.sort(byVer); lite.sort(byVer); img.sort(byVer);
  const text = [...new Set([...flash.map((m) => m.id), ...lite.map((m) => m.id), 'gemini-flash-latest'])].slice(0, 5);
  const image = [...new Set([...img.map((m) => m.id), 'gemini-2.5-flash-image'])].slice(0, 4);
  cachedModels = { text, image, at: Date.now() };
  return cachedModels;
}

async function callGemini(key: string, models: string[], payload: string, envPinned: boolean): Promise<any> {
  let lastErr = '';
  for (const model of models) {
    for (let attempt = 0; attempt < 2; attempt++) {
      let r: Response;
      try {
        r = await fetch(`${GEMINI_BASE}/models/${model}:generateContent`, {
          method: 'POST',
          headers: { 'x-goog-api-key': key, 'Content-Type': 'application/json' },
          body: payload,
        });
      } catch (e) { lastErr = `NET ${model} ${e}`; await sleep(600); continue; }
      if (r.ok) return await r.json();
      lastErr = `GEMINI_${r.status} [${model}] ${(await r.text()).slice(0, 200)}`;
      console.error(lastErr);
      if (r.status >= 500) { await sleep(700 * (attempt + 1)); continue; }
      break;
    }
  }
  if (!envPinned && lastErr.startsWith('GEMINI_404')) cachedModels = null;
  throw new Error(lastErr || 'GEMINI_FAILED');
}

const textModels = async (key: string) =>
  GEMINI_MODEL_ENV ? [GEMINI_MODEL_ENV] : (await resolveGeminiModels(key)).text;

// يحوّل سجل المحادثة إلى أدوار Gemini (user/model).
function historyContents(history: Turn[]): any[] {
  return history.map((t) => ({
    role: t.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: t.text }],
  }));
}

function historyText(history: Turn[]): string {
  return history.map((t) => `${t.role === 'assistant' ? 'المساعد' : 'المستخدم'}: ${t.text}`).join('\n');
}

const outText = (data: any) =>
  (data?.candidates?.[0]?.content?.parts?.map((p: any) => p?.text ?? '').join('') ?? '').trim();

// ---------- تفريغ الصوت ----------
async function transcribeGemini(key: string, audioB64: string, audioMime: string): Promise<string> {
  const payload = JSON.stringify({
    contents: [{
      role: 'user',
      parts: [
        { text: 'اكتب نص هذا التسجيل الصوتي حرفيًا كما قيل، بلا أي إضافة. أعد JSON فيه transcript.' },
        { inline_data: { mime_type: audioMime, data: audioB64 } },
      ],
    }],
    generationConfig: {
      temperature: 0,
      responseMimeType: 'application/json',
      responseSchema: { type: 'OBJECT', properties: { transcript: { type: 'STRING' } }, required: ['transcript'] },
    },
  });
  const data = await callGemini(key, await textModels(key), payload, !!GEMINI_MODEL_ENV);
  try { return (JSON.parse(outText(data))?.transcript ?? '').toString().trim(); } catch { return ''; }
}

// ---------- الموجِّه ----------
async function route(key: string, history: Turn[], text: string, hasAttached: boolean, hasPrevImage: boolean): Promise<Route> {
  const ctx =
    (history.length ? `المحادثة السابقة:\n${historyText(history)}\n\n` : '') +
    `الرسالة الأخيرة: ${text || '(بلا نص)'}\n` +
    `صور مرفقة الآن: ${hasAttached ? 'نعم' : 'لا'}\n` +
    `توجد صورة مولَّدة سابقة: ${hasPrevImage ? 'نعم' : 'لا'}`;
  const payload = JSON.stringify({
    systemInstruction: { parts: [{ text: ROUTER }] },
    contents: [{ role: 'user', parts: [{ text: ctx }] }],
    generationConfig: {
      temperature: 0,
      maxOutputTokens: 600,
      responseMimeType: 'application/json',
      responseSchema: {
        type: 'OBJECT',
        properties: {
          action: { type: 'STRING', enum: ['answer', 'web_search', 'find_photos', 'generate_image'] },
          search_query: { type: 'STRING' },
          photo_query: { type: 'STRING' },
          image_prompt: { type: 'STRING' },
          edit_previous_image: { type: 'BOOLEAN' },
          edit_attached_image: { type: 'BOOLEAN' },
        },
        required: ['action'],
      },
    },
  });
  const data = await callGemini(key, await textModels(key), payload, !!GEMINI_MODEL_ENV);
  let p: any = {};
  try { p = JSON.parse(outText(data)); } catch { p = {}; }
  const allowed: Action[] = ['answer', 'web_search', 'find_photos', 'generate_image'];
  const action: Action = allowed.includes(p?.action) ? p.action : 'answer';
  return {
    action,
    search_query: (p?.search_query ?? text).toString().trim() || text,
    photo_query: (p?.photo_query ?? '').toString().trim(),
    image_prompt: (p?.image_prompt ?? text).toString().trim() || text,
    edit_previous_image: p?.edit_previous_image === true && hasPrevImage,
    edit_attached_image: p?.edit_attached_image === true && hasAttached,
  };
}

// ---------- الإجابة بسياق كامل ----------
async function answerGemini(key: string, history: Turn[], text: string, images: Img[], system = SYSTEM): Promise<string> {
  const parts: any[] = [{ text: text || 'حلّل الصورة/اللقطات المرفقة وأخبرني ما تراه وما الحل.' }];
  for (const im of images) parts.push({ inline_data: { mime_type: im.mime, data: im.b64 } });
  const payload = JSON.stringify({
    systemInstruction: { parts: [{ text: system }] },
    contents: [...historyContents(history), { role: 'user', parts }],
    generationConfig: { temperature: 0.4, maxOutputTokens: 4096 },
  });
  return outText(await callGemini(key, await textModels(key), payload, !!GEMINI_MODEL_ENV));
}

// بحث Google المدمج في Gemini، مع سياق المحادثة.
async function webSearch(key: string, history: Turn[], query: string, images: Img[]) {
  const parts: any[] = [{ text: query }];
  for (const im of images) parts.push({ inline_data: { mime_type: im.mime, data: im.b64 } });
  const payload = JSON.stringify({
    systemInstruction: { parts: [{ text: WEB_SYSTEM }] },
    contents: [...historyContents(history), { role: 'user', parts }],
    tools: [{ google_search: {} }],
    generationConfig: { temperature: 0.2, maxOutputTokens: 4096 },
  });
  const data = await callGemini(key, await textModels(key), payload, !!GEMINI_MODEL_ENV);
  const cand = data?.candidates?.[0];
  const answer = (cand?.content?.parts?.map((p: any) => p?.text ?? '').join('') ?? '').trim();
  const seen = new Set<string>();
  const sources: Source[] = [];
  for (const c of cand?.groundingMetadata?.groundingChunks ?? []) {
    const u = c?.web?.uri?.toString();
    if (!u || seen.has(u)) continue;
    seen.add(u);
    sources.push({ title: (c?.web?.title ?? u).toString().slice(0, 120), url: u });
    if (sources.length >= 6) break;
  }
  return { answer, sources };
}

// ---------- بحث مجاني بلا مفتاح (احتياطي) ----------
type Hit = { title: string; url: string; snippet: string };
const stripTags = (s: string) =>
  s.replace(/<[^>]+>/g, '').replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#x27;|&#39;/g, "'")
    .replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/\s+/g, ' ').trim();

async function ddgText(q: string): Promise<Hit[]> {
  const r = await fetch('https://html.duckduckgo.com/html/', {
    method: 'POST',
    headers: { 'User-Agent': UA, 'Content-Type': 'application/x-www-form-urlencoded', 'Accept-Language': 'ar,en;q=0.8' },
    body: new URLSearchParams({ q }).toString(),
  });
  if (!r.ok) { console.error('ddg text failed', r.status); return []; }
  const html = await r.text();
  const out: Hit[] = [];
  const re = /<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>([\s\S]*?)(?=<a[^>]*class="result__a"|$)/g;
  let m: RegExpExecArray | null;
  while ((m = re.exec(html)) && out.length < 6) {
    let href = m[1];
    const ud = /[?&]uddg=([^&]+)/.exec(href);
    if (ud) href = decodeURIComponent(ud[1]);
    else if (href.startsWith('//')) href = 'https:' + href;
    if (!/^https?:\/\//.test(href) || /duckduckgo\.com\/y\.js/.test(href)) continue;
    const sn = /class="result__snippet"[^>]*>([\s\S]*?)<\/a>/.exec(m[3]);
    out.push({ title: stripTags(m[2]).slice(0, 120), url: href, snippet: sn ? stripTags(sn[1]).slice(0, 300) : '' });
  }
  return out;
}

async function wikiText(q: string): Promise<Hit[]> {
  const lang = /[؀-ۿ]/.test(q) ? 'ar' : 'en';
  const u = new URL(`https://${lang}.wikipedia.org/w/api.php`);
  u.searchParams.set('action', 'query'); u.searchParams.set('list', 'search'); u.searchParams.set('format', 'json');
  u.searchParams.set('srsearch', q); u.searchParams.set('srlimit', '3');
  const r = await fetch(u, { headers: { 'User-Agent': 'MashareenAssistant/2.0' } });
  if (!r.ok) return [];
  const list: any[] = (await r.json())?.query?.search ?? [];
  return list.map((x) => ({
    title: (x?.title ?? '').toString(),
    url: `https://${lang}.wikipedia.org/?curid=${x?.pageid}`,
    snippet: stripTags((x?.snippet ?? '').toString()),
  }));
}

async function freeSearch(q: string): Promise<Hit[]> {
  const [a, b] = await Promise.allSettled([ddgText(q), wikiText(q)]);
  return [...(a.status === 'fulfilled' ? a.value : []), ...(b.status === 'fulfilled' ? b.value : [])];
}

// ---------- جلب صور حقيقية لأي موضوع ----------
async function fetchThumb(src: string, title: string, page: string): Promise<Photo | null> {
  try {
    if (!/^https?:\/\//.test(src)) return null;
    const ir = await fetch(src, { headers: { 'User-Agent': UA } });
    if (!ir.ok) return null;
    const mime = (ir.headers.get('content-type') ?? 'image/jpeg').split(';')[0];
    if (!/^image\/(png|jpe?g|webp|gif)$/i.test(mime)) return null;
    const buf = new Uint8Array(await ir.arrayBuffer());
    if (buf.length < 2000 || buf.length > 1_500_000) return null;
    return { b64: bytesToB64(buf), mime, title: title.slice(0, 100), page };
  } catch { return null; }
}

async function ddgPhotos(q: string): Promise<Photo[]> {
  const h = { 'User-Agent': UA, 'Accept-Language': 'en-US,en;q=0.9' };
  const r1 = await fetch(`https://duckduckgo.com/?q=${encodeURIComponent(q)}&iax=images&ia=images`, { headers: h });
  if (!r1.ok) return [];
  const vqd = /vqd=["']?([\d-]+)/.exec(await r1.text())?.[1];
  if (!vqd) return [];
  // p=1: البحث الآمن مفعّل.
  const r2 = await fetch(
    `https://duckduckgo.com/i.js?l=wt-wt&o=json&q=${encodeURIComponent(q)}&vqd=${vqd}&f=,,,,,&p=1`,
    { headers: { ...h, Referer: 'https://duckduckgo.com/', Accept: 'application/json' } },
  );
  if (!r2.ok) return [];
  const res: any[] = (await r2.json())?.results ?? [];
  const got = await Promise.all(res.slice(0, 8).map((i) =>
    fetchThumb((i?.thumbnail ?? i?.image ?? '').toString(), (i?.title ?? '').toString(), (i?.url ?? '').toString())));
  return got.filter((x): x is Photo => !!x).slice(0, 4);
}

async function commonsPhotos(q: string): Promise<Photo[]> {
  const u = new URL('https://commons.wikimedia.org/w/api.php');
  u.searchParams.set('action', 'query'); u.searchParams.set('format', 'json');
  u.searchParams.set('generator', 'search'); u.searchParams.set('gsrsearch', `filetype:bitmap ${q}`);
  u.searchParams.set('gsrnamespace', '6'); u.searchParams.set('gsrlimit', '8');
  u.searchParams.set('prop', 'imageinfo'); u.searchParams.set('iiprop', 'url'); u.searchParams.set('iiurlwidth', '480');
  const r = await fetch(u, { headers: { 'User-Agent': 'MashareenAssistant/2.0' } });
  if (!r.ok) return [];
  const pages: any[] = Object.values((await r.json())?.query?.pages ?? {});
  const got = await Promise.all(pages.slice(0, 6).map((p) =>
    fetchThumb(p?.imageinfo?.[0]?.thumburl ?? '', (p?.title ?? '').toString().replace(/^File:/, ''), p?.imageinfo?.[0]?.descriptionurl ?? '')));
  return got.filter((x): x is Photo => !!x).slice(0, 4);
}

async function openversePhotos(q: string): Promise<Photo[]> {
  const u = new URL('https://api.openverse.org/v1/images/');
  u.searchParams.set('q', q); u.searchParams.set('page_size', '8'); u.searchParams.set('mature', 'false');
  const r = await fetch(u, { headers: { 'User-Agent': 'MashareenAssistant/2.0' } });
  if (!r.ok) return [];
  const res: any[] = (await r.json())?.results ?? [];
  const got = await Promise.all(res.slice(0, 6).map((i) =>
    fetchThumb((i?.thumbnail ?? i?.url ?? '').toString(), (i?.title ?? '').toString(), (i?.foreign_landing_url ?? '').toString())));
  return got.filter((x): x is Photo => !!x).slice(0, 4);
}

async function getPhotos(query: string): Promise<{ photos: Photo[]; source: string }> {
  for (const [name, fn] of [['ddg', ddgPhotos], ['commons', commonsPhotos], ['openverse', openversePhotos]] as const) {
    try {
      const photos = await fn(query);
      console.log('photos', name, photos.length, 'q=', query);
      if (photos.length > 0) return { photos, source: name };
    } catch (e) { console.error('photos error', name, String(e)); }
  }
  return { photos: [], source: '' };
}

// ---------- توليد/تعديل صورة ----------
async function generateImage(key: string, prompt: string, images: Img[]) {
  const parts: any[] = [{ text: prompt }];
  for (const im of images) parts.push({ inline_data: { mime_type: im.mime, data: im.b64 } });
  const payload = JSON.stringify({
    contents: [{ role: 'user', parts }],
    generationConfig: { responseModalities: ['IMAGE', 'TEXT'] },
  });
  const models = GEMINI_IMAGE_MODEL_ENV ? [GEMINI_IMAGE_MODEL_ENV] : (await resolveGeminiModels(key)).image;
  const data = await callGemini(key, models, payload, !!GEMINI_IMAGE_MODEL_ENV);
  const outParts: any[] = data?.candidates?.[0]?.content?.parts ?? [];
  let image: Img | null = null;
  let note = '';
  for (const p of outParts) {
    const inl = p?.inlineData ?? p?.inline_data;
    if (inl?.data && !image) image = { mime: (inl.mimeType ?? inl.mime_type ?? 'image/png').toString(), b64: inl.data.toString() };
    else if (p?.text) note += p.text.toString();
  }
  if (!image) throw new Error('NO_IMAGE ' + note.slice(0, 200));
  return { image, note: note.trim() };
}

// ---------- OpenAI (احتياطي حين لا يوجد مفتاح Gemini): إجابة بسياق ----------
async function askOpenAI(key: string, history: Turn[], text: string, audioB64: string, audioMime: string, images: Img[]) {
  let transcript = '';
  if (audioB64) {
    const ext = audioMime.includes('mp4') || audioMime.includes('m4a') ? 'm4a' : audioMime.includes('ogg') ? 'ogg' : audioMime.includes('wav') ? 'wav' : 'webm';
    const form = new FormData();
    form.append('file', new Blob([b64ToBytes(audioB64)], { type: audioMime }), `voice.${ext}`);
    form.append('model', STT_MODEL);
    const r = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST', headers: { Authorization: `Bearer ${key}` }, body: form,
    });
    if (!r.ok) throw new Error('STT_' + r.status);
    transcript = ((await r.json())?.text ?? '').toString().trim();
  }
  const question = [text, transcript].filter(Boolean).join('\n');
  if (!question && images.length === 0) return { transcript: '', answer: '' };
  const userContent: any[] = [{ type: 'text', text: question || 'حلّل الصورة المرفقة.' }];
  for (const im of images) userContent.push({ type: 'image_url', image_url: { url: `data:${im.mime};base64,${im.b64}` } });
  const r = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: CHAT_MODEL, max_tokens: 1200, temperature: 0.4,
      messages: [
        { role: 'system', content: SYSTEM },
        ...history.map((t) => ({ role: t.role, content: t.text })),
        { role: 'user', content: userContent },
      ],
    }),
  });
  if (!r.ok) throw new Error('CHAT_' + r.status);
  return { transcript, answer: ((await r.json())?.choices?.[0]?.message?.content ?? '').toString().trim() };
}

function parseHistory(raw: unknown): Turn[] {
  if (!Array.isArray(raw)) return [];
  const out: Turn[] = [];
  for (const t of raw.slice(-MAX_HISTORY)) {
    const role = t?.role === 'assistant' ? 'assistant' : t?.role === 'user' ? 'user' : null;
    const text = (t?.text ?? '').toString().trim().slice(0, MAX_TURN);
    if (role && text) out.push({ role, text });
  }
  // Gemini يشترط أن تبدأ المحادثة بدور المستخدم.
  while (out.length && out[0].role !== 'user') out.shift();
  return out;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: 'METHOD_NOT_ALLOWED' }, 405);

  const geminiKey = Deno.env.get('GEMINI_API_KEY');
  const openaiKey = Deno.env.get('OPENAI_API_KEY');
  if (!geminiKey && !openaiKey) return json({ error: 'AI_NOT_CONFIGURED' }, 503);

  const authHeader = req.headers.get('Authorization') ?? '';
  const url = Deno.env.get('SUPABASE_URL')!;
  const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
    global: { headers: { Authorization: authHeader } },
  });
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!);
  const { data: userData, error: userErr } = await userClient.auth.getUser();
  if (userErr || !userData?.user) return json({ error: 'AUTH_REQUIRED' }, 401);
  const uid = userData.user.id;

  let body: any;
  try { body = await req.json(); } catch { return json({ error: 'INVALID_JSON' }, 400); }

  const requestId: string = (body?.request_id ?? '').toString();
  if (!/^[0-9a-f-]{36}$/i.test(requestId)) return json({ error: 'REQUEST_ID_REQUIRED' }, 400);
  // الوضع الافتراضي "auto": الموجِّه يقرّر. الأوضاع القديمة تبقى مدعومة لتوافق
  // النسخ القديمة من التطبيق.
  const forced: Action | null =
    body?.mode === 'image' ? 'generate_image' : body?.mode === 'web' ? 'web_search' : body?.mode === 'text' ? 'answer' : null;
  let text = (body?.text ?? '').toString().trim().slice(0, MAX_TEXT);
  const audioB64: string = (body?.audio_base64 ?? '').toString();
  const audioMime: string = (body?.audio_mime ?? 'audio/webm').toString();
  const images: Img[] = Array.isArray(body?.images) ? body.images.slice(0, MAX_IMAGES) : [];
  const lastImage: Img | null =
    body?.last_image?.b64 && body?.last_image?.mime ? { b64: body.last_image.b64.toString(), mime: body.last_image.mime.toString() } : null;
  const history = parseHistory(body?.history);

  if (!text && !audioB64 && images.length === 0) return json({ error: 'EMPTY_REQUEST' }, 400);
  if (audioB64.length > MAX_B64) return json({ error: 'FILE_TOO_LARGE' }, 413);
  for (const im of [...images, ...(lastImage ? [lastImage] : [])]) {
    if (!im?.b64 || im.b64.length > MAX_B64 || !/^image\/(png|jpe?g|webp|gif)$/i.test(im.mime ?? '')) {
      return json({ error: 'INVALID_IMAGE' }, 400);
    }
  }

  // بلا مفتاح Gemini: لا توجيه ولا صور — إجابة بسياق عبر OpenAI.
  if (!geminiKey) {
    const { data: charge, error: chargeErr } = await userClient.rpc('ai_assistant_begin', { p_request_id: requestId, p_kind: 'text' });
    if (chargeErr) return chargeError(chargeErr.message ?? '');
    try {
      const o = await askOpenAI(openaiKey!, history, text, audioB64, audioMime, images);
      if (!o.answer) throw new Error('EMPTY_ANSWER');
      return json({ ok: true, kind: 'text', action: 'answer', transcript: o.transcript, answer: o.answer, mode: charge?.mode, cost: charge?.cost ?? 0 });
    } catch (e) {
      console.error('openai error', e);
      await refund(admin, uid, requestId);
      return json({ error: 'AI_FAILED' }, 502);
    }
  }

  // 1) التسجيل الصوتي يُفرَّغ أولًا ليصبح نصًّا يُفهَم ويُوجَّه.
  let transcript = '';
  if (audioB64) {
    try { transcript = await transcribeGemini(geminiKey, audioB64, audioMime); } catch (e) { console.error('stt', e); }
    if (!transcript && !text && images.length === 0) return json({ error: 'NO_SPEECH' }, 422);
    text = [text, transcript].filter(Boolean).join('\n');
  }

  // 2) التوجيه (بلا خصم: الخصم بعد معرفة نوع التنفيذ).
  let r: Route;
  try {
    r = forced
      ? { action: forced, search_query: text, photo_query: text, image_prompt: text, edit_previous_image: false, edit_attached_image: images.length > 0 }
      : await route(geminiKey, history, text, images.length > 0, !!lastImage);
  } catch (e) {
    console.error('route failed', String(e));
    r = { action: 'answer', search_query: text, photo_query: text, image_prompt: text, edit_previous_image: false, edit_attached_image: false };
  }
  console.log('route', JSON.stringify({ action: r.action, sq: r.search_query, pq: r.photo_query, ep: r.edit_previous_image }));

  // 3) الخصم بحسب التنفيذ الفعلي.
  const kind: 'text' | 'image' = r.action === 'generate_image' ? 'image' : 'text';
  const { data: charge, error: chargeErr } = await userClient.rpc('ai_assistant_begin', { p_request_id: requestId, p_kind: kind });
  if (chargeErr) return chargeError(chargeErr.message ?? '');
  const meta = { action: r.action, transcript, mode: charge?.mode, cost: charge?.cost ?? 0 };

  try {
    if (r.action === 'generate_image') {
      const refs: Img[] = [];
      if (r.edit_previous_image && lastImage) refs.push(lastImage);
      if (r.edit_attached_image) refs.push(...images);
      const g = await generateImage(geminiKey, r.image_prompt, refs);
      return json({ ok: true, kind: 'image', image: g.image, answer: g.note, ...meta });
    }

    if (r.action === 'find_photos') {
      const q = r.photo_query || r.search_query || text;
      const [ph, ans] = await Promise.allSettled([
        getPhotos(q),
        answerGemini(geminiKey, history, `${text}\n\n(تُعرض للمستخدم صور حقيقية من الإنترنت تحت إجابتك؛ اكتب وصفًا موجزًا مفيدًا لما طلبه في سطرين أو ثلاثة.)`, images),
      ]);
      const photos = ph.status === 'fulfilled' ? ph.value.photos : [];
      let answer = ans.status === 'fulfilled' ? ans.value : '';
      if (photos.length === 0) {
        answer = (answer ? answer + '\n\n' : '') + 'لم أجد صورة حقيقية مطابقة في المصادر المتاحة. إن أردت أرسم لك صورة توضيحية، فقط قل «ارسمها».';
      }
      if (!answer && photos.length === 0) throw new Error('EMPTY_ANSWER');
      return json({ ok: true, kind: 'web', answer, sources: [], photos, photos_configured: true, photos_wanted: true, ...meta });
    }

    if (r.action === 'web_search') {
      let answer = '';
      let sources: Source[] = [];
      try {
        const w = await webSearch(geminiKey, history, r.search_query, images);
        answer = w.answer; sources = w.sources;
      } catch (e) { console.error('grounded search failed', String(e)); }
      if (!answer) {
        const free = await freeSearch(r.search_query).catch(() => [] as Hit[]);
        if (free.length > 0) {
          const ctx = free.map((h, i) => `${i + 1}. ${h.title} — ${h.snippet} (${h.url})`).join('\n');
          answer = await answerGemini(geminiKey, history,
            `${text}\n\nنتائج بحث حديثة (اعتمد عليها وتجاهل غير المرتبط، ولا تخترع ما ليس فيها):\n${ctx}`, images, WEB_SYSTEM);
          sources = free.slice(0, 6).map((h) => ({ title: h.title, url: h.url }));
        } else {
          answer = await answerGemini(geminiKey, history, text, images);
          if (answer) answer += '\n\n⚠️ البحث المباشر غير متاح الآن، فهذه إجابة من معرفة النموذج دون مصادر.';
        }
      }
      if (!answer) throw new Error('EMPTY_ANSWER');
      return json({ ok: true, kind: 'web', answer, sources, photos: [], photos_configured: true, photos_wanted: false, ...meta });
    }

    const answer = await answerGemini(geminiKey, history, text, images);
    if (!answer) throw new Error('EMPTY_ANSWER');
    return json({ ok: true, kind: 'text', answer, ...meta });
  } catch (e) {
    console.error('ai-assistant error', e);
    await refund(admin, uid, requestId);
    const msg = String((e as Error)?.message ?? e);
    if (r.action === 'generate_image') {
      if (msg.startsWith('NO_IMAGE')) return json({ error: 'NO_IMAGE' }, 422);
      if (/^GEMINI_(429|403|404|400)/.test(msg)) return json({ error: 'IMAGE_UNAVAILABLE', detail: msg.slice(0, 160) }, 503);
    }
    if (r.action === 'web_search' && /^GEMINI_(429|403|400)/.test(msg)) return json({ error: 'WEB_UNAVAILABLE' }, 503);
    return json({ error: 'AI_FAILED' }, 502);
  }
});

function chargeError(m: string) {
  for (const code of ['INSUFFICIENT_POINTS', 'RATE_LIMITED', 'AI_DISABLED', 'AUTH_REQUIRED']) {
    if (m.includes(code)) return json({ error: code }, code === 'INSUFFICIENT_POINTS' ? 402 : code === 'RATE_LIMITED' ? 429 : 403);
  }
  console.error('begin failed', m);
  return json({ error: 'CHARGE_FAILED' }, 500);
}

async function refund(admin: any, uid: string, requestId: string) {
  try { await admin.rpc('ai_assistant_refund', { p_user_id: uid, p_request_id: requestId }); } catch (e) { console.error('refund failed', e); }
}
