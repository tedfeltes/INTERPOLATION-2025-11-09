import { promises as fs } from "node:fs";
import path from "node:path";
import { buildAudioChain, buildDetectChain, buildFilterChain } from "./pipeline";
import { extractPreviewFrame, probe, runFfmpeg } from "./ffmpeg";
import { findInputFile, jobDir, writeStatus } from "./jobs";
import type { EnhanceOptions, TextBox } from "./types";

/**
 * Kick off processing for a job. Fire-and-forget from the API route; status is
 * tracked via the on-disk status.json.
 */
export async function runJob(
  jobId: string,
  options: EnhanceOptions,
  textBoxes: TextBox[],
): Promise<void> {
  const dir = jobDir(jobId);
  const input = await findInputFile(jobId);
  if (!input) throw new Error("job has no input file");

  try {
    await writeStatus(jobId, { state: "probing" });
    const info = await probe(input);

    const { filterChain, twoPassStabilize } = buildFilterChain(options, textBoxes, info);
    const audioChain = buildAudioChain(options);

    // 1. Optional stabilization pre-pass. vidstabdetect writes transforms.trf
    //    into the job dir; we run ffmpeg with cwd=jobDir so it lands there.
    if (twoPassStabilize) {
      const detect = buildDetectChain(options);
      await writeStatus(jobId, {
        state: "processing",
        progressPct: 0,
        stage: "Analyzing motion (stabilize pass 1/2)",
      });
      await runFfmpeg(
        [
          "-y",
          "-i",
          input,
          "-vf",
          detect,
          "-f",
          "null",
          "-",
        ],
        info.durationSec,
        (pct) =>
          writeStatus(jobId, {
            state: "processing",
            progressPct: pct * 0.35,
            stage: "Analyzing motion (stabilize pass 1/2)",
          }).catch(() => {}),
        dir,
      );
    }

    // 2. Main pass: encode with the full filter chain.
    const outputPath = path.join(dir, "output.mp4");
    const args: string[] = ["-y", "-i", input, "-vf", filterChain];
    if (info.hasAudio && audioChain) {
      args.push("-af", audioChain, "-c:a", "aac", "-b:a", "192k");
    } else if (info.hasAudio) {
      args.push("-c:a", "copy");
    } else {
      args.push("-an");
    }
    args.push(
      "-c:v",
      "libx264",
      "-preset",
      "medium",
      "-crf",
      String(options.crf),
      "-pix_fmt",
      "yuv420p",
      "-movflags",
      "+faststart",
      outputPath,
    );

    const startOffset = twoPassStabilize ? 35 : 0;
    const scale = twoPassStabilize ? 0.65 : 1;
    await writeStatus(jobId, {
      state: "processing",
      progressPct: startOffset,
      stage: twoPassStabilize ? "Enhancing (stabilize pass 2/2)" : "Enhancing",
    });
    const t0 = Date.now();
    await runFfmpeg(
      args,
      info.durationSec,
      (pct) =>
        writeStatus(jobId, {
          state: "processing",
          progressPct: startOffset + pct * scale,
          stage: twoPassStabilize ? "Enhancing (stabilize pass 2/2)" : "Enhancing",
        }).catch(() => {}),
      dir,
    );
    const elapsed = (Date.now() - t0) / 1000;

    await writeStatus(jobId, {
      state: "done",
      outputRelPath: `/api/download/${jobId}`,
      durationSec: elapsed,
    });
  } catch (err) {
    await writeStatus(jobId, {
      state: "error",
      message: (err as Error).message,
    });
  }
}

/**
 * Prep a job for text-box selection: extract a preview frame + probe metadata.
 * Idempotent — safe to call again if the user re-uploads.
 */
export async function prepareJob(jobId: string): Promise<{
  previewRelPath: string;
  width: number;
  height: number;
  durationSec: number;
  hasAudio: boolean;
}> {
  const input = await findInputFile(jobId);
  if (!input) throw new Error("job has no input file");
  const info = await probe(input);
  const dir = jobDir(jobId);
  const preview = path.join(dir, "preview.jpg");
  await extractPreviewFrame(input, preview, info.durationSec);
  // Sanity-check the preview exists before returning.
  await fs.access(preview);
  return {
    previewRelPath: `/api/preview/${jobId}`,
    width: info.width,
    height: info.height,
    durationSec: info.durationSec,
    hasAudio: info.hasAudio,
  };
}
