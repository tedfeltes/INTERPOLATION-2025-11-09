"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { EnhanceOptions, JobStatus, TextBox } from "@/lib/types";
import { defaultOptions } from "@/lib/types";
import { OptionsPanel } from "./options-panel";
import { TextBoxCanvas } from "./text-box-canvas";
import { ProgressBar } from "./progress-bar";

type PreparedJob = {
  jobId: string;
  previewRelPath: string;
  width: number;
  height: number;
  durationSec: number;
  hasAudio: boolean;
};

export function EnhanceStudio() {
  const [prepared, setPrepared] = useState<PreparedJob | null>(null);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState<string | null>(null);
  const [options, setOptions] = useState<EnhanceOptions>(defaultOptions);
  const [textBoxes, setTextBoxes] = useState<TextBox[]>([]);
  const [status, setStatus] = useState<JobStatus | null>(null);
  const [running, setRunning] = useState(false);
  const pollRef = useRef<number | null>(null);

  const onUpload = useCallback(async (file: File) => {
    setUploading(true);
    setUploadError(null);
    setStatus(null);
    setTextBoxes([]);
    setPrepared(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const res = await fetch("/api/upload", { method: "POST", body: fd });
      if (!res.ok) {
        const j = (await res.json().catch(() => ({}))) as { error?: string };
        throw new Error(j.error ?? `upload failed (${res.status})`);
      }
      const json = (await res.json()) as PreparedJob;
      setPrepared(json);
    } catch (err) {
      setUploadError((err as Error).message);
    } finally {
      setUploading(false);
    }
  }, []);

  const onStart = useCallback(async () => {
    if (!prepared) return;
    setRunning(true);
    setStatus({ state: "processing", progressPct: 0, stage: "Starting" });
    const res = await fetch("/api/process", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({
        jobId: prepared.jobId,
        options,
        textBoxes,
      }),
    });
    if (!res.ok) {
      const j = (await res.json().catch(() => ({}))) as { error?: string };
      setStatus({ state: "error", message: j.error ?? `process failed` });
      setRunning(false);
      return;
    }
    startPolling(prepared.jobId);
  }, [prepared, options, textBoxes]);

  const startPolling = useCallback((jobId: string) => {
    if (pollRef.current) window.clearInterval(pollRef.current);
    pollRef.current = window.setInterval(async () => {
      const r = await fetch(`/api/status/${jobId}`);
      if (!r.ok) return;
      const s = (await r.json()) as JobStatus;
      setStatus(s);
      if (s.state === "done" || s.state === "error") {
        if (pollRef.current) window.clearInterval(pollRef.current);
        pollRef.current = null;
        setRunning(false);
      }
    }, 700);
  }, []);

  useEffect(() => {
    return () => {
      if (pollRef.current) window.clearInterval(pollRef.current);
    };
  }, []);

  return (
    <div className="grid gap-6 lg:grid-cols-[1fr_360px]">
      <section className="card p-4">
        {!prepared ? (
          <UploadDrop
            uploading={uploading}
            error={uploadError}
            onFile={onUpload}
          />
        ) : (
          <div className="flex flex-col gap-3">
            <div className="flex items-center justify-between">
              <div className="text-sm">
                <div className="font-medium">Preview</div>
                <div className="text-muted">
                  {prepared.width}×{prepared.height} ·{" "}
                  {prepared.durationSec.toFixed(1)}s ·{" "}
                  {prepared.hasAudio ? "with audio" : "silent"}
                </div>
              </div>
              <button
                type="button"
                className="btn-ghost"
                onClick={() => {
                  setPrepared(null);
                  setStatus(null);
                  setTextBoxes([]);
                }}
              >
                New video
              </button>
            </div>
            <TextBoxCanvas
              imageSrc={prepared.previewRelPath}
              intrinsicWidth={prepared.width}
              intrinsicHeight={prepared.height}
              boxes={textBoxes}
              onChange={setTextBoxes}
            />
            <p className="text-xs text-muted">
              Drag on the frame to draw a box over any burned-in text or
              watermark you want removed. Add as many as you need. Boxes are
              inpainted from the surrounding pixels.
            </p>

            {status && (
              <div className="rounded-lg border border-border bg-elev p-3">
                {status.state === "processing" && (
                  <div className="flex flex-col gap-2">
                    <div className="flex items-center justify-between text-sm">
                      <span>{status.stage}</span>
                      <span className="tabular-nums text-muted">
                        {status.progressPct.toFixed(0)}%
                      </span>
                    </div>
                    <ProgressBar pct={status.progressPct} />
                  </div>
                )}
                {status.state === "done" && (
                  <div className="flex flex-col gap-3">
                    <div className="text-sm text-text">
                      Done in {status.durationSec.toFixed(1)}s.
                    </div>
                    <video
                      controls
                      src={status.outputRelPath}
                      className="w-full rounded-lg border border-border bg-black"
                    />
                    <a
                      href={status.outputRelPath}
                      className="btn-primary self-start"
                      download
                    >
                      Download enhanced clip
                    </a>
                  </div>
                )}
                {status.state === "error" && (
                  <div className="text-sm text-red-400">
                    Error: {status.message}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </section>

      <aside className="card p-4">
        <OptionsPanel
          value={options}
          onChange={setOptions}
          disabled={running || !prepared}
        />
        <div className="mt-4 flex flex-col gap-2">
          <button
            type="button"
            className="btn-primary w-full"
            disabled={!prepared || running}
            onClick={onStart}
          >
            {running ? "Working…" : "Enhance video"}
          </button>
          <p className="text-[11px] leading-4 text-muted">
            The pipeline runs locally via <code>ffmpeg</code>. Nothing leaves
            your machine. Text-removal boxes use <code>delogo</code> (surrounding-pixel
            inpaint), which works well for on-screen captions and small
            watermarks.
          </p>
        </div>
      </aside>
    </div>
  );
}

function UploadDrop({
  uploading,
  error,
  onFile,
}: {
  uploading: boolean;
  error: string | null;
  onFile: (f: File) => void;
}) {
  const [dragging, setDragging] = useState(false);
  return (
    <label
      className={[
        "flex h-72 cursor-pointer flex-col items-center justify-center gap-3 rounded-xl border-2 border-dashed p-6 text-center transition-colors",
        dragging
          ? "border-accent bg-accent/5"
          : "border-border hover:border-accent/60 hover:bg-elev/40",
      ].join(" ")}
      onDragOver={(e) => {
        e.preventDefault();
        setDragging(true);
      }}
      onDragLeave={() => setDragging(false)}
      onDrop={(e) => {
        e.preventDefault();
        setDragging(false);
        const f = e.dataTransfer.files?.[0];
        if (f) onFile(f);
      }}
    >
      <div className="rounded-full bg-elev p-3">
        <svg
          width="22"
          height="22"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          strokeWidth="1.8"
          strokeLinecap="round"
          strokeLinejoin="round"
          aria-hidden
        >
          <path d="M12 3v12" />
          <path d="m6 9 6-6 6 6" />
          <path d="M4 15v4a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-4" />
        </svg>
      </div>
      <div>
        <div className="font-medium">
          {uploading ? "Uploading…" : "Drop a video here or click to pick"}
        </div>
        <div className="text-xs text-muted">
          mp4, mov, m4v, webm, mkv, avi — stays on your machine
        </div>
      </div>
      {error && <div className="text-sm text-red-400">Upload error: {error}</div>}
      <input
        type="file"
        accept="video/*"
        className="hidden"
        disabled={uploading}
        onChange={(e) => {
          const f = e.target.files?.[0];
          if (f) onFile(f);
        }}
      />
    </label>
  );
}
