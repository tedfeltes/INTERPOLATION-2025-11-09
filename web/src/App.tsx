import { useEffect, useState } from "react"

import {
  ConvertJobForm,
  type ConvertSuccess,
} from "@/components/convert-job-form"
import { FieldGuide } from "@/components/field-guide"
import { ResultsPanel } from "@/components/results-panel"
import { SiteHeader } from "@/components/site-header"
import { Toaster } from "@/components/ui/sonner"

export function App() {
  const [result, setResult] = useState<ConvertSuccess | null>(null)

  useEffect(() => {
    return () => {
      if (result?.blobUrl) URL.revokeObjectURL(result.blobUrl)
    }
  }, [result?.blobUrl])

  return (
    <div className="relative min-h-svh text-foreground">
      <div className="field-atmosphere" aria-hidden="true" />
      <SiteHeader />

      <main className="mx-auto w-full max-w-[920px] px-4 py-10 sm:px-0 sm:w-[min(920px,calc(100%-2rem))]">
        <section id="convert" className="animate-rise">
          <p className="mb-1.5 font-mono text-[0.78rem] tracking-[0.08em] text-accent-soft uppercase">
            Field kit
          </p>
          <h1 className="font-display text-[clamp(2.6rem,14vw,5.5rem)] leading-[0.95] font-extrabold tracking-[-0.03em]">
            StakeDXF
          </h1>
          <p className="mt-4 mb-8 max-w-md text-lg text-muted-foreground">
            Pull a Civil&nbsp;3D DWG from OneDrive on your phone, convert in the
            cloud, drop the DXF onto your Trimble TSC5. No laptop.
          </p>

          <ConvertJobForm
            onClearResult={() => {
              if (result?.blobUrl) URL.revokeObjectURL(result.blobUrl)
              setResult(null)
            }}
            onSuccess={(next) => {
              if (result?.blobUrl) URL.revokeObjectURL(result.blobUrl)
              setResult(next)
              requestAnimationFrame(() => {
                document
                  .getElementById("result")
                  ?.scrollIntoView({ behavior: "smooth", block: "nearest" })
              })
            }}
          />

          {result ? (
            <div id="result" className="mt-5">
              <ResultsPanel
                payload={result.payload}
                blobUrl={result.blobUrl}
                filename={result.filename}
              />
            </div>
          ) : null}
        </section>

        <FieldGuide />
      </main>

      <footer className="mx-auto mb-8 flex w-full max-w-[920px] flex-wrap justify-between gap-2 px-4 font-mono text-xs text-muted-foreground sm:px-0 sm:w-[min(920px,calc(100%-2rem))]">
        <span>StakeDXF field kit</span>
        <span>Host this URL for cellular access</span>
      </footer>

      <Toaster position="bottom-center" />
    </div>
  )
}

export default App
