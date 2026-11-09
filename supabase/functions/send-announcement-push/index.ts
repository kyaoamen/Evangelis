// Sends a push notification for a published announcement to the church's devices.
// Called by the back-office right after an announcement is created.
//
// Secrets (supabase secrets set ...):
//   FCM_SERVICE_ACCOUNT  JSON of a Firebase service account with the FCM role
// Provided by Supabase: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_ROLE_KEY
import { createClient } from "jsr:@supabase/supabase-js@2";

type I18n = { fr?: string; en?: string };
const pick = (t: I18n, locale: string, fallback: string) =>
  (locale === "en" ? t.en : t.fr) ?? (fallback === "en" ? t.en : t.fr) ?? t.fr ?? t.en ?? "";

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
  const { announcement_id } = await req.json().catch(() => ({}));
  if (!announcement_id) return json({ error: "announcement_id required" }, 400);

  // 1. Check the caller is staff of the announcement's church (RLS does it for us).
  const userClient = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_ANON_KEY")!, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: ann, error } = await userClient
    .from("announcements").select("id, church_id, title, body, audience, push_sent_at, publish_at")
    .eq("id", announcement_id).single();
  if (error || !ann) return json({ error: "not found" }, 404);
  const { data: isStaff } = await userClient.rpc("is_staff", { p_church: ann.church_id });
  if (!isStaff) return json({ error: "forbidden" }, 403);
  if (ann.push_sent_at) return json({ sent: 0, reason: "already sent" });
  if (new Date(ann.publish_at) > new Date()) return json({ sent: 0, reason: "scheduled" });

  // 2. Find recipients with the service role.
  const admin = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
  const { data: church } = await admin.from("churches").select("name, default_locale").eq("id", ann.church_id).single();
  const { data: members } = await admin.from("memberships").select("user_id")
    .eq("church_id", ann.church_id).eq("status", "active");
  const userIds = (members ?? []).map((m) => m.user_id);
  const { data: devices } = userIds.length
    ? await admin.from("device_tokens").select("token, locale").in("user_id", userIds)
    : { data: [] as { token: string; locale: string }[] };

  // 3. Send through FCM HTTP v1.
  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "{}");
  const accessToken = await googleAccessToken(sa);
  let sent = 0;
  const stale: string[] = [];
  for (const d of devices ?? []) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        message: {
          token: d.token,
          notification: {
            title: `${church?.name ?? ""} · ${pick(ann.title, d.locale, church?.default_locale ?? "fr")}`,
            body: pick(ann.body, d.locale, church?.default_locale ?? "fr").slice(0, 180),
          },
          data: { type: "announcement", church_id: ann.church_id, announcement_id: ann.id },
        },
      }),
    });
    if (res.ok) sent++;
    else if (res.status === 404 || res.status === 400) stale.push(d.token);
  }
  if (stale.length) await admin.from("device_tokens").delete().in("token", stale);
  await admin.from("announcements").update({ push_sent_at: new Date().toISOString() }).eq("id", ann.id);
  return json({ sent, removed: stale.length });
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

// OAuth2 access token from a service account (JWT bearer flow).
async function googleAccessToken(sa: { client_email: string; private_key: string }) {
  const now = Math.floor(Date.now() / 1000);
  const enc = (o: unknown) => b64url(new TextEncoder().encode(JSON.stringify(o)));
  const unsigned = `${enc({ alg: "RS256", typ: "JWT" })}.${enc({
    iss: sa.client_email, scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token", iat: now, exp: now + 3600,
  })}`;
  const pem = sa.private_key.replace(/-----[^-]+-----|\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8", Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" }, false, ["sign"],
  );
  const sig = new Uint8Array(await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned)));
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion: `${unsigned}.${b64url(sig)}` }),
  });
  return (await res.json()).access_token as string;
}
function b64url(bytes: Uint8Array) {
  return btoa(String.fromCharCode(...bytes)).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
