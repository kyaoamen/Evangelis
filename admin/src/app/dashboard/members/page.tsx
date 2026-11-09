"use client";

import { Suspense, useCallback, useEffect, useMemo, useState } from "react";
import { useSearchParams } from "next/navigation";
import {
  Badge,
  Button,
  Card,
  Empty,
  Feedback,
  Field,
  Input,
  PageHeader,
  Select,
  Spinner,
  Table,
  Td,
  fromLocalInput,
  useAction,
} from "@/components/ui";
import { downloadCsv } from "@/lib/csv";
import { useChurch, useCurrentChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import type { Invite, Member, MembershipStatus, Profile, Role } from "@/lib/types";

const STATUS_TONE = { pending: "warning", active: "success", suspended: "danger", left: "neutral" } as const;
const ROLES: Role[] = ["member", "editor", "pastor", "admin"];

function MembersInner() {
  const { t, fmtDate } = useI18n();
  const church = useCurrentChurch();
  const { isAdmin, role: myRole, user } = useChurch();
  const params = useSearchParams();
  const [status, setStatus] = useState<MembershipStatus | "all">((params.get("status") as MembershipStatus) ?? "all");
  const [query, setQuery] = useState("");
  const [members, setMembers] = useState<Member[] | null>(null);
  const [profiles, setProfiles] = useState<Map<string, Profile>>(new Map());
  const { busy, error, notice, run } = useAction();

  const load = useCallback(async () => {
    const db = supabase();
    const { data } = await db
      .from("memberships")
      .select("id, user_id, role, status, joined_at, created_at")
      .eq("church_id", church.id)
      .order("created_at", { ascending: false });
    const list = (data ?? []) as Member[];
    const ids = list.map((m) => m.user_id);
    const map = new Map<string, Profile>();
    for (let i = 0; i < ids.length; i += 200) {
      const { data: ps } = await db
        .from("profiles")
        .select("id, email, first_name, last_name, phone")
        .in("id", ids.slice(i, i + 200));
      for (const p of (ps ?? []) as Profile[]) map.set(p.id, p);
    }
    setProfiles(map);
    setMembers(list);
  }, [church.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  const name = useCallback(
    (m: Member) => {
      const p = profiles.get(m.user_id);
      const n = [p?.first_name, p?.last_name].filter(Boolean).join(" ");
      return n || p?.email || "—";
    },
    [profiles],
  );

  const shown = useMemo(() => {
    const q = query.trim().toLowerCase();
    return (members ?? []).filter((m) => {
      if (status !== "all" && m.status !== status) return false;
      if (!q) return true;
      const p = profiles.get(m.user_id);
      return `${name(m)} ${p?.email ?? ""} ${p?.phone ?? ""}`.toLowerCase().includes(q);
    });
  }, [members, status, query, profiles, name]);

  const setMemberStatus = (m: Member, s: MembershipStatus) =>
    run(async () => {
      const { error } = await supabase().rpc("set_membership_status", { p_membership: m.id, p_status: s });
      if (error) throw error;
      await load();
    }, t("saved"));

  const setMemberRole = (m: Member, r: Role) =>
    run(async () => {
      const { error } = await supabase().rpc("set_member_role", { p_membership: m.id, p_role: r });
      if (error) throw error;
      await load();
    }, t("saved"));

  if (!members) return <Spinner />;

  return (
    <div className="space-y-8">
      <PageHeader
        title={t("membersTitle")}
        actions={
          <Button
            variant="secondary"
            onClick={() =>
              downloadCsv(
                `membres-${church.slug}.csv`,
                ["Prénom", "Nom", "E-mail", "Téléphone", "Rôle", "Statut", "Depuis"],
                shown.map((m) => {
                  const p = profiles.get(m.user_id);
                  return [p?.first_name, p?.last_name, p?.email, p?.phone, m.role, m.status, m.joined_at?.slice(0, 10)];
                }),
              )
            }
          >
            {t("exportCsv")}
          </Button>
        }
      />

      <div className="flex flex-col gap-3 sm:flex-row">
        <Input placeholder={t("searchMembers")} value={query} onChange={(e) => setQuery(e.target.value)} className="sm:max-w-xs" />
        <div className="flex flex-wrap gap-2">
          {(["all", "pending", "active", "suspended"] as const).map((s) => (
            <Button key={s} variant={status === s ? "primary" : "secondary"} onClick={() => setStatus(s)}>
              {s === "all" ? t("all") : t(`ms_${s}`)}
              {s !== "all" && <span className="tabular-nums opacity-70">{members.filter((m) => m.status === s).length}</span>}
            </Button>
          ))}
        </div>
      </div>

      <Feedback error={error} notice={notice} />

      {shown.length === 0 ? (
        <Empty />
      ) : (
        <Table head={[t("name"), t("role"), t("status"), t("joined"), isAdmin ? t("actions") : ""]}>
          {shown.map((m) => {
            const p = profiles.get(m.user_id);
            const isSelf = m.user_id === user?.id;
            const canEditRole = isAdmin && m.role !== "owner" && !isSelf && (myRole === "owner" || m.role !== "admin");
            return (
              <tr key={m.id}>
                <Td>
                  <div className="font-medium">{name(m)}</div>
                  <div className="text-xs text-muted">{[p?.email, p?.phone].filter(Boolean).join(" · ")}</div>
                </Td>
                <Td>
                  {canEditRole ? (
                    <Select
                      aria-label={t("role")}
                      value={m.role}
                      disabled={busy}
                      onChange={(e) => void setMemberRole(m, e.target.value as Role)}
                      className="w-40"
                    >
                      {ROLES.filter((r) => r !== "admin" || myRole === "owner").map((r) => (
                        <option key={r} value={r}>
                          {t(`role_${r}`)}
                        </option>
                      ))}
                    </Select>
                  ) : (
                    t(`role_${m.role}`)
                  )}
                </Td>
                <Td>
                  <Badge tone={STATUS_TONE[m.status]}>{t(`ms_${m.status}`)}</Badge>
                </Td>
                <Td className="whitespace-nowrap text-muted">{fmtDate(m.joined_at ?? m.created_at, false)}</Td>
                <Td>
                  {isAdmin && m.role !== "owner" && !isSelf && (
                    <div className="flex flex-wrap gap-2">
                      {m.status === "pending" && (
                        <>
                          <Button disabled={busy} onClick={() => void setMemberStatus(m, "active")}>
                            {t("approve")}
                          </Button>
                          <Button variant="danger" disabled={busy} onClick={() => void setMemberStatus(m, "left")}>
                            {t("reject")}
                          </Button>
                        </>
                      )}
                      {m.status === "active" && (
                        <Button variant="danger" disabled={busy} onClick={() => void setMemberStatus(m, "suspended")}>
                          {t("suspend")}
                        </Button>
                      )}
                      {m.status === "suspended" && (
                        <Button variant="secondary" disabled={busy} onClick={() => void setMemberStatus(m, "active")}>
                          {t("reinstate")}
                        </Button>
                      )}
                    </div>
                  )}
                </Td>
              </tr>
            );
          })}
        </Table>
      )}

      {isAdmin && <Invites churchId={church.id} canGrantAdmin={myRole === "owner"} />}
    </div>
  );
}

function Invites({ churchId, canGrantAdmin }: { churchId: string; canGrantAdmin: boolean }) {
  const { t, fmtDate } = useI18n();
  const [invites, setInvites] = useState<Invite[]>([]);
  const [role, setRole] = useState<Role>("member");
  const [maxUses, setMaxUses] = useState("");
  const [expires, setExpires] = useState("");
  const { busy, error, notice, run } = useAction();

  const load = useCallback(async () => {
    const { data } = await supabase()
      .from("invites")
      .select("*")
      .eq("church_id", churchId)
      .order("created_at", { ascending: false });
    setInvites((data ?? []) as Invite[]);
  }, [churchId]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  return (
    <Card className="space-y-4">
      <div>
        <h2 className="font-semibold">{t("invites")}</h2>
        <p className="text-sm text-muted">{t("invitesHelp")}</p>
      </div>
      <form
        className="grid gap-3 sm:grid-cols-4 sm:items-end"
        onSubmit={(e) => {
          e.preventDefault();
          void run(async () => {
            const { error } = await supabase()
              .from("invites")
              .insert({
                church_id: churchId,
                role,
                max_uses: maxUses ? Number(maxUses) : null,
                expires_at: fromLocalInput(expires),
              });
            if (error) throw error;
            setMaxUses("");
            setExpires("");
            await load();
          });
        }}
      >
        <Field label={t("role")}>
          <Select value={role} onChange={(e) => setRole(e.target.value as Role)}>
            {ROLES.filter((r) => r !== "admin" || canGrantAdmin).map((r) => (
              <option key={r} value={r}>
                {t(`role_${r}`)}
              </option>
            ))}
          </Select>
        </Field>
        <Field label={t("maxUses")}>
          <Input type="number" min={1} placeholder={t("unlimited")} value={maxUses} onChange={(e) => setMaxUses(e.target.value)} />
        </Field>
        <Field label={t("expires")}>
          <Input type="datetime-local" value={expires} onChange={(e) => setExpires(e.target.value)} />
        </Field>
        <Button type="submit" disabled={busy}>
          {t("newInvite")}
        </Button>
      </form>
      <Feedback error={error} notice={notice} />
      {invites.length > 0 && (
        <ul className="divide-y divide-border rounded-lg border border-border">
          {invites.map((inv) => (
            <li key={inv.id} className="flex flex-col gap-2 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between">
              <div className="flex flex-wrap items-center gap-3">
                <code className="rounded bg-brand-soft px-2 py-1 font-mono text-base font-semibold tracking-widest text-brand">
                  {inv.code}
                </code>
                <span>{t(`role_${inv.role}`)}</span>
                <span className="text-muted">
                  {t("uses")}: {inv.uses}/{inv.max_uses ?? "∞"}
                </span>
                {inv.expires_at && (
                  <span className="text-muted">
                    {t("expires")} {fmtDate(inv.expires_at)}
                  </span>
                )}
              </div>
              <Button
                variant="danger"
                disabled={busy}
                onClick={() =>
                  void run(async () => {
                    const { error } = await supabase().from("invites").delete().eq("id", inv.id);
                    if (error) throw error;
                    await load();
                  })
                }
              >
                {t("delete")}
              </Button>
            </li>
          ))}
        </ul>
      )}
    </Card>
  );
}

export default function MembersPage() {
  return (
    <Suspense fallback={<Spinner />}>
      <MembersInner />
    </Suspense>
  );
}
