import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const admin = createClient(supabaseUrl, serviceKey);
const AVATAR_FRAMES_BUCKET = "avatar-frames";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Max-Age": "86400",
};

const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, "content-type": "application/json" },
});

const errorFields = (error: unknown) => {
  const err = error as Record<string, unknown> | null;
  const message =
    typeof err?.message === "string" && err.message.trim()
      ? err.message
      : error instanceof Error && error.message
        ? error.message
        : String(error ?? "INTERNAL_FUNCTION_ERROR");
  return {
    message,
    code: typeof err?.code === "string" ? err.code : null,
    details: typeof err?.details === "string" ? err.details : err?.details ?? null,
    hint: typeof err?.hint === "string" ? err.hint : err?.hint ?? null,
  };
};

const isStorageNotFound = (error: unknown) => {
  const fields = errorFields(error);
  const text = `${fields.message} ${fields.details ?? ""}`.toLowerCase();
  return text.includes("not found") || text.includes("object not found") || text.includes("no such object");
};

Deno.serve(async (req) => {
  try {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
    if (req.method !== "POST") return json({ ok: false, error: "METHOD_NOT_ALLOWED" }, 405);

    // verify_jwt=true is enabled for this function. Extract the actual user JWT
    // explicitly and bind all privileged work to that authenticated identity.
    const authorization = req.headers.get("authorization")?.trim() ?? "";
    const bearerMatch = authorization.match(/^Bearer\s+(.+)$/i);
    if (!bearerMatch?.[1]) return json({ ok: false, error: "AUTH_REQUIRED" }, 401);
    const token = bearerMatch[1].trim();

    const { data: authData, error: authError } = await admin.auth.getUser(token);
    if (authError || !authData.user) {
      const fields = errorFields(authError ?? new Error("AUTH_INVALID"));
      console.error("avatar-frame-delete-v2 authentication failed", fields);
      return json({
        ok: false,
        error: "AUTH_INVALID",
        message: fields.message,
        code: fields.code,
        details: fields.details,
        hint: fields.hint,
      }, 401);
    }
    const userId = authData.user.id;

    const { data: owner, error: ownerError } = await admin
      .from("platform_owners")
      .select("user_id")
      .eq("user_id", userId)
      .maybeSingle();
    if (ownerError) throw ownerError;
    if (!owner) return json({ ok: false, error: "FORBIDDEN" }, 403);

    const body = await req.json().catch(() => ({}));
    const frameKey = String(body?.frame_key ?? "").trim().toLowerCase();
    if (!frameKey) return json({ ok: false, error: "FRAME_KEY_REQUIRED" }, 400);

    const { data: frame, error: frameError } = await admin
      .from("avatar_frame_catalog")
      .select("frame_key, storage_path")
      .eq("frame_key", frameKey)
      .maybeSingle();
    if (frameError) throw frameError;
    if (!frame) return json({ ok: false, error: "FRAME_NOT_FOUND" }, 404);

    const storagePath = String(frame.storage_path ?? "").trim();
    if (!storagePath) return json({ ok: false, error: "STORAGE_PATH_MISSING" }, 500);

    // Delete the object first. Missing objects are treated as already deleted so a
    // previous interrupted request can safely be retried.
    const { error: storageError } = await admin.storage.from(AVATAR_FRAMES_BUCKET).remove([storagePath]);
    if (storageError && !isStorageNotFound(storageError)) {
      return json({
        ok: false,
        error: "STORAGE_DELETE_FAILED",
        details: storageError.message,
        frame_key: frameKey,
        storage_bucket: AVATAR_FRAMES_BUCKET,
        storage_path: storagePath,
      }, 500);
    }

    // Preserve the caller JWT for the SECURITY DEFINER RPC because the RPC uses auth.uid().
    const ownerClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: result, error: rpcError } = await ownerClient.rpc(
      "admin_delete_avatar_frame",
      { p_frame_key: frameKey },
    );
    if (rpcError) {
      const fields = errorFields(rpcError);
      return json({
        ok: false,
        error: fields.message,
        details: fields.details,
        hint: fields.hint,
        code: fields.code,
        frame_key: frameKey,
        storage_bucket: AVATAR_FRAMES_BUCKET,
        storage_path: storagePath,
      }, 400);
    }

    return json({
      ok: true,
      frame_key: frameKey,
      storage_bucket: AVATAR_FRAMES_BUCKET,
      storage_path: storagePath,
      cleared_profiles: result?.cleared_profiles ?? 0,
      storage_already_missing: Boolean(storageError && isStorageNotFound(storageError)),
      rpc_result: result ?? null,
    });
  } catch (error) {
    const err = error as Record<string, unknown> | null;
    const message =
      typeof err?.message === "string" && err.message.trim()
        ? err.message
        : error instanceof Error
          ? error.message
          : "INTERNAL_FUNCTION_ERROR";
    console.error("avatar-frame-delete-v2 error", {
      message,
      code: typeof err?.code === "string" ? err.code : null,
      details: err?.details ?? null,
      hint: err?.hint ?? null,
    });
    return json({
      ok: false,
      error: message,
      code: typeof err?.code === "string" ? err.code : null,
      details: err?.details ?? null,
      hint: err?.hint ?? null,
    }, 500);
  }
});
