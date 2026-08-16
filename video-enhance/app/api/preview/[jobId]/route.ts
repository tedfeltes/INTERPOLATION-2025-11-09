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
    const file = path.join(jobDir(jobId), "preview.jpg");
    const buf = await fs.readFile(file);
    return new NextResponse(new Uint8Array(buf), {
      headers: {
        "content-type": "image/jpeg",
        "cache-control": "no-store",
      },
    });
  } catch {
    return NextResponse.json({ error: "not found" }, { status: 404 });
  }
}
