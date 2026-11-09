"use client";

import { EventForm } from "@/components/event-form";
import { PageHeader } from "@/components/ui";
import { useI18n } from "@/lib/i18n";

export default function NewEventPage() {
  const { t } = useI18n();
  return (
    <div>
      <PageHeader title={t("newEvent")} />
      <EventForm />
    </div>
  );
}
