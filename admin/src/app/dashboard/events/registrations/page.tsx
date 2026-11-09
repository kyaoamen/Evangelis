"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { Badge, Button, Empty, PageHeader, Spinner, Table, Td } from "@/components/ui";
import { downloadCsv } from "@/lib/csv";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import type { ChurchEvent, Profile, Registration } from "@/lib/types";

const TONE = { confirmed: "success", waitlist: "warning", cancelled: "neutral" } as const;

function RegistrationsInner() {
  const { t, tr, fmtDate } = useI18n();
  const id = useSearchParams().get("id");
  const [event, setEvent] = useState<ChurchEvent | null>(null);
  const [regs, setRegs] = useState<Registration[] | null>(null);
  const [profiles, setProfiles] = useState<Map<string, Profile>>(new Map());

  useEffect(() => {
    if (!id) return;
    const db = supabase();
    void (async () => {
      const [{ data: ev }, { data: rs }] = await Promise.all([
        db.from("events").select("*").eq("id", id).maybeSingle(),
        db.from("event_registrations").select("*").eq("event_id", id).order("created_at"),
      ]);
      const list = (rs ?? []) as Registration[];
      const ids = [...new Set(list.map((r) => r.user_id))];
      const { data: ps } = ids.length
        ? await db.from("profiles").select("id, email, first_name, last_name, phone").in("id", ids)
        : { data: [] };
      setProfiles(new Map(((ps ?? []) as Profile[]).map((p) => [p.id, p])));
      setEvent(ev as ChurchEvent);
      setRegs(list);
    })();
  }, [id]);

  if (!id) return <Empty />;
  if (!regs || !event) return <Spinner />;

  const person = (r: Registration) => {
    const p = profiles.get(r.user_id);
    return { name: [p?.first_name, p?.last_name].filter(Boolean).join(" ") || p?.email || "—", p };
  };
  const confirmed = regs.filter((r) => r.status === "confirmed").reduce((a, r) => a + r.seats, 0);

  return (
    <div className="space-y-6">
      <PageHeader
        title={tr(event.title)}
        subtitle={`${fmtDate(event.starts_at)} · ${t("seats")}: ${confirmed}${event.capacity ? ` / ${event.capacity}` : ""}`}
        actions={
          <Button
            variant="secondary"
            onClick={() =>
              downloadCsv(
                `inscriptions-${id.slice(0, 8)}.csv`,
                ["Nom", "E-mail", "Téléphone", "Statut", "Places", "Inscrit le", "Arrivé à"],
                regs.map((r) => {
                  const { name, p } = person(r);
                  return [name, p?.email, p?.phone, r.status, r.seats, r.created_at, r.checked_in_at];
                }),
              )
            }
          >
            {t("exportCsv")}
          </Button>
        }
      />
      {regs.length === 0 ? (
        <Empty />
      ) : (
        <Table head={[t("name"), t("status"), t("seats"), t("registeredOn"), t("checkedIn")]}>
          {regs.map((r) => {
            const { name, p } = person(r);
            return (
              <tr key={r.id}>
                <Td>
                  <div className="font-medium">{name}</div>
                  <div className="text-xs text-muted">{[p?.email, p?.phone].filter(Boolean).join(" · ")}</div>
                </Td>
                <Td>
                  <Badge tone={TONE[r.status]}>{t(`reg_${r.status}`)}</Badge>
                </Td>
                <Td className="tabular-nums">{r.seats}</Td>
                <Td className="whitespace-nowrap text-muted">{fmtDate(r.created_at)}</Td>
                <Td>{r.checked_in_at ? <Badge tone="success">{fmtDate(r.checked_in_at)}</Badge> : "—"}</Td>
              </tr>
            );
          })}
        </Table>
      )}
    </div>
  );
}

export default function RegistrationsPage() {
  return (
    <Suspense fallback={<Spinner />}>
      <RegistrationsInner />
    </Suspense>
  );
}
