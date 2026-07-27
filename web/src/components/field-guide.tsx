import { useEffect, useState } from "react"

import { Separator } from "@/components/ui/separator"
import { fetchGuide, type GuidePayload } from "@/lib/convert-api"

const FALLBACK_IPHONE = [
  "Open this page in Safari. Optional: Share → Add to Home Screen.",
  "Tap Choose DWG → Browse → your OneDrive project folder.",
  "Tap Convert for TSC5.",
  "Tap Save DXF → Save to Files → OneDrive.",
]

const FALLBACK_TSC5 = [
  "On the TSC5, open the OneDrive app and download the DXF.",
  "Trimble Access → Job data → File Explorer.",
  "Copy DXF into Trimble Data/Projects/<your project>/.",
  "Map → Layer manager → Map files → tap DXF twice → Stakeout.",
]

export function FieldGuide() {
  const [guide, setGuide] = useState<GuidePayload | null>(null)

  useEffect(() => {
    let cancelled = false
    fetchGuide().then((payload) => {
      if (!cancelled) setGuide(payload)
    })
    return () => {
      cancelled = true
    }
  }, [])

  const iphoneSteps = guide?.iphone_steps?.length
    ? guide.iphone_steps
    : FALLBACK_IPHONE
  const tsc5Steps = guide?.tsc5_steps?.length ? guide.tsc5_steps : FALLBACK_TSC5
  const powerAutomateHref =
    guide?.power_automate?.template_path ||
    "/static/power-automate-onedrive.md"

  return (
    <section id="guide" className="animate-rise-late mt-14 border-t border-border pt-8">
      <h2 className="font-display mb-4 text-[1.8rem] font-bold">
        How you use this with only a phone + TSC5
      </h2>

      <article className="mb-5 pt-1">
        <h3 className="font-display mb-2.5 text-[1.05rem] text-accent-soft">
          A. Convert on iPhone (manual)
        </h3>
        <ol className="m-0 list-decimal space-y-1.5 pl-5 text-muted-foreground">
          {iphoneSteps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      </article>

      <article className="mb-5 pt-1">
        <h3 className="font-display mb-2.5 text-[1.05rem] text-accent-soft">
          B. Get the DXF onto the TSC5
        </h3>
        <ol className="m-0 list-decimal space-y-1.5 pl-5 text-muted-foreground">
          {tsc5Steps.map((step) => (
            <li key={step}>{step}</li>
          ))}
        </ol>
      </article>

      <article className="mb-2 rounded-[var(--radius)] border border-[rgba(228,87,46,0.35)] bg-[rgba(228,87,46,0.08)] p-4">
        <h3 className="font-display mb-2.5 text-[1.05rem] text-accent-soft">
          C. Best: auto-convert in OneDrive (no phone convert)
        </h3>
        <p className="m-0 mb-2 text-muted-foreground">
          Set up Power Automate once in the office: when a <code>.dwg</code>{" "}
          lands in the project folder, call StakeDXF and save{" "}
          <code>*_trimble_access.dxf</code> next to it. In the field you only
          copy the DXF to the TSC5.
        </p>
        <p className="m-0 text-muted-foreground">
          Details:{" "}
          <a
            href={powerAutomateHref}
            className="text-ok underline-offset-2 hover:underline"
            target="_blank"
            rel="noopener noreferrer"
          >
            Power Automate + OneDrive setup
          </a>
        </p>
      </article>

      <Separator className="my-10" />

      <section id="about">
        <h2 className="font-display mb-4 text-[1.8rem] font-bold">
          Why this works without a laptop
        </h2>
        <p className="m-0 max-w-xl text-[1.05rem] text-muted-foreground">
          The converter runs in the cloud. Your iPhone or TSC5 only uploads the
          DWG and downloads the DXF. Civil&nbsp;3D AECC objects are recovered
          from proxy graphics already stored in the office DWG.
        </p>
      </section>
    </section>
  )
}
