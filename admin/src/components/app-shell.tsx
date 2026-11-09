"use client";

import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useState } from "react";
import { LanguageToggle, Logo } from "@/components/brand";
import { Badge, Spinner } from "@/components/ui";
import { CreateChurch } from "@/components/create-church";
import { ChurchProvider, useChurch } from "@/lib/church";
import { useI18n, type MessageKey } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

const NAV: { href: string; key: MessageKey; icon: string; adminOnly?: boolean }[] = [
  { href: "/dashboard", key: "navDashboard", icon: "◧" },
  { href: "/dashboard/branding", key: "navBranding", icon: "✦", adminOnly: true },
  { href: "/dashboard/members", key: "navMembers", icon: "☺" },
  { href: "/dashboard/events", key: "navEvents", icon: "▦" },
  { href: "/dashboard/announcements", key: "navAnnouncements", icon: "✉" },
  { href: "/dashboard/checkin", key: "navCheckin", icon: "▣" },
  { href: "/dashboard/feedback", key: "navFeedback", icon: "✎", adminOnly: true },
  { href: "/dashboard/verification", key: "navVerification", icon: "✓", adminOnly: true },
];

function Shell({ children }: { children: React.ReactNode }) {
  const { t } = useI18n();
  const { ready, user, memberships, church, isAdmin, isPlatformAdmin, selectChurch } = useChurch();
  const path = usePathname();
  const router = useRouter();
  const [open, setOpen] = useState(false);

  useEffect(() => {
    if (ready && !user) router.replace(`/login?next=${encodeURIComponent(path)}`);
  }, [ready, user, path, router]);

  if (!ready || !user) return <Spinner />;

  const onPlatformPage = path.startsWith("/admin");
  const onNewChurch = path === "/dashboard/new-church";
  const needsChurch = !church && !onPlatformPage;

  const nav = (
    <nav className="flex flex-col gap-1" onClick={() => setOpen(false)}>
      {church &&
        NAV.filter((n) => !n.adminOnly || isAdmin).map((n) => {
          const active = n.href === "/dashboard" ? path === n.href : path.startsWith(n.href);
          return (
            <Link
              key={n.href}
              href={n.href}
              className={`flex min-h-10 items-center gap-3 rounded-lg px-3 text-sm ${active ? "bg-brand text-brand-fg" : "hover:bg-brand-soft"}`}
            >
              <span aria-hidden className="w-4 text-center">
                {n.icon}
              </span>
              {t(n.key)}
            </Link>
          );
        })}
      {isPlatformAdmin && (
        <Link
          href="/admin"
          className={`mt-2 flex min-h-10 items-center gap-3 rounded-lg border border-border px-3 text-sm ${onPlatformPage ? "bg-brand text-brand-fg" : "hover:bg-brand-soft"}`}
        >
          <span aria-hidden className="w-4 text-center">
            ⚙
          </span>
          {t("navPlatform")}
        </Link>
      )}
    </nav>
  );

  const switcher = (
    <div className="space-y-2">
      {memberships.length > 0 && (
        <select
          aria-label={t("switchChurch")}
          className="w-full rounded-lg border border-border bg-surface px-3 py-2 text-sm"
          value={church?.id ?? ""}
          onChange={(e) => {
            selectChurch(e.target.value);
            router.push("/dashboard");
          }}
        >
          {memberships.map((m) => (
            <option key={m.church_id} value={m.church_id}>
              {m.churches?.name}
            </option>
          ))}
        </select>
      )}
      <Link href="/dashboard/new-church" className="block text-xs text-brand hover:underline" onClick={() => setOpen(false)}>
        + {t("newChurch")}
      </Link>
    </div>
  );

  const footer = (
    <div className="space-y-3 border-t border-border pt-4">
      <div className="truncate text-xs text-muted" title={user.email ?? ""}>
        {user.email}
      </div>
      <div className="flex items-center justify-between gap-2">
        <LanguageToggle />
        <button
          type="button"
          className="text-xs text-muted hover:text-foreground"
          onClick={async () => {
            await supabase().auth.signOut();
            router.replace("/login");
          }}
        >
          {t("signOut")}
        </button>
      </div>
    </div>
  );

  return (
    <div className="min-h-screen lg:flex">
      {/* Mobile top bar */}
      <header className="sticky top-0 z-20 flex items-center justify-between border-b border-border bg-surface px-4 py-3 lg:hidden">
        <Logo small />
        <button
          type="button"
          aria-expanded={open}
          aria-label="Menu"
          className="flex h-10 w-10 items-center justify-center rounded-lg border border-border"
          onClick={() => setOpen((o) => !o)}
        >
          {open ? "✕" : "☰"}
        </button>
      </header>
      {open && (
        <div className="fixed inset-0 top-[65px] z-10 flex flex-col gap-6 overflow-y-auto bg-surface p-4 lg:hidden">
          {switcher}
          {nav}
          {footer}
        </div>
      )}

      {/* Desktop sidebar */}
      <aside className="sticky top-0 hidden h-screen w-64 shrink-0 flex-col gap-6 overflow-y-auto border-r border-border bg-surface p-4 lg:flex">
        <Logo />
        {switcher}
        <div className="flex-1">{nav}</div>
        {footer}
      </aside>

      <main className="min-w-0 flex-1 px-4 py-6 sm:px-8 lg:py-10">
        <div className="mx-auto max-w-5xl">
          {church && church.status !== "active" && !onPlatformPage && !path.startsWith("/dashboard/verification") && (
            <div className="mb-6 flex flex-col gap-2 rounded-lg border border-warning/30 bg-warning-soft px-4 py-3 text-sm sm:flex-row sm:items-center sm:justify-between">
              <span>
                <Badge tone="warning">{church.status}</Badge> {t("churchPending")}
              </span>
              {isAdmin && (
                <Link href="/dashboard/verification" className="font-medium text-brand underline">
                  {t("completeVerification")}
                </Link>
              )}
            </div>
          )}
          {needsChurch || onNewChurch ? <CreateChurch /> : children}
        </div>
      </main>
    </div>
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <ChurchProvider>
      <Shell>{children}</Shell>
    </ChurchProvider>
  );
}
