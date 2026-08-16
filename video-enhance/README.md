# Video Enhance (local)

A small Next.js app that runs on your own machine and enhances a video with
`ffmpeg`. Nothing is uploaded anywhere — the source clip is read from the
browser to a Node process on `localhost`, processed on disk, and streamed back
for download.

## What it does

- Denoise (`hqdn3d`)
- Sharpen (`unsharp`)
- Stabilize (`vidstab` 2-pass)
- Auto color grade (`eq` brightness/contrast/saturation)
- Upscale to 1.5×, 2×, or fit to 4K (lanczos)
- Optional audio clean-up (`highpass` + `loudnorm`)
- On-screen text / watermark removal via user-drawn boxes (`delogo` inpaint)

## What it does *not* do

- Body / anatomy reshaping. The app is intentionally scoped to
  non-anatomical, non-sexualized enhancement of your own footage.

## Requirements

- Node 20+ and npm
- `ffmpeg` 5+ on your `$PATH`, built with `libx264`, `libvidstab`, and the
  `delogo` / `hqdn3d` / `unsharp` / `eq` filters (the stock Ubuntu 24.04
  and Homebrew builds are fine)

## Run

```bash
cd video-enhance
npm install
npm run dev
# open http://localhost:3939
```

## How it's laid out

```
app/                  Next.js App Router pages + API routes
  api/upload          Accepts a file, extracts a preview frame
  api/process         Kicks off the ffmpeg pipeline for a job
  api/status/[id]     Polled by the client for progress
  api/preview/[id]    Serves the preview still (for box drawing)
  api/download/[id]   Serves the finished mp4
components/           Client-side UI
lib/pipeline.ts       Pure function: options -> ffmpeg filter chain
lib/ffmpeg.ts         Thin wrappers around ffmpeg / ffprobe
lib/runner.ts         Orchestrates the two-pass job on disk
lib/jobs.ts           Filesystem-backed job store
```

Job artifacts live under `./.jobs/<id>/` in this directory and are
gitignored. Deleting `.jobs/` clears everything.
