"use client";

import { useI18n } from "@/lib/i18n";

export function Logo({ small = false }: { small?: boolean }) {
  const { t } = useI18n();
  return (
    <div className="flex items-center gap-2">
      <span
        aria-hidden
        className={`flex items-center justify-center rounded-lg bg-brand font-bold text-brand-fg ${small ? "h-8 w-8 text-sm" : "h-10 w-10"}`}
      >
        E
      </span>
      <div className="leading-tight">
        <div className={`font-semibold ${small ? "text-sm" : "text-base"}`}>{t("appName")}</div>
        <div className="text-xs text-muted">{t("backOffice")}</div>
      </div>
    </div>
  );
}

export function LanguageToggle() {
  const { locale, setLocale } = useI18n();
  return (
    <div className="inline-flex overflow-hidden rounded-lg border border-border text-xs font-medium" role="group" aria-label="Language">
      {(["fr", "en"] as const).map((l) => (
        <button
          key={l}
          type="button"
          onClick={() => setLocale(l)}
          aria-pressed={locale === l}
          className={`px-3 py-1.5 ${locale === l ? "bg-brand text-brand-fg" : "bg-surface hover:bg-brand-soft"}`}
        >
          {l.toUpperCase()}
        </button>
      ))}
    </div>
  );
}
