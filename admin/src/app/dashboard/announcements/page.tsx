"use client";

import { useCallback, useEffect, useState } from "react";
import {
  Badge,
  Button,
  Card,
  Empty,
  Feedback,
  Field,
  I18nField,
  Input,
  PageHeader,
  Select,
  Spinner,
  cleanI18n,
  fromLocalInput,
  useAction,
} from "@/components/ui";
import { useChurch, useCurrentChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import type { Announcement, I18nText } from "@/lib/types";

export default function AnnouncementsPage() {
  const { t, tr, fmtDate } = useI18n();
  const church = useCurrentChurch();
  const { user } = useChurch();
  const [items, setItems] = useState<Announcement[] | null>(null);
  const [now, setNow] = useState(0);
  const [title, setTitle] = useState<I18nText>({});
  const [body, setBody] = useState<I18nText>({});
  const [audience, setAudience] = useState<"all" | "members">("all");
  const [publishAt, setPublishAt] = useState("");
  const { busy, error, notice, run, setNotice } = useAction();

  const load = useCallback(async () => {
    const { data } = await supabase()
      .from("announcements")
      .select("*")
      .eq("church_id", church.id)
      .order("publish_at", { ascending: false })
      .limit(100);
    setItems((data ?? []) as Announcement[]);
    setNow(Date.now());
  }, [church.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  return (
    <div className="space-y-8">
      <PageHeader title={t("announcementsTitle")} />
      <Card>
        <h2 className="mb-4 font-semibold">{t("newAnnouncement")}</h2>
        <form
          className="space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              const tt = cleanI18n(title);
              const bb = cleanI18n(body);
              if (!tt || !bb) throw new Error(`${t("eventTitle")} / ${t("body")}`);
              const db = supabase();
              const { data, error } = await db
                .from("announcements")
                .insert({
                  church_id: church.id,
                  title: tt,
                  body: bb,
                  audience,
                  publish_at: fromLocalInput(publishAt) ?? new Date().toISOString(),
                  created_by: user?.id,
                })
                .select("id, publish_at")
                .single();
              if (error) throw error;
              setTitle({});
              setBody({});
              setPublishAt("");
              await load();
              // Push now only when published immediately; scheduled ones need a cron (see README).
              if (new Date(data.publish_at).getTime() <= Date.now()) {
                const res = await db.functions.invoke("send-announcement-push", { body: { announcement_id: data.id } });
                if (res.error) setNotice(t("pushNotConfigured"));
                else setNotice(`${t("pushResult")} ${(res.data as { sent?: number })?.sent ?? 0}`);
                await load();
              } else {
                setNotice(t("saved"));
              }
            });
          }}
        >
          <I18nField label={t("eventTitle")} value={title} onChange={setTitle} required />
          <I18nField label={t("body")} value={body} onChange={setBody} multiline required />
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label={t("audience")}>
              <Select value={audience} onChange={(e) => setAudience(e.target.value as "all" | "members")}>
                <option value="all">{t("audienceAll")}</option>
                <option value="members">{t("audienceMembers")}</option>
              </Select>
            </Field>
            <Field label={t("publishAt")} help={t("publishNow")}>
              <Input type="datetime-local" value={publishAt} onChange={(e) => setPublishAt(e.target.value)} />
            </Field>
          </div>
          <Feedback error={error} notice={notice} />
          <Button type="submit" disabled={busy}>
            {t("publish")}
          </Button>
        </form>
      </Card>

      {!items ? (
        <Spinner />
      ) : items.length === 0 ? (
        <Empty />
      ) : (
        <div className="space-y-3">
          {items.map((a) => {
            const scheduled = new Date(a.publish_at).getTime() > now;
            return (
              <Card key={a.id} className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2 text-xs text-muted">
                    <span>{fmtDate(a.publish_at)}</span>
                    {scheduled && <Badge tone="warning">{t("scheduled")}</Badge>}
                    {a.audience === "members" && <Badge tone="brand">{t("audienceMembers")}</Badge>}
                    {a.push_sent_at && <Badge tone="success">{t("pushSent")}</Badge>}
                  </div>
                  <div className="mt-1 font-semibold">{tr(a.title, church.default_locale)}</div>
                  <p className="mt-1 whitespace-pre-line text-sm">{tr(a.body, church.default_locale)}</p>
                </div>
                <Button
                  variant="danger"
                  disabled={busy}
                  onClick={() => {
                    if (!confirm(t("confirmDelete"))) return;
                    void run(async () => {
                      const { error } = await supabase().from("announcements").delete().eq("id", a.id);
                      if (error) throw error;
                      await load();
                    });
                  }}
                >
                  {t("delete")}
                </Button>
              </Card>
            );
          })}
        </div>
      )}
    </div>
  );
}
