import { createClient } from "npm:@supabase/supabase-js@2";
import { corsHeaders } from "npm:@supabase/supabase-js/cors";

const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";

const secretKeysRaw =
  Deno.env.get("SUPABASE_SECRET_KEYS") ?? "{}";

const secretKeys = JSON.parse(secretKeysRaw);
const secretKey = secretKeys["default"] ?? "";

if (!supabaseUrl || !secretKey) {
  throw new Error("Missing Supabase server environment variables");
}

const supabaseAdmin = createClient(
  supabaseUrl,
  secretKey,
  {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  },
);

function json(
  body: Record<string, unknown>,
  status = 200,
) {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function getClientIp(req: Request): string | null {
  const forwarded = req.headers.get("x-forwarded-for");

  if (forwarded) {
    const first = forwarded
      .split(",")[0]
      ?.trim();

    if (first) {
      return first;
    }
  }

  const realIp =
    req.headers.get("x-real-ip")?.trim();

  return realIp || null;
}

async function sha256(value: string): Promise<string> {
  const data =
    new TextEncoder().encode(value);

  const digest =
    await crypto.subtle.digest(
      "SHA-256",
      data,
    );

  return Array.from(new Uint8Array(digest))
    .map(
      (byte) =>
        byte.toString(16).padStart(2, "0"),
    )
    .join("");
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return json(
      {
        error: "METHOD_NOT_ALLOWED",
      },
      405,
    );
  }

  const authorization =
    req.headers.get("authorization") ?? "";

  if (!authorization.startsWith("Bearer ")) {
    return json(
      {
        error: "AUTH_REQUIRED",
      },
      401,
    );
  }

  const accessToken =
    authorization
      .substring("Bearer ".length)
      .trim();

  const supabaseUser = createClient(
    supabaseUrl,
    Deno.env.get("SUPABASE_ANON_KEY") ?? "",
    {
      global: {
        headers: {
          Authorization:
            `Bearer ${accessToken}`,
        },
      },
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    },
  );

  const {
    data: { user },
    error: userError,
  } =
    await supabaseUser.auth.getUser();

  if (userError || !user) {
    return json(
      {
        error: "INVALID_SESSION",
      },
      401,
    );
  }

  const ip = getClientIp(req);

  if (!ip) {
    return json({
      ok: true,
      ip_recorded: false,
    });
  }

  const ipHash =
    await sha256(ip);

  const {
    data: currentIdentity,
    error: identityError,
  } =
    await supabaseAdmin
      .from("user_security_identity")
      .select("risk_score")
      .eq("user_id", user.id)
      .maybeSingle();

  if (identityError) {
    return json(
      {
        error: "IDENTITY_LOOKUP_FAILED",
      },
      500,
    );
  }

  const riskScore = Math.max(
    0,
    Math.min(
      100,
      Number(
        currentIdentity?.risk_score ?? 0,
      ),
    ),
  );

  const { error: updateError } =
    await supabaseAdmin
      .from("user_security_identity")
      .upsert(
        {
          user_id: user.id,
          last_ip_hash: ipHash,
          last_seen_at:
            new Date().toISOString(),
          updated_at:
            new Date().toISOString(),
          risk_score: riskScore,
        },
        {
          onConflict: "user_id",
        },
      );

  if (updateError) {
    return json(
      {
        error: "IDENTITY_UPDATE_FAILED",
      },
      500,
    );
  }

  return json({
    ok: true,
    ip_recorded: true,
  });
});
