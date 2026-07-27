import { DownloadIcon } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { ScrollArea } from "@/components/ui/scroll-area"
import { Separator } from "@/components/ui/separator"
import type { ConvertResult } from "@/lib/convert-api"

type ResultsPanelProps = {
  payload: ConvertResult
  blobUrl?: string
  filename: string
}

export function ResultsPanel({
  payload,
  blobUrl,
  filename,
}: ResultsPanelProps) {
  const href = blobUrl || payload.download_url || "#"
  const layers = (payload.layers || []).slice(0, 24)
  const notes = [...(payload.messages || []), ...(payload.warnings || [])]

  const stats: [string, string | number][] = [
    ["Stakeable", payload.stakeable_count ?? "—"],
    ["Proxies recovered", payload.proxy_carriers_exploded ?? 0],
    ["Engine", payload.engine ?? "—"],
    ["DXF", payload.dxf_version ?? "—"],
  ]

  return (
    <Card className="animate-rise rounded-[var(--radius)] border border-[rgba(143,206,107,0.35)] bg-[rgba(20,36,18,0.75)] ring-0">
      <CardHeader className="gap-4">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
          <CardTitle className="font-display text-xl font-bold">
            DXF ready
          </CardTitle>
          <Button
            render={
              <a
                href={href}
                download={filename}
                target="_blank"
                rel="noopener noreferrer"
              />
            }
            className="h-12 w-full rounded-[var(--radius)] font-display text-base font-bold shadow-[0_8px_24px_rgba(228,87,46,0.25)] sm:w-auto sm:min-w-56"
          >
            <DownloadIcon data-icon="inline-start" />
            Save DXF to Files / OneDrive
          </Button>
        </div>
        <CardDescription className="text-[0.92rem] text-muted-foreground">
          Next on TSC5: OneDrive → copy into{" "}
          <code>Trimble Data/Projects/&lt;job&gt;/</code> → Map files →
          selectable → Stakeout.
        </CardDescription>
      </CardHeader>

      <CardContent className="flex flex-col gap-4">
        <dl className="m-0 grid grid-cols-2 gap-3 sm:grid-cols-4">
          {stats.map(([label, value]) => (
            <div
              key={label}
              className="rounded-[var(--radius)] border border-border bg-black/20 p-3"
            >
              <dt className="text-[0.75rem] tracking-wider text-muted-foreground uppercase">
                {label}
              </dt>
              <dd className="mt-1 font-mono text-lg">{value}</dd>
            </div>
          ))}
        </dl>

        {layers.length > 0 ? (
          <div className="flex flex-col gap-2">
            <p className="m-0 font-mono text-xs tracking-wider text-muted-foreground uppercase">
              Layers
            </p>
            <ScrollArea className="max-h-28">
              <div className="flex flex-wrap gap-1.5 pr-3">
                {layers.map((layer) => (
                  <Badge
                    key={layer.name}
                    variant="outline"
                    className="rounded-[var(--radius)] font-mono text-[0.75rem] font-normal text-muted-foreground"
                  >
                    {layer.name} · {layer.stakeable_count}
                  </Badge>
                ))}
              </div>
            </ScrollArea>
          </div>
        ) : null}

        {notes.length > 0 ? (
          <>
            <Separator />
            <ul className="m-0 list-disc space-y-1.5 pl-4 text-sm text-warn">
              {notes.map((note) => (
                <li key={note}>{note}</li>
              ))}
            </ul>
          </>
        ) : null}
      </CardContent>
    </Card>
  )
}
