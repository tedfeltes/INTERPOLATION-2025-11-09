export type StabilizeMode = "off" | "light" | "strong";

export type UpscaleTarget = "none" | "1.5x" | "2x" | "4k";

export type EnhanceOptions = {
  upscale: UpscaleTarget;
  denoise: boolean;
  sharpen: boolean;
  colorGrade: boolean;
  stabilize: StabilizeMode;
  saturation: number; // 1.0 = neutral
  brightness: number; // 0 = neutral, -1..1
  contrast: number; // 1.0 = neutral
  audioClean: boolean; // simple high-pass + loudnorm
  crf: number; // x264 quality (lower = better, 18-24 typical)
};

export type TextBox = {
  // Coordinates are normalized (0..1) relative to the source video frame.
  x: number;
  y: number;
  w: number;
  h: number;
};

export type ProcessRequest = {
  jobId: string;
  options: EnhanceOptions;
  textBoxes: TextBox[];
};

export type JobStatus =
  | { state: "pending" }
  | { state: "probing" }
  | { state: "processing"; progressPct: number; stage: string }
  | { state: "done"; outputRelPath: string; durationSec: number }
  | { state: "error"; message: string };

export type ProbeResult = {
  width: number;
  height: number;
  durationSec: number;
  fps: number;
  hasAudio: boolean;
};

export const defaultOptions: EnhanceOptions = {
  upscale: "1.5x",
  denoise: true,
  sharpen: true,
  colorGrade: true,
  stabilize: "light",
  saturation: 1.08,
  brightness: 0.02,
  contrast: 1.05,
  audioClean: true,
  crf: 20,
};
