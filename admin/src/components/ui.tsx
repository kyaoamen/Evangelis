"use client";

import { useState } from "react";
import { useI18n } from "@/lib/i18n";
import type { I18nText } from "@/lib/types";

type Variant = "primary" | "secondary" | "danger" | "ghost";

export function Button({
  variant = "primary",
  className = "",
  ...props
}: React.ButtonHTMLAttributes<HTMLButtonElement> & { variant?: Variant }) {
  const styles: Record<Variant, string> = {
    primary: "bg-brand text-brand-fg hover:opacity-90",
    secondary: "border border-border bg-surface hover:bg-brand-soft",
    danger: "border border-danger/40 bg-surface text-danger hover:bg-danger-soft",
    ghost: "hover:bg-brand-soft",
  };
  return (
    <button
      type="button"
      {...props}
      className={`inline-flex min-h-10 items-center justify-center gap-2 rounded-lg px-4 py-2 text-sm font-medium transition disabled:cursor-not-allowed disabled:opacity-50 ${styles[variant]} ${className}`}
    />
  );
}

export function Card({ className = "", children }: { className?: string; children: React.ReactNode }) {
  return <div className={`rounded-xl border border-border bg-surface p-4 sm:p-6 ${className}`}>{children}</div>;
}

export function PageHeader({ title, subtitle, actions }: { title: string; subtitle?: string; actions?: React.ReactNode }) {
  return (
    <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
      <div>
        <h1 className="text-2xl font-semibold">{title}</h1>
        {subtitle && <p className="mt-1 text-sm text-muted">{subtitle}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2">{actions}</div>}
    </div>
  );
}

export function Field({
  label,
  help,
  children,
  className = "",
}: {
  label: string;
  help?: string;
  children: React.ReactNode;
  className?: string;
}) {
  return (
    <label className={`block ${className}`}>
      <span className="mb-1 block text-sm font-medium">{label}</span>
      {children}
      {help && <span className="mt-1 block text-xs text-muted">{help}</span>}
    </label>
  );
}

const inputBase =
  "rounded-lg border border-border bg-surface px-3 py-2 text-sm outline-none focus:border-brand focus:ring-2 focus:ring-brand/20";

/** Full width unless the caller sets its own width class. */
const cls = (extra?: string) => `${inputBase} ${/(^|\s)(sm:)?w-/.test(extra ?? "") ? "" : "w-full"} ${extra ?? ""}`;

export function Input(props: React.InputHTMLAttributes<HTMLInputElement>) {
  return <input {...props} className={cls(props.className)} />;
}

export function Textarea(props: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return <textarea rows={3} {...props} className={cls(props.className)} />;
}

export function Select(props: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return <select {...props} className={cls(props.className)} />;
}

export function Checkbox({
  label,
  checked,
  onChange,
}: {
  label: string;
  checked: boolean;
  onChange: (v: boolean) => void;
}) {
  return (
    <label className="flex min-h-10 items-center gap-2 text-sm">
      <input type="checkbox" className="h-4 w-4 accent-[var(--brand)]" checked={checked} onChange={(e) => onChange(e.target.checked)} />
      {label}
    </label>
  );
}

/** A FR + EN pair of inputs for jsonb {"fr","en"} text. */
export function I18nField({
  label,
  value,
  onChange,
  multiline = false,
  required = false,
}: {
  label: string;
  value: I18nText | null;
  onChange: (v: I18nText) => void;
  multiline?: boolean;
  required?: boolean;
}) {
  const { t } = useI18n();
  const v = value ?? {};
  const Comp = multiline ? Textarea : Input;
  return (
    <fieldset className="space-y-2">
      <legend className="mb-1 text-sm font-medium">{label}</legend>
      <div className="grid gap-2 sm:grid-cols-2">
        <div>
          <span className="mb-1 block text-xs text-muted">{t("french")}</span>
          <Comp value={v.fr ?? ""} required={required} onChange={(e) => onChange({ ...v, fr: e.target.value })} />
        </div>
        <div>
          <span className="mb-1 block text-xs text-muted">
            {t("english")} ({t("optional")})
          </span>
          <Comp value={v.en ?? ""} onChange={(e) => onChange({ ...v, en: e.target.value })} />
        </div>
      </div>
    </fieldset>
  );
}

/** Removes empty locales; returns null when nothing is left. */
export function cleanI18n(v: I18nText | null | undefined): I18nText | null {
  if (!v) return null;
  const out: I18nText = {};
  if (v.fr?.trim()) out.fr = v.fr.trim();
  if (v.en?.trim()) out.en = v.en.trim();
  return Object.keys(out).length ? out : null;
}

type Tone = "neutral" | "success" | "warning" | "danger" | "brand";
export function Badge({ tone = "neutral", children }: { tone?: Tone; children: React.ReactNode }) {
  const styles: Record<Tone, string> = {
    neutral: "bg-border/60 text-foreground",
    success: "bg-success-soft text-success",
    warning: "bg-warning-soft text-warning",
    danger: "bg-danger-soft text-danger",
    brand: "bg-brand-soft text-brand",
  };
  return <span className={`inline-flex items-center rounded-full px-2 py-0.5 text-xs font-medium ${styles[tone]}`}>{children}</span>;
}

export function Alert({ tone = "brand", children }: { tone?: Tone; children: React.ReactNode }) {
  const styles: Record<Tone, string> = {
    neutral: "border-border bg-surface",
    success: "border-success/30 bg-success-soft",
    warning: "border-warning/30 bg-warning-soft",
    danger: "border-danger/30 bg-danger-soft text-danger",
    brand: "border-brand/30 bg-brand-soft",
  };
  return <div className={`rounded-lg border px-4 py-3 text-sm ${styles[tone]}`}>{children}</div>;
}

export function Spinner() {
  const { t } = useI18n();
  return <p className="py-8 text-center text-sm text-muted">{t("loading")}</p>;
}

export function Empty() {
  const { t } = useI18n();
  return <p className="py-8 text-center text-sm text-muted">{t("none")}</p>;
}

/** Small helper for async actions with busy + error state. */
export function useAction() {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  async function run<T>(fn: () => Promise<T>, success?: string): Promise<T | undefined> {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const r = await fn();
      if (success) setNotice(success);
      return r;
    } catch (e) {
      setError(e && typeof e === "object" && "message" in e ? String((e as { message: unknown }).message) : String(e));
      return undefined;
    } finally {
      setBusy(false);
    }
  }
  return { busy, error, notice, setError, setNotice, run };
}

