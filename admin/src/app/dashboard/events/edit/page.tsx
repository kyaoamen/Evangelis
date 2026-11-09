"use client";

import { Suspense, useEffect, useState } from "react";
import { useSearchParams } from "next/navigation";
import { EventForm } from "@/components/event-form";
import { Empty, PageHeader, Spinner } from "@/components/ui";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";
import type { ChurchEvent } from "@/lib/types";

function EditInner() {
  const { t } = useI18n();
  const id = useSearchParams().get("id");
  const [event, setEvent] = useState<ChurchEvent | null | undefined>(undefined);

  useEffect(() => {
    if (!id) return;
    void supabase()
      .from("events")
      .select("*")
      .eq("id", id)
      .maybeSingle()
      .then(({ data }) => setEvent((data as ChurchEvent) ?? null));
  }, [id]);

  if (!id || event === null) return <Empty />;
  if (event === undefined) return <Spinner />;
  return (
    <div>
      <PageHeader title={t("editEvent")} />
      <EventForm event={event} />
    </div>
  );
}

export default function EditEventPage() {
  return (
    <Suspense fallback={<Spinner />}>
      <EditInner />
    </Suspense>
  );
}
