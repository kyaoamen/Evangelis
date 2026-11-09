"use client";

import { useCallback, useEffect, useState } from "react";
import { FeedbackList } from "@/components/feedback-list";
import { Alert, Badge, Button, Card, Empty, Feedback, PageHeader, Spinner, useAction } from "@/components/ui";
import { useChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { DOCS_BUCKET, supabase } from "@/lib/supabase";
import type { ChurchDocument, ReviewQueueItem } from "@/lib/types";

export default function PlatformAdminPage() {
  const { t } = useI18n();
  const { isPlatformAdmin } = useChurch();
  if (!isPlatformAdmin) return <Alert tone="warning">{t("errorGeneric")}</Alert>;
  return (
    <div className="space-y-10">
      <PageHeader title={t("platformTitle")} />
      <ReviewQueue />
      <section>
        <h2 className="mb-4 text-lg font-semibold">{t("allFeedback")}</h2>
        <FeedbackList canTriage />
      </section>
    </div>
  );
}

function ReviewQueue() {
  const { t, fmtDate } = useI18n();
  const [queue, setQueue] = useState<ReviewQueueItem[] | null>(null);
  const [docs, setDocs] = useState<Map<string, ChurchDocument[]>>(new Map());
  const { busy, error, notice, run } = useAction();

  const load = useCallback(async () => {
    const db = supabase();
    const { data } = await db.from("church_review_queue").select("*").order("submitted_for_review_at");
    const items = (data ?? []) as ReviewQueueItem[];
    const { data: ds } = items.length
      ? await db
          .from("church_documents")
          .select("*")
          .in(
            "church_id",
            items.map((i) => i.id),
          )
      : { data: [] };
    const map = new Map<string, ChurchDocument[]>();
    for (const d of (ds ?? []) as ChurchDocument[]) map.set(d.church_id, [...(map.get(d.church_id) ?? []), d]);
    setDocs(map);
    setQueue(items);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  async function open(doc: ChurchDocument) {
    const { data, error } = await supabase().storage.from(DOCS_BUCKET).createSignedUrl(doc.storage_path, 300);
    if (error) return alert(error.message);
    window.open(data.signedUrl, "_blank", "noopener");
  }

  const reviewDoc = (doc: ChurchDocument, accept: boolean) =>
    run(async () => {
      const note = accept ? null : prompt(t("rejectNotePrompt"));
      if (!accept && !note) return;
      const { error } = await supabase().rpc("review_church_document", { p_document: doc.id, p_accept: accept, p_note: note });
      if (error) throw error;
      await load();
    });

  const reviewChurch = (id: string, approve: boolean) =>
    run(async () => {
      const note = approve ? null : prompt(t("rejectNotePrompt"));
      if (!approve && !note) return;
      const { error } = await supabase().rpc("review_church", { p_church: id, p_approve: approve, p_note: note });
      if (error) throw error;
      await load();
    }, t("saved"));

  return (
    <section>
      <h2 className="mb-4 text-lg font-semibold">{t("reviewQueue")}</h2>
      <Feedback error={error} notice={notice} />
      {!queue ? (
        <Spinner />
      ) : queue.length === 0 ? (
        <Empty />
      ) : (
        <div className="space-y-4">
          {queue.map((c) => (
            <Card key={c.id} className="space-y-4">
              <div className="flex flex-col gap-1 sm:flex-row sm:items-start sm:justify-between">
                <div>
                  <div className="text-lg font-semibold">{c.name}</div>
                  <div className="text-sm text-muted">
                    /c/{c.slug} · {[c.city, c.country].filter(Boolean).join(", ")}
                    {c.church_type ? ` · ${c.church_type}` : ""}
                  </div>
                  <div className="text-sm">
                    {t("owner")}: {c.owner_name?.trim() || "—"} {c.owner_email && <span className="text-muted">({c.owner_email})</span>}
                  </div>
                </div>
                <div className="text-xs text-muted">
                  {t("underReview")} {fmtDate(c.submitted_for_review_at)}
                </div>
              </div>
              <ul className="divide-y divide-border rounded-lg border border-border">
                {(docs.get(c.id) ?? []).map((d) => (
                  <li key={d.id} className="flex flex-col gap-2 px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between">
                    <div>
                      <div className="font-medium">{t(`doc_${d.type}`)}</div>
                      <div className="flex items-center gap-2 text-xs text-muted">
                        <Badge tone={d.status === "accepted" ? "success" : d.status === "rejected" ? "danger" : "brand"}>{t(d.status)}</Badge>
                        {d.file_name}
                      </div>
                    </div>
                    <div className="flex gap-2">
                      <Button variant="secondary" onClick={() => void open(d)}>
                        {t("view")}
                      </Button>
                      <Button variant="secondary" disabled={busy} onClick={() => void reviewDoc(d, true)}>
                        {t("acceptDoc")}
                      </Button>
                      <Button variant="danger" disabled={busy} onClick={() => void reviewDoc(d, false)}>
                        {t("rejectDoc")}
                      </Button>
                    </div>
                  </li>
                ))}
              </ul>
              <div className="flex flex-wrap gap-2">
                <Button disabled={busy} onClick={() => void reviewChurch(c.id, true)}>
                  {t("approveChurch")}
                </Button>
                <Button variant="danger" disabled={busy} onClick={() => void reviewChurch(c.id, false)}>
                  {t("rejectChurch")}
                </Button>
              </div>
            </Card>
          ))}
        </div>
      )}
    </section>
  );
}
