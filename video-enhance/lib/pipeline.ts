import type { EnhanceOptions, ProbeResult, TextBox } from "./types";

/**
 * Build the ffmpeg -vf filter chain from a set of enhancement options
 * and user-drawn text-removal boxes.
 *
 * Returns an object with:
 *   filterChain: string suitable for -vf
 *   twoPassStabilize: whether the caller needs to run a vidstabdetect prepass
 */
export function buildFilterChain(
  options: EnhanceOptions,
  textBoxes: TextBox[],
  probe: ProbeResult,
): { filterChain: string; twoPassStabilize: boolean } {
  const filters: string[] = [];

  // 1. Text/logo removal is applied FIRST, on the source resolution, so the
  //    normalized box coordinates map cleanly to pixels.
  for (const box of textBoxes) {
    const x = Math.max(0, Math.round(box.x * probe.width));
    const y = Math.max(0, Math.round(box.y * probe.height));
    const w = Math.max(4, Math.round(box.w * probe.width));
    const h = Math.max(4, Math.round(box.h * probe.height));
    // delogo inpaints from surrounding pixels; good for burned-in captions
    // and small watermarks. show=0 keeps the fill in the final render.
    filters.push(`delogo=x=${x}:y=${y}:w=${w}:h=${h}:show=0`);
  }

  // 2. Denoise (high-quality 3D denoiser). Mild defaults.
  if (options.denoise) {
    filters.push("hqdn3d=luma_spatial=3:chroma_spatial=2:luma_tmp=4:chroma_tmp=3");
  }

  // 3. Stabilize (2-pass vidstab). We only emit the transform pass here;
  //    the caller is responsible for running vidstabdetect first.
  let twoPassStabilize = false;
  if (options.stabilize !== "off") {
    twoPassStabilize = true;
    const smoothing = options.stabilize === "strong" ? 30 : 15;
    filters.push(
      `vidstabtransform=input=transforms.trf:zoom=0:smoothing=${smoothing}:interpol=bicubic`,
    );
    // A tiny unsharp after stabilize compensates for interpolation softness.
    filters.push("unsharp=5:5:0.4:5:5:0.0");
  }

  // 4. Color grade (brightness/contrast/saturation).
  if (options.colorGrade) {
    const b = clamp(options.brightness, -1, 1);
    const c = clamp(options.contrast, 0.1, 3);
    const s = clamp(options.saturation, 0, 3);
    filters.push(`eq=brightness=${b}:contrast=${c}:saturation=${s}`);
  }

  // 5. Sharpen (kept subtle to avoid ringing).
  if (options.sharpen) {
    filters.push("unsharp=5:5:0.8:5:5:0.0");
  }

  // 6. Upscale last, so denoise/sharpen operate on the smaller frame (faster,
  //    better results).
  const scale = upscaleFilter(options.upscale, probe);
  if (scale) filters.push(scale);

  // Always ensure yuv420p at the end so the result plays everywhere.
  filters.push("format=yuv420p");

  return {
    filterChain: filters.join(","),
    twoPassStabilize,
  };
}

/**
 * Filter chain used *only* for the vidstabdetect prepass.
 * We keep it minimal so detection sees the untransformed frame.
 */
export function buildDetectChain(options: EnhanceOptions): string {
  if (options.stabilize === "off") return "";
  const shakiness = options.stabilize === "strong" ? 8 : 5;
  const accuracy = options.stabilize === "strong" ? 15 : 9;
  return `vidstabdetect=shakiness=${shakiness}:accuracy=${accuracy}:result=transforms.trf`;
}

function upscaleFilter(
  target: EnhanceOptions["upscale"],
  probe: ProbeResult,
): string | null {
  switch (target) {
    case "none":
      return null;
    case "1.5x":
      return `scale=iw*1.5:ih*1.5:flags=lanczos`;
    case "2x":
      return `scale=iw*2:ih*2:flags=lanczos`;
    case "4k": {
      // Fit within 3840x2160 while preserving aspect ratio; only upscale, never down.
      if (probe.width >= 3840 || probe.height >= 2160) return null;
      return `scale='min(3840,iw*3840/iw)':'-2':flags=lanczos`;
    }
  }
}

function clamp(v: number, lo: number, hi: number): number {
  return Math.max(lo, Math.min(hi, v));
}

/**
 * Compose the audio filter chain. Kept separate from the video chain so the
 * runner can pass -af or -an cleanly.
 */
export function buildAudioChain(options: EnhanceOptions): string | null {
  if (!options.audioClean) return null;
  // High-pass removes rumble; loudnorm normalizes perceived loudness.
  return "highpass=f=80,loudnorm=I=-16:TP=-1.5:LRA=11";
}
