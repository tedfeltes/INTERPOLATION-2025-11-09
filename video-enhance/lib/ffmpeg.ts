import { spawn } from "node:child_process";
import { promises as fs } from "node:fs";
import path from "node:path";
import type { ProbeResult } from "./types";

/**
 * Probe a video file's basic metadata via ffprobe.
 */
export async function probe(inputPath: string): Promise<ProbeResult> {
  const args = [
    "-v",
    "error",
    "-print_format",
    "json",
    "-show_streams",
    "-show_format",
    inputPath,
  ];
  const { stdout } = await runCollect("ffprobe", args);
  const parsed = JSON.parse(stdout) as {
    streams: Array<{
      codec_type: string;
      width?: number;
      height?: number;
      avg_frame_rate?: string;
      r_frame_rate?: string;
    }>;
    format: { duration?: string };
  };

  const video = parsed.streams.find((s) => s.codec_type === "video");
  const audio = parsed.streams.find((s) => s.codec_type === "audio");
  if (!video || !video.width || !video.height) {
    throw new Error("No video stream in file");
  }
  const fpsRaw = video.avg_frame_rate ?? video.r_frame_rate ?? "0/1";
  const [num, den] = fpsRaw.split("/").map(Number);
  const fps = den ? num / den : 0;

  return {
    width: video.width,
    height: video.height,
    durationSec: parsed.format.duration ? Number(parsed.format.duration) : 0,
    fps: Number.isFinite(fps) ? fps : 0,
    hasAudio: Boolean(audio),
  };
}

/**
 * Extract a single still frame at ~10% of the duration into a JPEG, used as
 * the preview the user paints text-removal boxes onto.
 */
export async function extractPreviewFrame(
  inputPath: string,
  outPath: string,
  durationSec: number,
): Promise<void> {
  const at = Math.max(0.2, durationSec * 0.1);
  await runOrThrow("ffmpeg", [
    "-y",
    "-ss",
    String(at),
    "-i",
    inputPath,
    "-frames:v",
    "1",
    "-q:v",
    "3",
    outPath,
  ]);
}

/**
 * Run ffmpeg with a full command line, reporting progress percentage via a
 * callback based on the current out_time_ms vs the total duration.
 */
export async function runFfmpeg(
  args: string[],
  totalDurationSec: number,
  onProgress: (pct: number) => void,
  cwd?: string,
): Promise<void> {
  await new Promise<void>((resolve, reject) => {
    const child = spawn("ffmpeg", ["-hide_banner", "-nostats", "-progress", "pipe:1", ...args], {
      cwd,
    });
    let stderrTail = "";
    child.stdout.on("data", (chunk: Buffer) => {
      const text = chunk.toString("utf8");
      for (const line of text.split("\n")) {
        const m = line.match(/^out_time_ms=(\d+)/);
        if (m && totalDurationSec > 0) {
          const outSec = Number(m[1]) / 1_000_000;
          const pct = Math.max(0, Math.min(99, (outSec / totalDurationSec) * 100));
          onProgress(pct);
        }
      }
    });
    child.stderr.on("data", (chunk: Buffer) => {
      stderrTail = (stderrTail + chunk.toString("utf8")).slice(-4000);
    });
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`ffmpeg exited ${code}: ${stderrTail}`));
    });
  });
}

/**
 * Small helper: run a command and collect its stdout as a string.
 */
async function runCollect(
  cmd: string,
  args: string[],
): Promise<{ stdout: string; stderr: string }> {
  return await new Promise((resolve, reject) => {
    const child = spawn(cmd, args);
    let out = "";
    let err = "";
    child.stdout.on("data", (d: Buffer) => (out += d.toString("utf8")));
    child.stderr.on("data", (d: Buffer) => (err += d.toString("utf8")));
    child.on("error", reject);
    child.on("close", (code) => {
      if (code === 0) resolve({ stdout: out, stderr: err });
      else reject(new Error(`${cmd} exited ${code}: ${err}`));
    });
  });
}

async function runOrThrow(cmd: string, args: string[]): Promise<void> {
  const { stderr } = await runCollect(cmd, args);
  // runCollect already throws on non-zero exit; nothing else to do here.
  void stderr;
}

export async function fileExists(p: string): Promise<boolean> {
  try {
    await fs.access(p);
    return true;
  } catch {
    return false;
  }
}

export function jobPath(jobDir: string, name: string): string {
  return path.join(jobDir, name);
}
