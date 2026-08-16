"use client";

export function ProgressBar({ pct }: { pct: number }) {
  const clamped = Math.max(0, Math.min(100, pct));
  return (
    <div className="relative h-1.5 w-full overflow-hidden rounded-full bg-border">
      <div
        className="absolute inset-y-0 left-0 bg-gradient-to-r from-accent to-accentSoft transition-[width] duration-200"
        style={{ width: `${clamped}%` }}
      />
    </div>
  );
}
