"use client";

import { useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, Feedback, Field, Input, PageHeader, Select, useAction } from "@/components/ui";
import { useChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

const slugify = (s: string) =>
  s
    .normalize("NFD")
    .replace(/[̀-ͯ]/g, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 40);

/** Creates a church (status pending) and sends the user to verification. */
export function CreateChurch() {
  const { t } = useI18n();
  const { memberships, reload, selectChurch } = useChurch();
  const router = useRouter();
  const [name, setName] = useState("");
  const [slug, setSlug] = useState("");
  const [slugTouched, setSlugTouched] = useState(false);
  const [city, setCity] = useState("");
  const [country, setCountry] = useState("");
  const [churchType, setChurchType] = useState("");
  const [locale, setLocale] = useState("fr");
  const { busy, error, notice, run } = useAction();

  return (
    <div>
      <PageHeader title={t("createChurchTitle")} subtitle={memberships.length ? undefined : t("noStaffChurch")} />
      <Card className="max-w-2xl">
        <p className="mb-6 text-sm text-muted">{t("createChurchBody")}</p>
        <form
          className="grid gap-4 sm:grid-cols-2"
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              const db = supabase();
              const { data: id, error } = await db.rpc("create_church", {
                p_name: name,
                p_slug: slug,
                p_city: city || null,
                p_country: country || null,
                p_default_locale: locale,
              });
              if (error) throw error;
              if (churchType.trim()) {
                await db.from("churches").update({ church_type: churchType.trim() }).eq("id", id);
              }
              selectChurch(id as string);
              await reload();
              router.push("/dashboard/verification");
            });
          }}
        >
          <Field label={t("churchName")} className="sm:col-span-2">
            <Input
              required
              minLength={2}
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                if (!slugTouched) setSlug(slugify(e.target.value));
              }}
            />
          </Field>
          <Field label={t("slug")} help={`${t("slugHelp")}${slug || "…"}`} className="sm:col-span-2">
            <Input
              required
              pattern="[a-z0-9][a-z0-9-]{1,38}[a-z0-9]"
              value={slug}
              onChange={(e) => {
                setSlugTouched(true);
                setSlug(e.target.value.toLowerCase());
              }}
            />
          </Field>
          <Field label={t("city")}>
            <Input value={city} onChange={(e) => setCity(e.target.value)} />
          </Field>
          <Field label={t("country")}>
            <Input maxLength={2} value={country} onChange={(e) => setCountry(e.target.value.toUpperCase())} />
          </Field>
          <Field label={t("churchType")}>
            <Input placeholder="Baptiste, évangélique…" value={churchType} onChange={(e) => setChurchType(e.target.value)} />
          </Field>
          <Field label={t("defaultLocale")}>
            <Select value={locale} onChange={(e) => setLocale(e.target.value)}>
              <option value="fr">{t("french")}</option>
              <option value="en">{t("english")}</option>
            </Select>
          </Field>
          <div className="sm:col-span-2">
            <Feedback error={error} notice={notice} />
          </div>
          <div className="sm:col-span-2">
            <Button type="submit" disabled={busy}>
              {t("create")}
            </Button>
          </div>
        </form>
      </Card>
    </div>
  );
}
