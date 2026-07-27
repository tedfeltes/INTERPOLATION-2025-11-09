import { useId, useRef, useState } from "react"
import { ChevronDownIcon, Loader2Icon } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardFooter,
  CardHeader,
} from "@/components/ui/card"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Collapsible,
  CollapsibleContent,
  CollapsibleTrigger,
} from "@/components/ui/collapsible"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Separator } from "@/components/ui/separator"
import { cn } from "@/lib/utils"
import {
  type ConvertOptions,
  type ConvertResult,
  type DxfVersion,
  DEFAULT_CONVERT_OPTIONS,
  runConvertJob,
} from "@/lib/convert-api"

const DXF_VERSIONS: { value: DxfVersion; label: string }[] = [
  { value: "R2010", label: "R2010 (recommended)" },
  { value: "R2000", label: "R2000" },
  { value: "R2007", label: "R2007" },
  { value: "R2013", label: "R2013" },
  { value: "R2018", label: "R2018" },
]

export type ConvertSuccess = {
  payload: ConvertResult
  blobUrl?: string
  filename: string
}

type ConvertJobFormProps = {
  onSuccess: (result: ConvertSuccess) => void
  onClearResult: () => void
}

export function ConvertJobForm({
  onSuccess,
  onClearResult,
}: ConvertJobFormProps) {
  const fileInputId = useId()
  const inputRef = useRef<HTMLInputElement>(null)
  const [file, setFile] = useState<File | null>(null)
  const [dragging, setDragging] = useState(false)
  const [options, setOptions] = useState<ConvertOptions>(DEFAULT_CONVERT_OPTIONS)
  const [advancedOpen, setAdvancedOpen] = useState(false)
  const [busy, setBusy] = useState(false)
  const [status, setStatus] = useState("")
  const [isError, setIsError] = useState(false)

  function assignFile(next: File | null | undefined) {
    setFile(next ?? null)
  }

  function onDrop(event: React.DragEvent<HTMLLabelElement>) {
    event.preventDefault()
    setDragging(false)
    const next = event.dataTransfer.files?.[0]
    if (next) assignFile(next)
  }

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault()
    if (!file) {
      setIsError(true)
      setStatus("Choose a DWG from OneDrive / Files first.")
      return
    }

    setBusy(true)
    setIsError(false)
    onClearResult()
    setStatus("Uploading to cloud converter…")

    try {
      setStatus("Preparing DXF download…")
      const result = await runConvertJob(file, options)
      setStatus(result.status)
      setIsError(false)
      onSuccess({
        payload: result.payload,
        blobUrl: result.blobUrl,
        filename: result.filename,
      })
    } catch (error) {
      setIsError(true)
      setStatus(
        error instanceof Error ? error.message : "Conversion failed."
      )
    } finally {
      setBusy(false)
    }
  }

  const fileLabel = file
    ? `${file.name} · ${Math.max(1, Math.round(file.size / 1024))} KB`
    : null

  return (
    <Card className="animate-rise-delay rounded-[var(--radius)] bg-card/90 ring-border backdrop-blur-md">
      <CardHeader className="gap-3">
        <ol
          className="m-0 grid list-none grid-cols-1 gap-2 p-0 sm:grid-cols-3"
          aria-label="Field workflow"
        >
          {[
            ["OneDrive", "DWG from office"],
            ["Convert", "here on iPhone or TSC5"],
            ["Copy DXF", "into Trimble Data/Projects"],
          ].map(([title, detail]) => (
            <li
              key={title}
              className="rounded-[var(--radius)] border border-border bg-black/35 px-3.5 py-2.5 text-sm text-muted-foreground"
            >
              <strong className="font-display text-accent-soft">{title}</strong>{" "}
              {detail}
            </li>
          ))}
        </ol>
      </CardHeader>

      <CardContent>
        <form id="convert-form" onSubmit={onSubmit} className="flex flex-col gap-4">
          <label
            htmlFor={fileInputId}
            onDragEnter={(event) => {
              event.preventDefault()
              setDragging(true)
            }}
            onDragOver={(event) => {
              event.preventDefault()
              setDragging(true)
            }}
            onDragLeave={(event) => {
              event.preventDefault()
              setDragging(false)
            }}
            onDrop={onDrop}
            className={cn(
              "relative grid min-h-36 cursor-pointer place-items-center gap-1 rounded-[var(--radius)] border-[1.5px] border-dashed border-[rgba(228,87,46,0.45)] bg-[linear-gradient(180deg,rgba(228,87,46,0.08),transparent_60%),rgba(8,12,8,0.45)] px-6 py-6 text-center transition-colors",
              (dragging || file) && "bg-[rgba(228,87,46,0.12)]",
              dragging && "dropzone-active"
            )}
          >
            <input
              ref={inputRef}
              id={fileInputId}
              name="file"
              type="file"
              accept=".dwg,.dxf,application/acad,image/vnd.dwg,application/octet-stream"
              className="absolute inset-0 cursor-pointer opacity-0"
              onChange={(event) => assignFile(event.target.files?.[0])}
            />
            <span className="font-display text-xl font-bold sm:text-[1.35rem]">
              Choose DWG from OneDrive
            </span>
            <span className="text-sm text-muted-foreground">
              Safari/Files → Browse → OneDrive location
            </span>
            {fileLabel ? (
              <span className="mt-2 rounded-full border border-[rgba(111,155,90,0.4)] bg-[rgba(111,155,90,0.2)] px-2.5 py-1 font-mono text-xs">
                {fileLabel}
              </span>
            ) : null}
          </label>

          <Collapsible open={advancedOpen} onOpenChange={setAdvancedOpen}>
            <div className="rounded-[var(--radius)] border border-border bg-black/15 px-3 py-1">
              <CollapsibleTrigger
                render={
                  <Button
                    type="button"
                    variant="ghost"
                    className="h-11 w-full justify-between px-1 font-display font-bold text-muted-foreground hover:text-foreground"
                  />
                }
              >
                Advanced options
                <ChevronDownIcon
                  className={cn(
                    "size-4 transition-transform",
                    advancedOpen && "rotate-180"
                  )}
                />
              </CollapsibleTrigger>
              <CollapsibleContent className="overflow-hidden data-closed:animate-out data-closed:fade-out-0 data-open:animate-in data-open:fade-in-0">
                <Separator className="mb-3" />
                <div className="mb-3 grid grid-cols-1 gap-3 sm:grid-cols-2">
                  <div className="flex flex-col gap-1.5 sm:col-span-2">
                    <Label htmlFor="dxf-version" className="text-muted-foreground">
                      DXF version
                    </Label>
                    <Select
                      value={options.dxfVersion}
                      onValueChange={(value) => {
                        if (!value) return
                        setOptions((prev) => ({
                          ...prev,
                          dxfVersion: value as DxfVersion,
                        }))
                      }}
                    >
                      <SelectTrigger
                        id="dxf-version"
                        className="h-11 w-full min-w-0 rounded-[var(--radius)]"
                      >
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        {DXF_VERSIONS.map((version) => (
                          <SelectItem key={version.value} value={version.value}>
                            {version.label}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  </div>

                  {(
                    [
                      ["explodeProxies", "Explode Civil 3D proxies"],
                      ["explodeBlocks", "Explode blocks"],
                      ["convertSplines", "Splines → polylines"],
                      ["flattenZ", "Flatten Z to 0"],
                    ] as const
                  ).map(([key, label]) => (
                    <label
                      key={key}
                      className="flex min-h-11 items-center gap-2.5 text-sm text-muted-foreground"
                    >
                      <Checkbox
                        checked={options[key]}
                        onCheckedChange={(checked) =>
                          setOptions((prev) => ({
                            ...prev,
                            [key]: checked === true,
                          }))
                        }
                      />
                      <span>{label}</span>
                    </label>
                  ))}

                  <div className="flex flex-col gap-1.5 sm:col-span-2">
                    <Label
                      htmlFor="include-layers"
                      className="text-muted-foreground"
                    >
                      Include layers only
                    </Label>
                    <Input
                      id="include-layers"
                      value={options.includeLayers}
                      onChange={(event) =>
                        setOptions((prev) => ({
                          ...prev,
                          includeLayers: event.target.value,
                        }))
                      }
                      placeholder="CL, EOP, CURB"
                      className="h-11 rounded-[var(--radius)]"
                    />
                  </div>
                  <div className="flex flex-col gap-1.5 sm:col-span-2">
                    <Label
                      htmlFor="exclude-layers"
                      className="text-muted-foreground"
                    >
                      Exclude layers
                    </Label>
                    <Input
                      id="exclude-layers"
                      value={options.excludeLayers}
                      onChange={(event) =>
                        setOptions((prev) => ({
                          ...prev,
                          excludeLayers: event.target.value,
                        }))
                      }
                      placeholder="DEFPOINTS, HATCH"
                      className="h-11 rounded-[var(--radius)]"
                    />
                  </div>
                </div>
              </CollapsibleContent>
            </div>
          </Collapsible>
        </form>
      </CardContent>

      <CardFooter className="flex flex-col items-stretch gap-3 border-t-0 bg-transparent">
        <Button
          type="submit"
          form="convert-form"
          disabled={busy}
          className="h-12 w-full rounded-[var(--radius)] font-display text-base font-bold shadow-[0_8px_24px_rgba(228,87,46,0.25)]"
        >
          {busy ? (
            <>
              <Loader2Icon className="animate-spin" data-icon="inline-start" />
              Converting…
            </>
          ) : (
            "Convert for TSC5"
          )}
        </Button>
        <p
          role="status"
          aria-live="polite"
          className={cn(
            "m-0 text-sm text-muted-foreground",
            isError && "text-destructive"
          )}
        >
          {status}
        </p>
      </CardFooter>
    </Card>
  )
}
