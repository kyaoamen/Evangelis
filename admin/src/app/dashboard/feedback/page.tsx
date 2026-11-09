"use client";

import { FeedbackList } from "@/components/feedback-list";
import { PageHeader } from "@/components/ui";
import { useChurch, useCurrentChurch } from "@/lib/church";
import { useI18n } from "@/lib/i18n";

export default function FeedbackPage() {
  const { t } = useI18n();
  const church = useCurrentChurch();
  const { isPlatformAdmin } = useChurch();
  return (
    <div>
      <PageHeader title={t("feedbackTitle")} subtitle={t("feedbackBody")} />
      <FeedbackList churchId={church.id} canTriage={isPlatformAdmin} />
    </div>
  );
}
