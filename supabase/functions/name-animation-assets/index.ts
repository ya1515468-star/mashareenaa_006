import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const BUCKET = "name-animations";
const MAX_BYTES = 8 * 1024 * 1024;
const MAX_DIMENSION = 2048;
const MAX_FRAMES = 240;
const MAX_DECODED_BYTES = 128 * 1024 * 1024;
const MAX_WIDTH = 44;
const MAX_HEIGHT = 30;
const headers = {
  "content-type": "application/json",
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, apikey, x-client-info, content-type, x-request-id, x-name-animation-filename, x-name-animation-key, x-name-animation-name-ar, x-name-animation-category, x-name-animation-owner-free, x-name-animation-price-points, x-name-animation-price-gems",
  "access-control-allow-methods": "POST, OPTIONS",
};

function json(body: Record<string, unknown>, status = 200) { return new Response(JSON.stringify(body), { status, headers }); }
function headerInt(req: Request, name: string, fallback: number) { const n = Number.parseInt(req.headers.get(name) ?? "", 10); return Number.isFinite(n) ? n : fallback; }
function safeText(raw: string | null, fallback = "") { return (raw ?? fallback).trim().slice(0, 160); }
function decodeB64Url(raw: string | null, fallback: string) {
  if (!raw) return fallback;
  try {
    const padded = raw.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((raw.length + 3) % 4);
    return new TextDecoder().decode(Uint8Array.from(atob(padded), c => c.charCodeAt(0)));
  } catch { return fallback; }
}
function u16(b: Uint8Array, o: number) { return b[o] | (b[o + 1] << 8); }
function skipSubBlocks(b: Uint8Array, offset: number) {
  let o = offset;
  while (true) {
    if (o >= b.length) throw new Error("GIF_TRUNCATED");
    const n = b[o++];
    if (n === 0) return o;
    if (o + n > b.length) throw new Error("GIF_TRUNCATED");
    o += n;
  }
}
function inspectGif(b: Uint8Array) {
  if (b.length < 13) throw new Error("INVALID_GIF");
  const signature = new TextDecoder().decode(b.slice(0, 6));
  if (signature !== "GIF87a" && signature !== "GIF89a") throw new Error("INVALID_GIF");
  const width = u16(b, 6), height = u16(b, 8);
  if (width < 1 || height < 1 || width > MAX_DIMENSION || height > MAX_DIMENSION) throw new Error("INVALID_GIF_DIMENSIONS");
  if ((width * height * 4) > MAX_DECODED_BYTES) throw new Error("GIF_DECODED_TOO_LARGE");
  const packed = b[10];
  let o = 13;
  if ((packed & 0x80) !== 0) { const entries = 1 << ((packed & 0x07) + 1); const n = entries * 3; if (o + n > b.length) throw new Error("GIF_TRUNCATED"); o += n; }
  let frames = 0;
  let duration = 0;
  let pendingDelay = 100;
  let transparent = false;
  let trailer = false;
  while (o < b.length) {
    const block = b[o++];
    if (block === 0x3b) { trailer = true; break; }
    if (block === 0x21) {
      if (o >= b.length) throw new Error("GIF_TRUNCATED");
      const label = b[o++];
      if (label === 0xf9) {
        if (o + 6 > b.length || b[o++] !== 4) throw new Error("GIF_TRUNCATED");
        const gcePacked = b[o++];
        const delayCs = u16(b, o); o += 2; o += 1;
        pendingDelay = delayCs <= 0 ? 100 : delayCs * 10;
        transparent = transparent || (gcePacked & 0x01) !== 0;
        if (b[o++] !== 0) throw new Error("GIF_TRUNCATED");
      } else if (label === 0x01) {
        if (o >= b.length || b[o++] !== 12) throw new Error("GIF_TRUNCATED");
        if (o + 12 > b.length) throw new Error("GIF_TRUNCATED");
        o += 12; o = skipSubBlocks(b, o);
      } else if (label === 0xff) {
        if (o >= b.length || b[o++] !== 11) throw new Error("GIF_TRUNCATED");
        if (o + 11 > b.length) throw new Error("GIF_TRUNCATED");
        o += 11; o = skipSubBlocks(b, o);
      } else {
        o = skipSubBlocks(b, o);
      }
      continue;
    }
    if (block !== 0x2c) throw new Error("INVALID_GIF");
    if (o + 9 > b.length) throw new Error("GIF_TRUNCATED");
    const frameWidth = u16(b, o + 4), frameHeight = u16(b, o + 6), framePacked = b[o + 8];
    if (frameWidth < 1 || frameHeight < 1 || frameWidth > MAX_DIMENSION || frameHeight > MAX_DIMENSION) throw new Error("INVALID_GIF_DIMENSIONS");
    o += 9;
    if ((framePacked & 0x80) !== 0) { const entries = 1 << ((framePacked & 0x07) + 1); const n = entries * 3; if (o + n > b.length) throw new Error("GIF_TRUNCATED"); o += n; }
    if (o >= b.length) throw new Error("GIF_TRUNCATED");
    const lzw = b[o++];
    if (lzw < 2 || lzw > 8) throw new Error("INVALID_GIF");
    o = skipSubBlocks(b, o);
    frames++;
    if (frames > MAX_FRAMES) throw new Error("GIF_TOO_MANY_FRAMES");
    duration += Math.min(5000, Math.max(10, pendingDelay));
    pendingDelay = 100;
    if ((width * height * frames * 4) > MAX_DECODED_BYTES) throw new Error("GIF_DECODED_TOO_LARGE");
  }
  if (!trailer || frames < 1) throw new Error("INVALID_GIF");
  return { width, height, frames, duration, transparent };
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers });
  if (req.method !== "POST") return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);
  // Every code path below is wrapped so an unexpected exception (a network
  // hiccup, an unforeseen edge case) always still comes back as a clean JSON
  // response with proper CORS headers, instead of an uncaught crash — that
  // exact gap is what silently broke CORS for every OPTIONS request earlier.
  try {
    return await handlePost(req);
  } catch (e) {
    console.error("NAME_ANIMATION_UNHANDLED", e instanceof Error ? (e.stack ?? e.message) : String(e));
    return json({ ok: false, error: "SERVER_ERROR", detail: e instanceof Error ? e.message : String(e) }, 500);
  }
});

