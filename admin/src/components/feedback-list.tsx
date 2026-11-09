"use client";

import { useCallback, useEffect, useState } from "react";
import { Badge, Button, Empty, Feedback, Select, Spinner, useAction } from "@/components/ui";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import type { Feedback as FeedbackRow, FeedbackKind, FeedbackStatus } from "@/lib/types";

const KIND_TONE = { bug: "danger", idea: "brand", other: "neutral" } as const;
const STATUSES: FeedbackStatus[] = ["new", "planned", "done", "wontfix"];

/** Feedback list. With churchId: that church's feedback; without: all (platform admins). */
export function FeedbackList({ churchId, canTriage }: { churchId?: string; canTriage: boolean }) {
  const { t, fmtDate } = useI18n();
  const [rows, setRows] = useState<FeedbackRow[] | null>(null);
  const [kind, setKind] = useState<FeedbackKind | "all">("all");
  const [status, setStatus] = useState<FeedbackStatus | "all">("all");
  const { busy, error, notice, run } = useAction();

  const load = useCallback(async () => {
    let q = supabase().from("feedback").select("*, churches(name)").order("created_at", { ascending: false }).limit(300);
    if (churchId) q = q.eq("church_id", churchId);
    if (kind !== "all") q = q.eq("kind", kind);
    if (status !== "all") q = q.eq("status", status);
    const { data } = await q;
    setRows((data ?? []) as FeedbackRow[]);
  }, [churchId, kind, status]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap gap-2">
        {(["all", "bug", "idea", "other"] as const).map((k) => (
          <Button key={k} variant={kind === k ? "primary" : "secondary"} onClick={() => setKind(k)}>
            {k === "all" ? t("all") : t(`kind_${k}`)}
          </Button>
        ))}
        <Select
          aria-label={t("status")}
          value={status}
          onChange={(e) => setStatus(e.target.value as FeedbackStatus | "all")}
          className="w-auto"
        >
          <option value="all">
            {t("status")}: {t("all")}
          </option>
          {STATUSES.map((s) => (
            <option key={s} value={s}>
              {t(`fs_${s}`)}
            </option>
          ))}
        </Select>
      </div>
      <Feedback error={error} notice={notice} />
      {!rows ? (
        <Spinner />
      ) : rows.length === 0 ? (
        <Empty />
      ) : (
        <ul className="space-y-3">
          {rows.map((f) => (
            <li key={f.id} className="rounded-xl border border-border bg-surface p-4">
              <div className="flex flex-wrap items-center gap-2 text-xs text-muted">
                <Badge tone={KIND_TONE[f.kind]}>{t(`kind_${f.kind}`)}</Badge>
                <span>{fmtDate(f.created_at)}</span>
                {!churchId && f.churches?.name && <span>· {f.churches.name}</span>}
                {f.platform && <span>· {f.platform}</span>}
                {f.screen && <code className="rounded bg-background px-1">{f.screen}</code>}
                {f.app_version && <span>· v{f.app_version}</span>}
              </div>
              <p className="mt-2 whitespace-pre-line text-sm">{f.message}</p>
              <div className="mt-3 flex items-center gap-2">
                {canTriage ? (
                  <Select
                    aria-label={t("status")}
                    value={f.status}
                    disabled={busy}
                    className="w-auto"
                    onChange={(e) =>
                      void run(async () => {
                        const { error } = await supabase()
                          .from("feedback")
                          .update({ status: e.target.value })
                          .eq("id", f.id);
                        if (error) throw error;
                        await load();
                      })
                    }
                  >
                    {STATUSES.map((s) => (
                      <option key={s} value={s}>
                        {t(`fs_${s}`)}
                      </option>
                    ))}
                  </Select>
                ) : (
                  <Badge tone={f.status === "new" ? "warning" : "neutral"}>{t(`fs_${f.status}`)}</Badge>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
