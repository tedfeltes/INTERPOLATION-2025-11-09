/**
 * Minimal, dependency-free assertions for the pure pipeline builder.
 * Run with:  npx tsx lib/pipeline.test.ts
 */
import {
  buildAudioChain,
  buildDetectChain,
  buildFilterChain,
} from "./pipeline";
import { defaultOptions, type EnhanceOptions, type TextBox } from "./types";

let failures = 0;
function check(name: string, cond: boolean, detail?: string) {
  if (cond) {
    console.log(`  ok  ${name}`);
  } else {
    failures += 1;
    console.error(`FAIL  ${name}${detail ? `\n      ${detail}` : ""}`);
  }
}

const probe = { width: 1920, height: 1080, durationSec: 12, fps: 30, hasAudio: true };

// 1. Empty options: only format=yuv420p should be present.
{
  const opts: EnhanceOptions = {
    ...defaultOptions,
    denoise: false,
    sharpen: false,
    colorGrade: false,
    stabilize: "off",
    upscale: "none",
    audioClean: false,
  };
  const { filterChain, twoPassStabilize } = buildFilterChain(opts, [], probe);
  check("no options -> yuv420p only", filterChain === "format=yuv420p", filterChain);
  check("no options -> no stabilize prepass", twoPassStabilize === false);
  check("no options -> no audio chain", buildAudioChain(opts) === null);
}

// 2. Default options exercise most of the pipeline.
{
  const { filterChain, twoPassStabilize } = buildFilterChain(
    defaultOptions,
    [],
    probe,
  );
  check("defaults include hqdn3d", filterChain.includes("hqdn3d"));
  check("defaults include eq", filterChain.includes("eq="));
  check("defaults include unsharp", filterChain.includes("unsharp="));
  check("defaults include vidstabtransform", filterChain.includes("vidstabtransform"));
  check("defaults request two-pass stabilize", twoPassStabilize === true);
  check(
    "detect chain non-empty for stabilize",
    buildDetectChain(defaultOptions).includes("vidstabdetect"),
  );
}

// 3. Text boxes come first and map to pixels correctly.
{
  const box: TextBox = { x: 0.1, y: 0.2, w: 0.3, h: 0.4 };
  const { filterChain } = buildFilterChain(defaultOptions, [box], probe);
  const first = filterChain.split(",")[0];
  const expected = `delogo=x=192:y=216:w=576:h=432:show=0`;
  check("delogo emitted first", first === expected, `${first} vs ${expected}`);
}

// 4. 4K upscale is skipped when already >=4K.
{
  const { filterChain } = buildFilterChain(
    { ...defaultOptions, upscale: "4k" },
    [],
    { ...probe, width: 3840, height: 2160 },
  );
  check(
    "4k target is a no-op above 4K",
    !filterChain.includes("scale=") || filterChain.includes("scale=iw*"),
    filterChain,
  );
}

// 5. Extreme grade values are clamped inside eq= parameters.
{
  const wild: EnhanceOptions = {
    ...defaultOptions,
    brightness: 99,
    contrast: -5,
    saturation: 999,
    stabilize: "off",
    denoise: false,
    sharpen: false,
    upscale: "none",
  };
  const { filterChain } = buildFilterChain(wild, [], probe);
  const eq = filterChain.split(",").find((s) => s.startsWith("eq="));
  check("eq clamps brightness", !!eq && eq.includes("brightness=1"));
  check("eq clamps contrast", !!eq && eq.includes("contrast=0.1"));
  check("eq clamps saturation", !!eq && eq.includes("saturation=3"));
}

if (failures > 0) {
  console.error(`\n${failures} check(s) failed`);
  process.exit(1);
} else {
  console.log("\nall pipeline checks passed");
}
