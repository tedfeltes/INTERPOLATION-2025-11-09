"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import type { TextBox } from "@/lib/types";

type Props = {
  imageSrc: string;
  intrinsicWidth: number;
  intrinsicHeight: number;
  boxes: TextBox[];
  onChange: (next: TextBox[]) => void;
};

/**
 * A small interactive canvas the user drags on to mark rectangles for text
 * removal. Coordinates are stored normalized (0..1) so they survive
 * responsive resizing and map cleanly to the source resolution on the server.
 */
export function TextBoxCanvas({
  imageSrc,
  intrinsicWidth,
  intrinsicHeight,
  boxes,
  onChange,
}: Props) {
  const containerRef = useRef<HTMLDivElement | null>(null);
  const [size, setSize] = useState<{ w: number; h: number }>({ w: 0, h: 0 });
  const [drag, setDrag] = useState<
    | { startX: number; startY: number; endX: number; endY: number }
    | null
  >(null);

  useEffect(() => {
    const el = containerRef.current;
    if (!el) return;
    const ro = new ResizeObserver(() => {
      const r = el.getBoundingClientRect();
      setSize({ w: r.width, h: r.height });
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const toNorm = useCallback(
    (clientX: number, clientY: number) => {
      const el = containerRef.current!;
      const rect = el.getBoundingClientRect();
      const x = clamp01((clientX - rect.left) / rect.width);
      const y = clamp01((clientY - rect.top) / rect.height);
      return { x, y };
    },
    [],
  );

  const onPointerDown = (e: React.PointerEvent) => {
    (e.target as Element).setPointerCapture(e.pointerId);
    const { x, y } = toNorm(e.clientX, e.clientY);
    setDrag({ startX: x, startY: y, endX: x, endY: y });
  };
  const onPointerMove = (e: React.PointerEvent) => {
    if (!drag) return;
    const { x, y } = toNorm(e.clientX, e.clientY);
    setDrag({ ...drag, endX: x, endY: y });
  };
  const onPointerUp = () => {
    if (!drag) return;
    const nx = Math.min(drag.startX, drag.endX);
    const ny = Math.min(drag.startY, drag.endY);
    const nw = Math.abs(drag.endX - drag.startX);
    const nh = Math.abs(drag.endY - drag.startY);
    setDrag(null);
    // Ignore microscopic drags (accidental clicks).
    if (nw < 0.01 || nh < 0.01) return;
    onChange([...boxes, { x: nx, y: ny, w: nw, h: nh }]);
  };

  const aspect = intrinsicWidth / intrinsicHeight || 16 / 9;

  return (
    <div className="flex flex-col gap-2">
      <div
        ref={containerRef}
        className="relative w-full overflow-hidden rounded-xl border border-border bg-black select-none touch-none"
        style={{ aspectRatio: aspect }}
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
      >
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={imageSrc}
          alt="preview"
          className="absolute inset-0 h-full w-full object-contain"
          draggable={false}
        />
        {boxes.map((b, i) => (
          <BoxOverlay
            key={i}
            box={b}
            size={size}
            onRemove={() => onChange(boxes.filter((_, j) => j !== i))}
          />
        ))}
        {drag && (
          <div
            className="absolute border-2 border-accent bg-accent/20 pointer-events-none"
            style={rectStyle(drag, size)}
          />
        )}
      </div>
      <div className="flex items-center justify-between text-xs">
        <span className="text-muted">
          {boxes.length === 0
            ? "No text-removal boxes yet"
            : `${boxes.length} region${boxes.length === 1 ? "" : "s"} marked`}
        </span>
        {boxes.length > 0 && (
          <button
            type="button"
            className="text-muted hover:text-text"
            onClick={() => onChange([])}
          >
            Clear all
          </button>
        )}
      </div>
    </div>
  );
}

function BoxOverlay({
  box,
  size,
  onRemove,
}: {
  box: TextBox;
  size: { w: number; h: number };
  onRemove: () => void;
}) {
  return (
    <div
      className="absolute border-2 border-accent bg-accent/10"
      style={{
        left: box.x * size.w,
        top: box.y * size.h,
        width: box.w * size.w,
        height: box.h * size.h,
      }}
    >
      <button
        type="button"
        onClick={onRemove}
        className="absolute -right-2 -top-2 flex h-5 w-5 items-center justify-center rounded-full bg-accent text-[11px] font-bold text-black shadow"
        aria-label="Remove box"
      >
        ×
      </button>
    </div>
  );
}

function rectStyle(
  drag: { startX: number; startY: number; endX: number; endY: number },
  size: { w: number; h: number },
): React.CSSProperties {
  const x = Math.min(drag.startX, drag.endX) * size.w;
  const y = Math.min(drag.startY, drag.endY) * size.h;
  const w = Math.abs(drag.endX - drag.startX) * size.w;
  const h = Math.abs(drag.endY - drag.startY) * size.h;
  return { left: x, top: y, width: w, height: h };
}

function clamp01(v: number): number {
  return Math.max(0, Math.min(1, v));
}