export function Feedback({ error, notice }: { error: string | null; notice: string | null }) {
  if (!error && !notice) return null;
  return <Alert tone={error ? "danger" : "success"}>{error ?? notice}</Alert>;
}

/** Image picker with preview. */
export function ImageInput({
  label,
  url,
  onFile,
  busy,
}: {
  label: string;
  url: string | null;
  onFile: (f: File) => void;
  busy?: boolean;
}) {
  const { t } = useI18n();
  return (
    <div>
      <span className="mb-1 block text-sm font-medium">{label}</span>
      <div className="flex items-center gap-3">
        <div className="flex h-20 w-20 shrink-0 items-center justify-center overflow-hidden rounded-lg border border-border bg-background">
          {url ? (
            // eslint-disable-next-line @next/next/no-img-element -- user-uploaded storage URL
            <img src={url} alt="" className="h-full w-full object-contain" />
          ) : (
            <span className="text-xs text-muted">—</span>
          )}
        </div>
        <label className={`inline-flex min-h-10 cursor-pointer items-center rounded-lg border border-border px-4 text-sm hover:bg-brand-soft ${busy ? "opacity-50" : ""}`}>
          {url ? t("replace") : t("upload")}
          <input
            type="file"
            accept="image/*"
            className="sr-only"
            disabled={busy}
            onChange={(e) => {
              const f = e.target.files?.[0];
              if (f) onFile(f);
              e.target.value = "";
            }}
          />
        </label>
      </div>
    </div>
  );
}

export function Table({ head, children }: { head: React.ReactNode[]; children: React.ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-xl border border-border bg-surface">
      <table className="w-full min-w-[640px] text-left text-sm">
        <thead className="border-b border-border text-xs uppercase tracking-wide text-muted">
          <tr>
            {head.map((h, i) => (
              <th key={i} className="px-4 py-3 font-medium">
                {h}
              </th>
            ))}
          </tr>
        </thead>
        <tbody className="divide-y divide-border">{children}</tbody>
      </table>
    </div>
  );
}

export function Td({ children, className = "" }: { children?: React.ReactNode; className?: string }) {
  return <td className={`px-4 py-3 align-middle ${className}`}>{children}</td>;
}

/** <input type="datetime-local"> value from an ISO string, in local time. */
export function toLocalInput(iso: string | null | undefined): string {
  if (!iso) return "";
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export function fromLocalInput(v: string): string | null {
  return v ? new Date(v).toISOString() : null;
}
