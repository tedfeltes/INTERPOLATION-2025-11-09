import { promises as fs } from "node:fs";
import path from "node:path";
import type { JobStatus } from "./types";

/**
 * Simple filesystem-backed job store. Each job lives at:
 *   .jobs/<jobId>/
 *     input.<ext>
 *     status.json
 *     output.mp4        (after processing)
 *     transforms.trf    (during stabilize prepass)
 *
 * A file-backed store is more than enough for a single-user local tool and
 * survives dev-server hot reloads (in-memory maps do not).
 */
const JOBS_ROOT = path.resolve(process.cwd(), ".jobs");

export async function ensureJobsRoot(): Promise<void> {
  await fs.mkdir(JOBS_ROOT, { recursive: true });
}

export function jobDir(jobId: string): string {
  if (!/^[a-z0-9-]{6,64}$/.test(jobId)) {
    throw new Error("invalid job id");
  }
  return path.join(JOBS_ROOT, jobId);
}

export async function readStatus(jobId: string): Promise<JobStatus | null> {
  try {
    const raw = await fs.readFile(path.join(jobDir(jobId), "status.json"), "utf8");
    return JSON.parse(raw) as JobStatus;
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === "ENOENT") return null;
    throw err;
  }
}

export async function writeStatus(jobId: string, status: JobStatus): Promise<void> {
  await fs.mkdir(jobDir(jobId), { recursive: true });
  await fs.writeFile(
    path.join(jobDir(jobId), "status.json"),
    JSON.stringify(status),
    "utf8",
  );
}

export async function findInputFile(jobId: string): Promise<string | null> {
  const dir = jobDir(jobId);
  try {
    const entries = await fs.readdir(dir);
    const input = entries.find((f) => f.startsWith("input."));
    return input ? path.join(dir, input) : null;
  } catch {
    return null;
  }
}
