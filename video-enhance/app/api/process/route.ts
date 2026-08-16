import { NextRequest, NextResponse } from "next/server";
import { runJob } from "@/lib/runner";
import type { ProcessRequest } from "@/lib/types";
import { writeStatus } from "@/lib/jobs";

export const runtime = "nodejs";
// Long jobs (stabilize + upscale on a 4K clip) can take a while.
export const maxDuration = 600;

export async function POST(req: NextRequest) {
  let body: ProcessRequest;
  try {
    body = (await req.json()) as ProcessRequest;
  } catch {
    return NextResponse.json({ error: "invalid json" }, { status: 400 });
  }

  if (!body?.jobId) {
    return NextResponse.json({ error: "jobId required" }, { status: 400 });
  }

  await writeStatus(body.jobId, {
    state: "processing",
    progressPct: 0,
    stage: "Starting",
  });

  // Fire-and-forget. Client polls /api/status/[jobId].
  runJob(body.jobId, body.options, body.textBoxes ?? []).catch(() => {});
  return NextResponse.json({ jobId: body.jobId });
}
