"use client";

import { LanguageToggle, Logo } from "@/components/brand";
import { Card } from "@/components/ui";
import { useI18n } from "@/lib/i18n";

export default function SetupPage() {
  const { t } = useI18n();
  return (
    <main className="mx-auto flex min-h-screen max-w-2xl flex-col gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <Logo />
        <LanguageToggle />
      </div>
      <Card>
        <h1 className="text-xl font-semibold">{t("setupTitle")}</h1>
        <p className="mt-2 text-sm text-muted">{t("setupBody")}</p>
        <ol className="mt-6 list-decimal space-y-3 pl-5 text-sm">
          <li>{t("setupStep1")}</li>
          <li>{t("setupStep2")}</li>
          <li>
            {t("setupStep3")}
            <pre className="mt-2 overflow-x-auto rounded-lg bg-background p-3 text-xs">
              {`NEXT_PUBLIC_SUPABASE_URL=https://xxxx.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=...`}
            </pre>
          </li>
        </ol>
      </Card>
    </main>
  );
}
