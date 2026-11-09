"use client";

import { useEffect, useRef, useState } from "react";
import type { IScannerControls } from "@zxing/browser";
import { Alert, Button, Card, Field, Input, PageHeader } from "@/components/ui";
import { useI18n } from "@/lib/i18n";
import { errorMessage, supabase } from "@/lib/supabase";

interface CheckInResult {
  registration_id: string;
  seats: number;
  first_name: string | null;
  last_name: string | null;
  already_checked_in: boolean;
}

export default function CheckinPage() {
  const { t } = useI18n();
  const videoRef = useRef<HTMLVideoElement>(null);
  const controls = useRef<IScannerControls | null>(null);
  const lastScan = useRef<{ code: string; at: number } | null>(null);
  const [scanning, setScanning] = useState(false);
  const [code, setCode] = useState("");
  const [result, setResult] = useState<CheckInResult | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function checkIn(token: string) {
    const clean = token.trim();
    if (!clean) return;
    setBusy(true);
    setError(null);
    setResult(null);
    try {
      const { data, error } = await supabase().rpc("check_in", { p_qr_token: clean });
      if (error) throw error;
      const row = (data as CheckInResult[])[0];
      setResult(row ?? null);
      setCode("");
      if (navigator.vibrate) navigator.vibrate(row?.already_checked_in ? [80, 60, 80] : 60);
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  }

  async function startCamera() {
    setError(null);
    try {
      const { BrowserQRCodeReader } = await import("@zxing/browser");
      const reader = new BrowserQRCodeReader();
      controls.current = await reader.decodeFromVideoDevice(undefined, videoRef.current!, (res) => {
        if (!res) return;
        const text = res.getText();
        const now = Date.now();
        // Ignore the same code seen again within 4 seconds.
        if (lastScan.current && lastScan.current.code === text && now - lastScan.current.at < 4000) return;
        lastScan.current = { code: text, at: now };
        void checkIn(text);
      });
      setScanning(true);
    } catch {
      setError(t("cameraError"));
    }
  }

  function stopCamera() {
    controls.current?.stop();
    controls.current = null;
    setScanning(false);
  }

  useEffect(() => () => controls.current?.stop(), []);

  const fullName = result ? [result.first_name, result.last_name].filter(Boolean).join(" ") || "—" : "";

  return (
    <div className="mx-auto max-w-xl space-y-6">
      <PageHeader title={t("checkinTitle")} subtitle={t("checkinBody")} />

      {result && (
        <Alert tone={result.already_checked_in ? "warning" : "success"}>
          <div className="text-lg font-semibold">
            {result.already_checked_in ? "⚠" : "✓"} {t("welcome")}, {fullName}
          </div>
          <div>
            {t("seats")}: {result.seats}
          </div>
          {result.already_checked_in && <div className="mt-1 font-medium">{t("alreadyCheckedIn")}</div>}
        </Alert>
      )}
      {error && <Alert tone="danger">{error}</Alert>}

      <Card className="space-y-4">
        <div className={`overflow-hidden rounded-lg bg-black ${scanning ? "" : "hidden"}`}>
          <video ref={videoRef} className="aspect-square w-full object-cover" muted playsInline />
        </div>
        {scanning ? (
          <Button variant="secondary" className="w-full" onClick={stopCamera}>
            {t("stopCamera")}
          </Button>
        ) : (
          <Button className="w-full" onClick={() => void startCamera()}>
            {t("startCamera")}
          </Button>
        )}
      </Card>

      <Card>
        <form
          className="flex flex-col gap-3 sm:flex-row sm:items-end"
          onSubmit={(e) => {
            e.preventDefault();
            void checkIn(code);
          }}
        >
          <Field label={t("manualCode")} className="flex-1">
            <Input value={code} onChange={(e) => setCode(e.target.value)} autoCapitalize="off" autoCorrect="off" spellCheck={false} />
          </Field>
          <Button type="submit" disabled={busy || !code.trim()}>
            {t("checkIn")}
          </Button>
        </form>
      </Card>
    </div>
  );
}
