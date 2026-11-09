"use client";

import { useCallback, useEffect, useState } from "react";
import { Alert, Badge, Button, Card, Feedback, PageHeader, Spinner, useAction } from "@/components/ui";
import { useChurch, useCurrentChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";
import { DOCS_BUCKET, supabase, uploadFile } from "@/lib/supabase";
import { DOCUMENT_TYPES, type ChurchDocument, type DocumentType } from "@/lib/types";

export default function VerificationPage() {
  const { t, fmtDate } = useI18n();
  const church = useCurrentChurch();
  const { reload, isAdmin } = useChurch();
  const [docs, setDocs] = useState<ChurchDocument[] | null>(null);
  const { busy, error, notice, run } = useAction();

  const load = useCallback(async () => {
    const { data } = await supabase().from("church_documents").select("*").eq("church_id", church.id);
    setDocs((data ?? []) as ChurchDocument[]);
  }, [church.id]);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- data fetch
    void load();
  }, [load]);

  if (!isAdmin) return <Alert tone="warning">{t("errorGeneric")}</Alert>;
  if (!docs) return <Spinner />;

  const active = church.status === "active";
  const byType = new Map(docs.map((d) => [d.type, d]));
  const complete = DOCUMENT_TYPES.every((ty) => byType.has(ty) && byType.get(ty)!.status !== "rejected");

  async function upload(type: DocumentType, file: File) {
    await run(async () => {
      const path = await uploadFile(DOCS_BUCKET, church.id, type, file);
      const { error } = await supabase()
        .from("church_documents")
        .upsert(
          { church_id: church.id, type, storage_path: path, file_name: file.name, status: "submitted", review_note: null },
          { onConflict: "church_id,type" },
        );
      if (error) throw error;
      await load();
    });
  }

  async function view(doc: ChurchDocument) {
    const { data } = await supabase().storage.from(DOCS_BUCKET).createSignedUrl(doc.storage_path, 300);
    if (data?.signedUrl) window.open(data.signedUrl, "_blank", "noopener");
  }

  return (
    <div>
      <PageHeader title={t("verificationTitle")} subtitle={t("verificationBody")} />
      <div className="space-y-4">
        {active && <Alert tone="success">{t("churchActive")}</Alert>}
        {church.review_note && !active && (
          <Alert tone="danger">
            <strong>{t("reviewNote")} :</strong> {church.review_note}
          </Alert>
        )}
        {church.submitted_for_review_at && !active && (
          <Alert tone="brand">
            {t("underReview")} {fmtDate(church.submitted_for_review_at)}
          </Alert>
        )}

        <Card className="divide-y divide-border p-0 sm:p-0">
          {DOCUMENT_TYPES.map((type) => {
            const doc = byType.get(type);
            const tone = doc?.status === "accepted" ? "success" : doc?.status === "rejected" ? "danger" : "brand";
            return (
              <div key={type} className="flex flex-col gap-3 p-4 sm:flex-row sm:items-center sm:justify-between">
                <div className="min-w-0">
                  <div className="font-medium">{t(`doc_${type}`)}</div>
                  {doc && (
                    <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-muted">
                      <Badge tone={tone}>{t(doc.status)}</Badge>
                      <span className="truncate">{doc.file_name}</span>
                    </div>
                  )}
                  {doc?.review_note && <div className="mt-1 text-xs text-danger">{doc.review_note}</div>}
                </div>
                <div className="flex gap-2">
                  {doc && (
                    <Button variant="secondary" onClick={() => void view(doc)}>
                      {t("view")}
                    </Button>
                  )}
                  {!active && (
                    <label className={`inline-flex min-h-10 cursor-pointer items-center rounded-lg px-4 text-sm font-medium ${doc ? "border border-border hover:bg-brand-soft" : "bg-brand text-brand-fg"} ${busy ? "pointer-events-none opacity-50" : ""}`}>
                      {doc ? t("replace") : t("upload")}
                      <input
                        type="file"
                        accept="application/pdf,image/*"
                        className="sr-only"
                        onChange={(e) => {
                          const f = e.target.files?.[0];
                          if (f) void upload(type, f);
                          e.target.value = "";
                        }}
                      />
                    </label>
                  )}
                </div>
              </div>
            );
          })}
        </Card>

        <Feedback error={error} notice={notice} />
        {!active && (
          <Button
            disabled={!complete || busy}
            onClick={() =>
              void run(async () => {
                const { error } = await supabase().rpc("submit_church_for_review", { p_church: church.id });
                if (error) throw error;
                await reload();
              }, t("saved"))
            }
          >
            {t("submitForReview")}
          </Button>
        )}
      </div>
    </div>
  );
}
