import { NextResponse } from "next/server";
import { readStatus } from "@/lib/jobs";

export const runtime = "nodejs";

export async function GET(
  _req: Request,
  ctx: { params: Promise<{ jobId: string }> },
) {
  const { jobId } = await ctx.params;
  const status = await readStatus(jobId);
  if (!status) return NextResponse.json({ error: "not found" }, { status: 404 });
  return NextResponse.json(status);
}