async function handlePost(req: Request): Promise<Response> {
  const url = Deno.env.get("SUPABASE_URL");
  const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !serviceKey) return json({ ok: false, error: "SERVER_CONFIGURATION_ERROR" }, 500);
  const authHeader = req.headers.get("Authorization") ?? "";
  if (!authHeader.startsWith("Bearer ")) return json({ ok: false, error: "AUTH_REQUIRED" }, 401);
  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
  const token = authHeader.slice(7).trim();
  const { data: authData, error: authError } = await admin.auth.getUser(token);
  if (authError || !authData.user) return json({ ok: false, error: "INVALID_SESSION" }, 401);
  const { data: owner, error: ownerError } = await admin.rpc("is_platform_owner", { p_user_id: authData.user.id });
  if (ownerError) return json({ ok: false, error: "OWNER_CHECK_FAILED", detail: ownerError.message }, 500);
  if (owner !== true) return json({ ok: false, error: "OWNER_REQUIRED" }, 403);

  const requestId = req.headers.get("x-request-id")?.trim();
  if (!requestId) return json({ ok: false, error: "REQUEST_ID_REQUIRED" }, 400);
  const existing = await admin.from("idempotency_requests").select("response,user_id,operation").eq("request_id", requestId).maybeSingle();
  if (existing.data) {
    if (existing.data.user_id !== authData.user.id || existing.data.operation !== "name_animation_asset") return json({ ok: false, error: "REQUEST_ID_REPLAY_FORBIDDEN" }, 409);
    return json({ ...(existing.data.response as Record<string, unknown>), replayed: true }, 200);
  }

  const contentType = (req.headers.get("content-type") ?? "").split(";", 1)[0].toLowerCase();
  if (contentType !== "image/gif" && contentType !== "application/octet-stream") return json({ ok: false, error: "GIF_REQUIRED" }, 400);
  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.length === 0) return json({ ok: false, error: "ANIMATION_EMPTY" }, 400);
  if (bytes.length > MAX_BYTES) return json({ ok: false, error: "ANIMATION_TOO_LARGE" }, 413);

  let info;
  try { info = inspectGif(bytes); } catch (e) { return json({ ok: false, error: String(e instanceof Error ? e.message : e) }, 400); }

  const keyHeader = safeText(req.headers.get("x-name-animation-key"));
  const existingKey = keyHeader && keyHeader !== "auto" ? keyHeader.toLowerCase() : "";
  if (existingKey && !/^[a-z0-9_]+$/.test(existingKey)) return json({ ok: false, error: "INVALID_EFFECT_KEY" }, 400);
  const filename = decodeB64Url(req.headers.get("x-name-animation-filename"), "animal.gif");
  const requestedName = decodeB64Url(req.headers.get("x-name-animation-name-ar"), "");
  const stem = filename.replace(/\.gif$/i, "").toLowerCase().replace(/[^a-z0-9_]+/g, "_").replace(/^_+|_+$/g, "").slice(0, 48) || "animal";
  const key = existingKey || `${stem}_animal_${crypto.randomUUID().slice(0, 8)}`;
  const nameAr = requestedName || filename.replace(/\.gif$/i, "").trim() || "حيوان";
  const durationMs = Math.min(2400, Math.max(1200, info.duration));
  const fps = Math.min(30, Math.max(1, Math.round(info.frames / (durationMs / 1000))));
  const pricePoints = Math.max(0, headerInt(req, "x-name-animation-price-points", 5000));
  const priceGems = Math.max(0, headerInt(req, "x-name-animation-price-gems", 50));
  const ownerFree = (req.headers.get("x-name-animation-owner-free") ?? "false").toLowerCase() === "true";

  const bucket = admin.storage.from(BUCKET);
  const oldRow = existingKey ? await admin.from("name_animation_catalog").select("effect_key,name_ar,storage_path,is_active,price_points,price_gems,owner_free").eq("effect_key", key).maybeSingle() : { data: null };
  if (existingKey && oldRow.data == null) return json({ ok: false, error: "ANIMATION_NOT_FOUND" }, 404);
  const version = crypto.randomUUID().replace(/-/g, "").slice(0, 16);
  const storagePath = existingKey ? `catalog/${key}/${version}.gif` : `catalog/${key}.gif`;
  const upload = await bucket.upload(storagePath, bytes, { contentType: "image/gif", cacheControl: "3600", upsert: false });
  if (upload.error) return json({ ok: false, error: "STORAGE_UPLOAD_FAILED", detail: upload.error.message }, 500);

  const publicUrl = bucket.getPublicUrl(storagePath).data.publicUrl;
  const payload = {
    effect_key: key,
    name_ar: nameAr.slice(0, 160),
    category: safeText(req.headers.get("x-name-animation-category"), "animal") || "animal",
    asset_url: publicUrl,
    storage_path: storagePath,
    size_bytes: bytes.length,
    animation_type: "gif",
    fps,
    duration_ms: durationMs,
    max_width: MAX_WIDTH,
    max_height: MAX_HEIGHT,
    transparent: true,
    loop: true,
    price_points: pricePoints,
    price_gems: priceGems,
    owner_free: ownerFree,
    is_active: existingKey ? (oldRow.data?.is_active ?? true) : true,
    metadata: { placement: "above_name", anchor: "bottom_center", source_width: info.width, source_height: info.height, frame_count: info.frames, render_effect: "float_glow", source_format: "gif", transparent_detected: info.transparent, decoded_memory_limit: MAX_DECODED_BYTES },
    source_width: info.width,
    source_height: info.height,
    frame_count: info.frames,
    render_effect: "float_glow",
  };

  const result = existingKey
    ? await admin.from("name_animation_catalog").update(payload).eq("effect_key", key).select("effect_key,name_ar,storage_path,asset_url,max_width,max_height").single()
    : await admin.from("name_animation_catalog").insert(payload).select("effect_key,name_ar,storage_path,asset_url,max_width,max_height").single();
  if (result.error || !result.data) {
    await bucket.remove([storagePath]).catch(() => undefined);
    return json({ ok: false, error: "DATABASE_WRITE_FAILED", detail: result.error?.message ?? "missing row" }, 500);
  }

  const response = { ok: true, effect_key: result.data.effect_key, name_ar: result.data.name_ar, storage_path: result.data.storage_path, asset_url: result.data.asset_url, max_width: MAX_WIDTH, max_height: MAX_HEIGHT };
  const idem = await admin.from("idempotency_requests").insert({ request_id: requestId, user_id: authData.user.id, operation: "name_animation_asset", response });
  if (idem.error) console.error("NAME_ANIMATION_IDEMPOTENCY_WRITE_FAILED", requestId, idem.error.message);

  const auditAction = existingKey ? "ANIMAL_GIF_REPLACED" : "ANIMAL_CREATED";
  const audit = await admin.from("audit_logs").insert({
    actor_user_id: authData.user.id,
    actor_id: authData.user.id,
    action: auditAction,
    resource_type: "name_animation_catalog",
    resource_id: key,
    target_id: key,
    request_id: requestId,
    result: "success",
    metadata: {
      old_storage_path: oldRow.data?.storage_path ?? null,
      new_storage_path: storagePath,
      name_ar: nameAr.slice(0, 160),
      source_width: info.width,
      source_height: info.height,
      frame_count: info.frames,
      size_bytes: bytes.length,
    },
  });
  if (audit.error) console.error("NAME_ANIMATION_AUDIT_WRITE_FAILED", requestId, audit.error.message);

  if (existingKey && oldRow.data?.storage_path && oldRow.data.storage_path !== storagePath) {
    const cleanup = await bucket.remove([oldRow.data.storage_path]);
    if (cleanup.error) console.warn("NAME_ANIMATION_OLD_ASSET_CLEANUP_FAILED", key, cleanup.error.message);
  }
  return json(response, 200);
}
