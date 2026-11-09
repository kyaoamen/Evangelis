"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { Card, PageHeader } from "@/components/ui";
import { useChurch, useCurrentChurch } from "@/lib/church";
import { useI18n, type MessageKey } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

interface Stats {
  active: number;
  pending: number;
  events: number;
  registrations: number;
  feedback: number;
}

export default function DashboardPage() {
  const { t } = useI18n();
  const church = useCurrentChurch();
  const { isAdmin } = useChurch();
  const [stats, setStats] = useState<Stats | null>(null);

  useEffect(() => {
    let cancelled = false;
    const db = supabase();
    const count = async (q: PromiseLike<{ count: number | null }>) => (await q).count ?? 0;
    void Promise.all([
      count(db.from("memberships").select("id", { count: "exact", head: true }).eq("church_id", church.id).eq("status", "active")),
      count(db.from("memberships").select("id", { count: "exact", head: true }).eq("church_id", church.id).eq("status", "pending")),
      count(
        db
          .from("events")
          .select("id", { count: "exact", head: true })
          .eq("church_id", church.id)
          .gte("starts_at", new Date().toISOString()),
      ),
      count(
        db
          .from("event_registrations")
          .select("id", { count: "exact", head: true })
          .eq("church_id", church.id)
          .eq("status", "confirmed"),
      ),
      count(db.from("feedback").select("id", { count: "exact", head: true }).eq("church_id", church.id).eq("status", "new")),
    ]).then(([active, pending, events, registrations, feedback]) => {
      if (!cancelled) setStats({ active, pending, events, registrations, feedback });
    });
    return () => {
      cancelled = true;
    };
  }, [church.id]);

  const tiles: { key: MessageKey; value: number | undefined; href: string }[] = [
    { key: "activeMembers", value: stats?.active, href: "/dashboard/members" },
    { key: "pendingMembers", value: stats?.pending, href: "/dashboard/members?status=pending" },
    { key: "upcomingEvents", value: stats?.events, href: "/dashboard/events" },
    { key: "registrations", value: stats?.registrations, href: "/dashboard/events" },
    ...(isAdmin ? [{ key: "newFeedback" as const, value: stats?.feedback, href: "/dashboard/feedback" }] : []),
  ];

  return (
    <div>
      <PageHeader title={church.name} subtitle={[church.city, church.country].filter(Boolean).join(", ")} />
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
        {tiles.map((tile) => (
          <Link key={tile.key} href={tile.href} className="rounded-xl border border-border bg-surface p-4 hover:border-brand">
            <div className="text-3xl font-semibold tabular-nums">{tile.value ?? "–"}</div>
            <div className="mt-1 text-sm text-muted">{t(tile.key)}</div>
          </Link>
        ))}
      </div>

      <h2 className="mb-3 mt-10 text-lg font-semibold">{t("quickLinks")}</h2>
      <div className="grid gap-3 sm:grid-cols-3">
        {(
          [
            ["/dashboard/events/new", "newEvent"],
            ["/dashboard/announcements", "newAnnouncement"],
            ["/dashboard/checkin", "navCheckin"],
          ] as const
        ).map(([href, key]) => (
          <Link key={href} href={href}>
            <Card className="h-full hover:border-brand">
              <span className="font-medium">{t(key)}</span>
            </Card>
          </Link>
        ))}
      </div>
    </div>
  );
}
