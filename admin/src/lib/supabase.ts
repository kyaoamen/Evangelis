import { createBrowserClient } from "@supabase/ssr";
import type { SupabaseClient } from "@supabase/supabase-js";

export const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL ?? "";
export const SUPABASE_ANON_KEY = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY ?? "";
export const isConfigured = SUPABASE_URL.length > 0 && SUPABASE_ANON_KEY.length > 0;

let client: SupabaseClient | null = null;

/** Browser Supabase client (session kept in cookies so the proxy can read it). */
export function supabase(): SupabaseClient {
  if (!isConfigured) throw new Error("Supabase is not configured");
  client ??= createBrowserClient(SUPABASE_URL, SUPABASE_ANON_KEY);
  return client;
}

/** Turns a Supabase/PostgREST error into a readable message. */
export function errorMessage(e: unknown): string {
  if (e && typeof e === "object" && "message" in e) return String((e as { message: unknown }).message);
  return String(e);
}

/** Throws when a Supabase call returned an error. */
export function check<T>(res: { data: T; error: unknown }): T {
  if (res.error) throw res.error;
  return res.data;
}

export const MEDIA_BUCKET = "church-media";
export const DOCS_BUCKET = "church-documents";

/** Uploads a file under <churchId>/<prefix>-<timestamp>.<ext> and returns its storage path. */
export async function uploadFile(bucket: string, churchId: string, prefix: string, file: File): Promise<string> {
  const ext = (file.name.split(".").pop() ?? "bin").toLowerCase().replace(/[^a-z0-9]/g, "");
  const safe = prefix.replace(/[^a-z0-9_-]/gi, "-").toLowerCase();
  const path = `${churchId}/${safe}-${Date.now()}.${ext}`;
  const { error } = await supabase().storage.from(bucket).upload(path, file, {
    contentType: file.type || undefined,
    cacheControl: "3600",
  });
  if (error) throw error;
  return path;
}

export function publicUrl(path: string): string {
  return supabase().storage.from(MEDIA_BUCKET).getPublicUrl(path).data.publicUrl;
}
