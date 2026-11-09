"use client";

import { useEffect, useState } from "react";
import {
  Button,
  Card,
  Feedback,
  Field,
  I18nField,
  ImageInput,
  Input,
  PageHeader,
  Select,
  Spinner,
  cleanI18n,
  useAction,
} from "@/components/ui";
import { useChurch, useCurrentChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { MEDIA_BUCKET, publicUrl, supabase, uploadFile } from "@/lib/supabase";
import type { Branding, Church } from "@/lib/types";

const SOCIALS = ["youtube", "facebook", "instagram", "tiktok", "whatsapp"] as const;

export default function BrandingPage() {
  const { t, tr } = useI18n();
  const church = useCurrentChurch();
  const { reload } = useChurch();
  const [b, setB] = useState<Branding | null>(null);
  const [settings, setSettings] = useState<Pick<Church, "join_mode" | "default_locale" | "name" | "city" | "country">>({
    join_mode: church.join_mode,
    default_locale: church.default_locale,
    name: church.name,
    city: church.city,
    country: church.country,
  });
  const [uploading, setUploading] = useState(false);
  const { busy, error, notice, run, setError } = useAction();

  useEffect(() => {
    void supabase()
      .from("church_branding")
      .select("*")
      .eq("church_id", church.id)
      .single()
      .then(({ data }) => setB(data as Branding));
  }, [church.id]);

  if (!b) return <Spinner />;
  const set = <K extends keyof Branding>(k: K, v: Branding[K]) => setB({ ...b, [k]: v });

  async function uploadImage(kind: "logo" | "cover", file: File) {
    setUploading(true);
    try {
      const path = await uploadFile(MEDIA_BUCKET, church.id, kind, file);
      set(kind === "logo" ? "logo_url" : "cover_url", publicUrl(path));
    } catch (e) {
      setError(e && typeof e === "object" && "message" in e ? String(e.message) : String(e));
    } finally {
      setUploading(false);
    }
  }

  const save = () =>
    run(async () => {
      const db = supabase();
      const nullIfEmpty = (s: string | null) => (s && s.trim() ? s.trim() : null);
      const socials = Object.fromEntries(Object.entries(b.socials ?? {}).filter(([, v]) => v && v.trim()));
      const r1 = await db
        .from("church_branding")
        .update({
          logo_url: b.logo_url,
          cover_url: b.cover_url,
          primary_color: b.primary_color,
          accent_color: b.accent_color,
          tagline: cleanI18n(b.tagline),
          welcome_text: cleanI18n(b.welcome_text),
          about_text: cleanI18n(b.about_text),
          featured_video_url: nullIfEmpty(b.featured_video_url),
          address: nullIfEmpty(b.address),
          phone: nullIfEmpty(b.phone),
          email: nullIfEmpty(b.email),
          website: nullIfEmpty(b.website),
          socials,
        })
        .eq("church_id", church.id);
      if (r1.error) throw r1.error;
      const r2 = await db
        .from("churches")
        .update({
          name: settings.name.trim(),
          city: nullIfEmpty(settings.city),
          country: nullIfEmpty(settings.country)?.toUpperCase() ?? null,
          join_mode: settings.join_mode,
          default_locale: settings.default_locale,
        })
        .eq("id", church.id);
      if (r2.error) throw r2.error;
      await reload();
    }, t("saved"));

  return (
    <div>
      <PageHeader
        title={t("brandingTitle")}
        actions={
          <Button onClick={() => void save()} disabled={busy || uploading}>
            {t("save")}
          </Button>
        }
      />
      <div className="grid gap-6 lg:grid-cols-[1fr_320px]">
        <div className="space-y-6">
          <Card className="space-y-4">
            <h2 className="font-semibold">{t("identity")}</h2>
            <Field label={t("churchName")}>
              <Input value={settings.name} onChange={(e) => setSettings({ ...settings, name: e.target.value })} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label={t("city")}>
                <Input value={settings.city ?? ""} onChange={(e) => setSettings({ ...settings, city: e.target.value })} />
              </Field>
              <Field label={t("country")}>
                <Input
                  maxLength={2}
                  value={settings.country ?? ""}
                  onChange={(e) => setSettings({ ...settings, country: e.target.value.toUpperCase() })}
                />
              </Field>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              <ImageInput label={t("logo")} url={b.logo_url} busy={uploading} onFile={(f) => void uploadImage("logo", f)} />
              <ImageInput label={t("cover")} url={b.cover_url} busy={uploading} onFile={(f) => void uploadImage("cover", f)} />
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {(["primary_color", "accent_color"] as const).map((k) => (
                <Field key={k} label={t(k === "primary_color" ? "primaryColor" : "accentColor")}>
                  <div className="flex gap-2">
                    <input
                      type="color"
                      aria-label={t(k === "primary_color" ? "primaryColor" : "accentColor")}
                      className="h-10 w-12 cursor-pointer rounded border border-border bg-surface"
                      value={b[k]}
                      onChange={(e) => set(k, e.target.value.toUpperCase())}
                    />
                    <Input pattern="#[0-9A-Fa-f]{6}" value={b[k]} onChange={(e) => set(k, e.target.value)} />
                  </div>
                </Field>
              ))}
            </div>
          </Card>

          <Card className="space-y-4">
            <h2 className="font-semibold">{t("texts")}</h2>
            <I18nField label={t("churchTagline")} value={b.tagline} onChange={(v) => set("tagline", v)} />
            <I18nField label={t("welcomeText")} value={b.welcome_text} onChange={(v) => set("welcome_text", v)} multiline />
            <I18nField label={t("aboutText")} value={b.about_text} onChange={(v) => set("about_text", v)} multiline />
            <Field label={t("featuredVideo")}>
              <Input type="url" value={b.featured_video_url ?? ""} onChange={(e) => set("featured_video_url", e.target.value)} />
            </Field>
          </Card>

          <Card className="space-y-4">
            <h2 className="font-semibold">{t("contact")}</h2>
            <Field label={t("address")}>
              <Input value={b.address ?? ""} onChange={(e) => set("address", e.target.value)} />
            </Field>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label={t("phone")}>
                <Input type="tel" value={b.phone ?? ""} onChange={(e) => set("phone", e.target.value)} />
              </Field>
              <Field label={t("email")}>
                <Input type="email" value={b.email ?? ""} onChange={(e) => set("email", e.target.value)} />
              </Field>
            </div>
            <Field label={t("website")}>
              <Input type="url" value={b.website ?? ""} onChange={(e) => set("website", e.target.value)} />
            </Field>
            <fieldset>
              <legend className="mb-2 text-sm font-medium">{t("socials")}</legend>
              <div className="grid gap-3 sm:grid-cols-2">
                {SOCIALS.map((s) => (
                  <Field key={s} label={s[0].toUpperCase() + s.slice(1)}>
                    <Input
                      type="url"
                      placeholder="https://"
                      value={b.socials?.[s] ?? ""}
                      onChange={(e) => set("socials", { ...b.socials, [s]: e.target.value })}
                    />
                  </Field>
                ))}
              </div>
            </fieldset>
          </Card>

          <Card className="space-y-4">
            <h2 className="font-semibold">{t("settings")}</h2>
            <Field label={t("joinMode")}>
              <Select
                value={settings.join_mode}
                onChange={(e) => setSettings({ ...settings, join_mode: e.target.value as Church["join_mode"] })}
              >
                <option value="open">{t("joinOpen")}</option>
                <option value="approval">{t("joinApproval")}</option>
                <option value="invite">{t("joinInvite")}</option>
              </Select>
            </Field>
            <Field label={t("defaultLocale")}>
              <Select
                value={settings.default_locale}
                onChange={(e) => setSettings({ ...settings, default_locale: e.target.value as Church["default_locale"] })}
              >
                <option value="fr">{t("french")}</option>
                <option value="en">{t("english")}</option>
              </Select>
            </Field>
          </Card>
          <Feedback error={error} notice={notice} />
          <Button onClick={() => void save()} disabled={busy || uploading}>
            {t("save")}
          </Button>
        </div>

        {/* Live preview of the app header + welcome card */}
        <div className="lg:sticky lg:top-10 lg:self-start">
          <p className="mb-2 text-sm font-medium">{t("preview")}</p>
          <div className="overflow-hidden rounded-[28px] border-8 border-foreground/80 bg-white text-[#1c1830] shadow-lg">
            <div className="flex items-center gap-3 px-4 py-3 text-white" style={{ background: b.primary_color }}>
              <div
                className="flex h-9 w-9 shrink-0 items-center justify-center overflow-hidden rounded-full font-bold"
                style={{ background: b.accent_color }}
              >
                {b.logo_url ? (
                  // eslint-disable-next-line @next/next/no-img-element -- storage URL
                  <img src={b.logo_url} alt="" className="h-full w-full object-cover" />
                ) : (
                  settings.name.charAt(0)
                )}
              </div>
              <div className="min-w-0">
                <div className="truncate text-sm font-semibold">{settings.name}</div>
                <div className="truncate text-xs opacity-80">{tr(b.tagline, settings.default_locale)}</div>
              </div>
            </div>
            <div className="space-y-3 p-3">
              <div
                className="rounded-2xl p-4 text-white"
                style={{ background: `linear-gradient(90deg, ${b.primary_color}, ${b.accent_color})` }}
              >
                {b.cover_url && (
                  // eslint-disable-next-line @next/next/no-img-element -- storage URL
                  <img src={b.cover_url} alt="" className="mb-3 max-h-32 w-full rounded-lg object-contain" />
                )}
                <div className="font-semibold">{tr(b.welcome_text, settings.default_locale) || settings.name}</div>
              </div>
              <div className="rounded-xl border border-[#e4e1ee] p-3 text-xs">
                <div className="font-semibold uppercase tracking-wide" style={{ color: b.accent_color }}>
                  {t("upcomingEvents")}
                </div>
                <div className="mt-2 flex items-center gap-2">
                  <div className="rounded-md px-2 py-1 text-center text-white" style={{ background: b.primary_color }}>
                    12
                  </div>
                  <div>…</div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
