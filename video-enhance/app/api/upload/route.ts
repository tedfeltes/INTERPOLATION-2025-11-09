import { NextRequest, NextResponse } from "next/server";
import { promises as fs } from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { ensureJobsRoot, jobDir, writeStatus } from "@/lib/jobs";
import { prepareJob } from "@/lib/runner";

export const runtime = "nodejs";
export const maxDuration = 300;

const ALLOWED_EXT = new Set([
  ".mp4",
  ".mov",
  ".m4v",
  ".webm",
  ".mkv",
  ".avi",
  ".mpg",
  ".mpeg",
]);

export async function POST(req: NextRequest) {
  try {
    await ensureJobsRoot();
    const form = await req.formData();
    const file = form.get("file");
    if (!(file instanceof File)) {
      return NextResponse.json({ error: "no file" }, { status: 400 });
    }

    const ext = path.extname(file.name).toLowerCase();
    if (!ALLOWED_EXT.has(ext)) {
      return NextResponse.json(
        { error: `unsupported extension ${ext}` },
        { status: 400 },
      );
    }

    const jobId = crypto.randomBytes(8).toString("hex");
    const dir = jobDir(jobId);
    await fs.mkdir(dir, { recursive: true });
    const inputPath = path.join(dir, `input${ext}`);
    const buf = Buffer.from(await file.arrayBuffer());
    await fs.writeFile(inputPath, buf);
    await writeStatus(jobId, { state: "pending" });

    const info = await prepareJob(jobId);
    return NextResponse.json({ jobId, ...info });
  } catch (err) {
    return NextResponse.json(
      { error: (err as Error).message },
      { status: 500 },
    );
  }
}
