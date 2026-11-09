"use client";

import { createContext, useCallback, useContext, useEffect, useMemo, useState } from "react";
import type { User } from "@supabase/supabase-js";
import { supabase } from "./supabase";
import { ADMIN_ROLES, STAFF_ROLES, type Church, type Role, type StaffMembership } from "./types";

interface ChurchCtx {
  ready: boolean;
  user: User | null;
  memberships: StaffMembership[];
  church: Church | null;
  role: Role | null;
  isAdmin: boolean; // owner/admin of the current church
  isPlatformAdmin: boolean;
  selectChurch: (id: string) => void;
  reload: () => Promise<void>;
}

const Ctx = createContext<ChurchCtx | null>(null);
const KEY = "current_church_id";

export function ChurchProvider({ children }: { children: React.ReactNode }) {
  const [ready, setReady] = useState(false);
  const [user, setUser] = useState<User | null>(null);
  const [memberships, setMemberships] = useState<StaffMembership[]>([]);
  const [currentId, setCurrentId] = useState<string | null>(null);
  const [isPlatformAdmin, setPlatformAdmin] = useState(false);

  const reload = useCallback(async () => {
    const db = supabase();
    const { data: auth } = await db.auth.getUser();
    setUser(auth.user);
    if (!auth.user) {
      setMemberships([]);
      setReady(true);
      return;
    }
    const [ms, pa] = await Promise.all([
      db
        .from("memberships")
        .select("id, church_id, role, status, churches(*)")
        .eq("user_id", auth.user.id)
        .eq("status", "active")
        .in("role", STAFF_ROLES),
      db.from("platform_admins").select("user_id").eq("user_id", auth.user.id).maybeSingle(),
    ]);
    const list = ((ms.data ?? []) as unknown as StaffMembership[]).sort((a, b) =>
      (a.churches?.name ?? "").localeCompare(b.churches?.name ?? ""),
    );
    setMemberships(list);
    setPlatformAdmin(!!pa.data);
    let saved: string | null = null;
    try {
      saved = localStorage.getItem(KEY);
    } catch {}
    setCurrentId((prev) => {
      const wanted = prev ?? saved;
      return list.some((m) => m.church_id === wanted) ? wanted : (list[0]?.church_id ?? null);
    });
    setReady(true);
  }, []);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- initial load from Supabase
    void reload();
    const { data } = supabase().auth.onAuthStateChange((event) => {
      if (event === "SIGNED_IN" || event === "SIGNED_OUT") void reload();
    });
    return () => data.subscription.unsubscribe();
  }, [reload]);

  const selectChurch = useCallback((id: string) => {
    setCurrentId(id);
    try {
      localStorage.setItem(KEY, id);
    } catch {}
  }, []);

  const value = useMemo<ChurchCtx>(() => {
    const m = memberships.find((x) => x.church_id === currentId) ?? null;
    return {
      ready,
      user,
      memberships,
      church: m?.churches ?? null,
      role: m?.role ?? null,
      isAdmin: !!m && ADMIN_ROLES.includes(m.role),
      isPlatformAdmin,
      selectChurch,
      reload,
    };
  }, [ready, user, memberships, currentId, isPlatformAdmin, selectChurch, reload]);

  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useChurch(): ChurchCtx {
  const ctx = useContext(Ctx);
  if (!ctx) throw new Error("useChurch outside ChurchProvider");
  return ctx;
}

/** The current church, asserted present (pages under the shell only render with one). */
export function useCurrentChurch(): Church {
  const { church } = useChurch();
  if (!church) throw new Error("no current church");
  return church;
}
