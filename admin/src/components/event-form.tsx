"use client";

import { useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import {
  Button,
  Card,
  Checkbox,
  Feedback,
  Field,
  I18nField,
  ImageInput,
  Input,
  Select,
  cleanI18n,
  fromLocalInput,
  toLocalInput,
  useAction,
} from "@/components/ui";
import { useCurrentChurch, useChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { MEDIA_BUCKET, publicUrl, supabase, uploadFile } from "@/lib/supabase";
import type { ChurchEvent, EventCategory, I18nText } from "@/lib/types";

type Draft = Omit<ChurchEvent, "id" | "church_id"> & { id?: string };

const empty: Draft = {
  category_id: null,
  title: {},
  description: null,
  poster_url: null,
  starts_at: "",
  ends_at: null,
  location: null,
  capacity: null,
  max_seats_per_registration: 1,
  registration_open: true,
  visibility: "public",
  published_at: null,
};

export function EventForm({ event }: { event?: ChurchEvent }) {
  const { t, tr } = useI18n();
  const church = useCurrentChurch();
  const { user } = useChurch();
  const router = useRouter();
  const [d, setD] = useState<Draft>(event ?? empty);
  const [publish, setPublish] = useState(!!event?.published_at || !event);
  const [categories, setCategories] = useState<EventCategory[]>([]);
  const [uploading, setUploading] = useState(false);
  const { busy, error, run, setError } = useAction();

  useEffect(() => {
    void supabase()
      .from("event_categories")
      .select("*")
      .eq("church_id", church.id)
      .order("sort")
      .then(({ data }) => setCategories((data ?? []) as EventCategory[]));
  }, [church.id]);

  const set = <K extends keyof Draft>(k: K, v: Draft[K]) => setD((x) => ({ ...x, [k]: v }));

  return (
    <form
      className="space-y-6"
      onSubmit={(e) => {
        e.preventDefault();
        void run(async () => {
          const title = cleanI18n(d.title);
          if (!title) throw new Error(t("eventTitle"));
          const row = {
            church_id: church.id,
            category_id: d.category_id || null,
            title,
            description: cleanI18n(d.description),
            poster_url: d.poster_url,
            starts_at: d.starts_at,
            ends_at: d.ends_at,
            location: d.location?.trim() || null,
            capacity: d.capacity,
            max_seats_per_registration: d.max_seats_per_registration,
            registration_open: d.registration_open,
            visibility: d.visibility,
            published_at: publish ? (event?.published_at ?? new Date().toISOString()) : null,
          };
          const db = supabase();
          const res = event
            ? await db.from("events").update(row).eq("id", event.id)
            : await db.from("events").insert({ ...row, created_by: user?.id });
          if (res.error) throw res.error;
          router.push("/dashboard/events");
        });
      }}
    >
      <Card className="space-y-4">
        <I18nField label={t("eventTitle")} value={d.title} onChange={(v: I18nText) => set("title", v)} required />
        <I18nField label={t("description")} value={d.description} onChange={(v) => set("description", v)} multiline />
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("category")}>
            <Select value={d.category_id ?? ""} onChange={(e) => set("category_id", e.target.value || null)}>
              <option value="">{t("noCategory")}</option>
              {categories.map((c) => (
                <option key={c.id} value={c.id}>
                  {tr(c.name)}
                </option>
              ))}
            </Select>
          </Field>
          <Field label={t("location")}>
            <Input value={d.location ?? ""} onChange={(e) => set("location", e.target.value)} />
          </Field>
          <Field label={t("startsAt")}>
            <Input
              type="datetime-local"
              required
              value={toLocalInput(d.starts_at)}
              onChange={(e) => set("starts_at", fromLocalInput(e.target.value) ?? "")}
            />
          </Field>
          <Field label={t("endsAt")}>
            <Input
              type="datetime-local"
              min={toLocalInput(d.starts_at)}
              value={toLocalInput(d.ends_at)}
              onChange={(e) => set("ends_at", fromLocalInput(e.target.value))}
            />
          </Field>
        </div>
        <ImageInput
          label={t("poster")}
          url={d.poster_url}
          busy={uploading}
          onFile={async (f) => {
            setUploading(true);
            try {
              set("poster_url", publicUrl(await uploadFile(MEDIA_BUCKET, church.id, "poster", f)));
            } catch (e) {
              setError(e && typeof e === "object" && "message" in e ? String(e.message) : String(e));
            } finally {
              setUploading(false);
            }
          }}
        />
      </Card>

      <Card className="space-y-4">
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label={t("capacity")} help={t("capacityHelp")}>
            <Input
              type="number"
              min={1}
              value={d.capacity ?? ""}
              onChange={(e) => set("capacity", e.target.value ? Number(e.target.value) : null)}
            />
          </Field>
          <Field label={t("maxSeats")}>
            <Input
              type="number"
              min={1}
              max={20}
              required
              value={d.max_seats_per_registration}
              onChange={(e) => set("max_seats_per_registration", Number(e.target.value) || 1)}
            />
          </Field>
          <Field label={t("visibility")}>
            <Select value={d.visibility} onChange={(e) => set("visibility", e.target.value as Draft["visibility"])}>
              <option value="public">{t("visPublic")}</option>
              <option value="members">{t("visMembers")}</option>
            </Select>
          </Field>
        </div>
        <Checkbox label={t("registrationOpen")} checked={d.registration_open} onChange={(v) => set("registration_open", v)} />
        <Checkbox label={t("published")} checked={publish} onChange={setPublish} />
      </Card>

      <Feedback error={error} notice={null} />
      <div className="flex gap-2">
        <Button type="submit" disabled={busy || uploading}>
          {t("save")}
        </Button>
        <Button variant="secondary" onClick={() => router.push("/dashboard/events")}>
          {t("cancel")}
        </Button>
      </div>
    </form>
  );
}
