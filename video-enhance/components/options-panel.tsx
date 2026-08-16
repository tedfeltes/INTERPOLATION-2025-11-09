"use client";

import type { EnhanceOptions } from "@/lib/types";

type Props = {
  value: EnhanceOptions;
  onChange: (next: EnhanceOptions) => void;
  disabled?: boolean;
};

export function OptionsPanel({ value, onChange, disabled }: Props) {
  const set = <K extends keyof EnhanceOptions>(k: K, v: EnhanceOptions[K]) =>
    onChange({ ...value, [k]: v });

  return (
    <div className={disabled ? "opacity-60 pointer-events-none" : ""}>
      <h2 className="text-sm font-semibold tracking-tight">Enhancement</h2>
      <div className="mt-3 flex flex-col gap-3">
        <Row label="Upscale">
          <select
            className="field"
            value={value.upscale}
            onChange={(e) =>
              set("upscale", e.target.value as EnhanceOptions["upscale"])
            }
          >
            <option value="none">No upscale</option>
            <option value="1.5x">1.5× (lanczos)</option>
            <option value="2x">2× (lanczos)</option>
            <option value="4k">Fit to 4K</option>
          </select>
        </Row>

        <Row label="Stabilize">
          <select
            className="field"
            value={value.stabilize}
            onChange={(e) =>
              set("stabilize", e.target.value as EnhanceOptions["stabilize"])
            }
          >
            <option value="off">Off</option>
            <option value="light">Light</option>
            <option value="strong">Strong</option>
          </select>
        </Row>

        <ToggleRow
          label="Denoise (hqdn3d)"
          on={value.denoise}
          onToggle={(v) => set("denoise", v)}
        />
        <ToggleRow
          label="Sharpen (unsharp)"
          on={value.sharpen}
          onToggle={(v) => set("sharpen", v)}
        />
        <ToggleRow
          label="Auto color grade"
          on={value.colorGrade}
          onToggle={(v) => set("colorGrade", v)}
        />
        <ToggleRow
          label="Clean up audio"
          on={value.audioClean}
          onToggle={(v) => set("audioClean", v)}
        />
      </div>

      <h3 className="mt-6 text-xs font-semibold uppercase tracking-widest text-muted">
        Grade
      </h3>
      <div className="mt-2 flex flex-col gap-2">
        <SliderRow
          label="Brightness"
          min={-0.3}
          max={0.3}
          step={0.01}
          value={value.brightness}
          onChange={(v) => set("brightness", v)}
        />
        <SliderRow
          label="Contrast"
          min={0.7}
          max={1.4}
          step={0.01}
          value={value.contrast}
          onChange={(v) => set("contrast", v)}
        />
        <SliderRow
          label="Saturation"
          min={0.7}
          max={1.6}
          step={0.01}
          value={value.saturation}
          onChange={(v) => set("saturation", v)}
        />
      </div>

      <h3 className="mt-6 text-xs font-semibold uppercase tracking-widest text-muted">
        Encoding
      </h3>
      <div className="mt-2">
        <SliderRow
          label={`CRF (${value.crf})`}
          min={16}
          max={28}
          step={1}
          value={value.crf}
          onChange={(v) => set("crf", Math.round(v))}
        />
        <p className="mt-1 text-[11px] text-muted">
          Lower = higher quality, bigger file. 18–22 is a good range.
        </p>
      </div>
    </div>
  );
}

function Row({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <label className="flex items-center justify-between gap-3">
      <span className="text-sm text-text">{label}</span>
      <div className="min-w-[160px]">{children}</div>
    </label>
  );
}

function ToggleRow({
  label,
  on,
  onToggle,
}: {
  label: string;
  on: boolean;
  onToggle: (v: boolean) => void;
}) {
  return (
    <div className="flex items-center justify-between">
      <span className="text-sm text-text">{label}</span>
      <button
        type="button"
        className="toggle"
        data-on={on ? "true" : "false"}
        onClick={() => onToggle(!on)}
        aria-pressed={on}
        aria-label={label}
      />
    </div>
  );
}

function SliderRow({
  label,
  min,
  max,
  step,
  value,
  onChange,
}: {
  label: string;
  min: number;
  max: number;
  step: number;
  value: number;
  onChange: (v: number) => void;
}) {
  return (
    <label className="flex flex-col gap-1">
      <div className="flex items-center justify-between text-xs text-muted">
        <span>{label}</span>
        <span className="tabular-nums">{value.toFixed(2)}</span>
      </div>
      <input
        type="range"
        min={min}
        max={max}
        step={step}
        value={value}
        onChange={(e) => onChange(Number(e.target.value))}
        className="accent-accent"
      />
    </label>
  );
}
