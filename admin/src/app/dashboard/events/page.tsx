"use client";

import Link from "next/link";
import { useCallback, useEffect, useState } from "react";
import { Badge, Button, Card, Empty, Feedback, I18nField, PageHeader, Spinner, cleanI18n, useAction } from "@/components/ui";
import { useCurrentChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import type { ChurchEvent, EventCategory, I18nText } from "@/lib/types";

export default function EventsPage() {
  const { t, tr, fmtDate } = useI18n();
  const church = useCurrentChurch();
  const [events, setEvents] = useState<ChurchEvent[] | null>(null);
  const [counts, setCounts] = useState<Map<string, number>>(new Map());
  const [tab, setTab] = useState<"upcoming" | "past">("upcoming");
  const [now, setNow] = useState(0);
  const { busy, error, notice, run } = useAction();

  const load = useCallback(async () => {
    const db = supabase();
    const [{ data: evs }, { data: regs }] = await Promise.all([
      db.from("events").select("*").eq("church_id", church.id).order("starts_at"),
      db.from("event_registrations").select("event_id, seats").eq("church_id", church.id).eq("status", "confirmed"),
    ]);
    const map = new Map<string, number>();
    for (const r of (regs ?? []) as { event_id: string; seats: number }[]) map.set(r.event_id, (map.get(r.event_id) ?? 0) + r.seats);
    setCounts(map);
    setNow(Date.now());
    setEvents((evs ?? []) as ChurchEvent[]);
  }, [church.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  if (!events) return <Spinner />;
  const shown =
    tab === "upcoming"
      ? events.filter((e) => new Date(e.ends_at ?? e.starts_at).getTime() >= now)
      : events.filter((e) => new Date(e.ends_at ?? e.starts_at).getTime() < now).reverse();

  return (
    <div className="space-y-8">
      <PageHeader
        title={t("eventsTitle")}
        actions={
          <Link href="/dashboard/events/new" className="inline-flex min-h-10 items-center rounded-lg bg-brand px-4 text-sm font-medium text-brand-fg">
            + {t("newEvent")}
          </Link>
        }
      />
      <div className="flex gap-2">
        {(["upcoming", "past"] as const).map((k) => (
          <Button key={k} variant={tab === k ? "primary" : "secondary"} onClick={() => setTab(k)}>
            {t(k)}
          </Button>
        ))}
      </div>
      <Feedback error={error} notice={notice} />
      {shown.length === 0 ? (
        <Empty />
      ) : (
        <div className="space-y-3">
          {shown.map((e) => (
            <Card key={e.id} className="flex flex-col gap-4 sm:flex-row sm:items-center">
              <div className="flex h-16 w-16 shrink-0 flex-col items-center justify-center rounded-lg bg-brand text-brand-fg">
                <span className="text-xl font-bold leading-none">{new Date(e.starts_at).getDate()}</span>
                <span className="text-xs uppercase">
                  {new Intl.DateTimeFormat(undefined, { month: "short" }).format(new Date(e.starts_at))}
                </span>
              </div>
              <div className="min-w-0 flex-1">
                <div className="flex flex-wrap items-center gap-2">
                  <span className="font-semibold">{tr(e.title, church.default_locale)}</span>
                  <Badge tone={e.published_at ? "success" : "neutral"}>{e.published_at ? t("published") : t("draft")}</Badge>
                  {e.visibility === "members" && <Badge tone="brand">{t("visMembers")}</Badge>}
                </div>
                <div className="mt-1 text-sm text-muted">
                  {fmtDate(e.starts_at)}
                  {e.location ? ` · ${e.location}` : ""}
                </div>
                <div className="mt-1 text-sm">
                  {t("seats")}: <span className="tabular-nums">{counts.get(e.id) ?? 0}</span>
                  {e.capacity ? ` / ${e.capacity}` : ""}
                </div>
              </div>
              <div className="flex flex-wrap gap-2">
                <Link
                  href={`/dashboard/events/registrations?id=${e.id}`}
                  className="inline-flex min-h-10 items-center rounded-lg border border-border px-4 text-sm hover:bg-brand-soft"
                >
                  {t("seeRegistrations")}
                </Link>
                <Link
                  href={`/dashboard/events/edit?id=${e.id}`}
                  className="inline-flex min-h-10 items-center rounded-lg border border-border px-4 text-sm hover:bg-brand-soft"
                >
                  {t("edit")}
                </Link>
                <Button
                  variant="danger"
                  disabled={busy}
                  onClick={() => {
                    if (!confirm(t("confirmDelete"))) return;
                    void run(async () => {
                      const { error } = await supabase().from("events").delete().eq("id", e.id);
                      if (error) throw error;
                      await load();
                    });
                  }}
                >
                  {t("delete")}
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
      <Categories churchId={church.id} />
    </div>
  );
}

function Categories({ churchId }: { churchId: string }) {
  const { t, tr } = useI18n();
  const [cats, setCats] = useState<EventCategory[]>([]);
  const [name, setName] = useState<I18nText>({});
  const { busy, error, run } = useAction();

  const load = useCallback(async () => {
    const { data } = await supabase().from("event_categories").select("*").eq("church_id", churchId).order("sort");
    setCats((data ?? []) as EventCategory[]);
  }, [churchId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  return (
    <Card className="space-y-4">
      <h2 className="font-semibold">{t("categories")}</h2>
      <div className="flex flex-wrap gap-2">
        {cats.map((c) => (
          <span key={c.id} className="inline-flex items-center gap-2 rounded-full border border-border px-3 py-1 text-sm">
            {tr(c.name)}
            <button
              type="button"
              aria-label={t("delete")}
              className="text-muted hover:text-danger"
              onClick={() =>
                void run(async () => {
                  const { error } = await supabase().from("event_categories").delete().eq("id", c.id);
                  if (error) throw error;
                  await load();
                })
              }
            >
              ✕
            </button>
          </span>
        ))}
      </div>
      <form
        className="space-y-3"
        onSubmit={(e) => {
          e.preventDefault();
          void run(async () => {
            const n = cleanI18n(name);
            if (!n) return;
            const { error } = await supabase()
              .from("event_categories")
              .insert({ church_id: churchId, name: n, sort: cats.length + 1 });
            if (error) throw error;
            setName({});
            await load();
          });
        }}
      >
        <I18nField label={t("newCategory")} value={name} onChange={setName} required />
        <Button type="submit" variant="secondary" disabled={busy}>
          {t("add")}
        </Button>
      </form>
      <Feedback error={error} notice={null} />
    </Card>
  );
}
