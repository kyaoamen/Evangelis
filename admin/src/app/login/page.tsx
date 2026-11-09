"use client";

import { Suspense, useState } from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { LanguageToggle, Logo } from "@/components/brand";
import { Button, Card, Feedback, Field, Input, useAction } from "@/components/ui";
import { useI18n } from "@/lib/i18n";
import { supabase } from "@/lib/supabase";

function LoginForm() {
  const { t } = useI18n();
  const router = useRouter();
  const params = useSearchParams();
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [sent, setSent] = useState(false);
  const { busy, error, notice, run } = useAction();

  const next = params.get("next");
  const target = next && next.startsWith("/") && !next.startsWith("//") ? next : "/dashboard";

  return (
    <Card>
      <h1 className="text-xl font-semibold">{t("signIn")}</h1>
      <p className="mt-1 text-sm text-muted">{t("signInSubtitle")}</p>
      {!sent ? (
        <form
          className="mt-6 space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              const { error } = await supabase().auth.signInWithOtp({
                email: email.trim(),
                options: { shouldCreateUser: true },
              });
              if (error) throw error;
              setSent(true);
            });
          }}
        >
          <Field label={t("email")}>
            <Input type="email" required autoComplete="email" value={email} onChange={(e) => setEmail(e.target.value)} />
          </Field>
          <Feedback error={error} notice={notice} />
          <Button type="submit" disabled={busy} className="w-full">
            {t("sendCode")}
          </Button>
        </form>
      ) : (
        <form
          className="mt-6 space-y-4"
          onSubmit={(e) => {
            e.preventDefault();
            void run(async () => {
              const { error } = await supabase().auth.verifyOtp({ email: email.trim(), token: code.trim(), type: "email" });
              if (error) throw error;
              router.replace(target);
              router.refresh();
            });
          }}
        >
          <p className="text-sm">
            {t("codeSent")} <strong>{email}</strong>
          </p>
          <Field label={t("code")}>
            <Input
              inputMode="numeric"
              autoComplete="one-time-code"
              pattern="[0-9]{6,10}"
              required
              value={code}
              onChange={(e) => setCode(e.target.value)}
            />
          </Field>
          <Feedback error={error} notice={notice} />
          <Button type="submit" disabled={busy} className="w-full">
            {t("verify")}
          </Button>
          <Button variant="ghost" className="w-full" onClick={() => setSent(false)}>
            {t("changeEmail")}
          </Button>
        </form>
      )}
    </Card>
  );
}

export default function LoginPage() {
  const { t } = useI18n();
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center gap-6 px-4 py-10">
      <div className="flex items-center justify-between">
        <Logo />
        <LanguageToggle />
      </div>
      <Suspense fallback={<p className="text-sm text-muted">{t("loading")}</p>}>
        <LoginForm />
      </Suspense>
      <p className="text-center text-xs text-muted">{t("tagline")}</p>
    </main>
  );
}
