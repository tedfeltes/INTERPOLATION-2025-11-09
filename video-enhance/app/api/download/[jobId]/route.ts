import { NextResponse } from "next/server";
import { promises as fs } from "node:fs";
import path from "node:path";
import { jobDir } from "@/lib/jobs";

export const runtime = "nodejs";

export async function GET(
  _req: Request,
  ctx: { params: Promise<{ jobId: string }> },
) {
  const { jobId } = await ctx.params;
  try {
    const file = path.join(jobDir(jobId), "output.mp4");
    const buf = await fs.readFile(file);
    return new NextResponse(new Uint8Array(buf), {
      headers: {
        "content-type": "video/mp4",
        "content-disposition": `attachment; filename="enhanced-${jobId}.mp4"`,
        "cache-control": "no-store",
      },
    });
  } catch {
    return NextResponse.json({ error: "not found" }, { status: 404 });
  }
}
