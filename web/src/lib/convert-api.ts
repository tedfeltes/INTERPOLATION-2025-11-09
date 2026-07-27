export type DxfVersion = "R2000" | "R2007" | "R2010" | "R2013" | "R2018"

export type ConvertOptions = {
  dxfVersion: DxfVersion
  explodeProxies: boolean
  explodeBlocks: boolean
  convertSplines: boolean
  flattenZ: boolean
  includeLayers: string
  excludeLayers: string
}

export type LayerStat = {
  name: string
  stakeable_count: number
}

export type ConvertResult = {
  stakeable_count?: number
  proxy_carriers_exploded?: number
  engine?: string
  dxf_version?: string
  output_name?: string
  download_url?: string
  layers?: LayerStat[]
  messages?: string[]
  warnings?: string[]
  detail?: string
}

export type GuidePayload = {
  iphone_steps?: string[]
  tsc5_steps?: string[]
  power_automate?: {
    template_path?: string
  }
}

export const DEFAULT_CONVERT_OPTIONS: ConvertOptions = {
  dxfVersion: "R2010",
  explodeProxies: true,
  explodeBlocks: true,
  convertSplines: true,
  flattenZ: false,
  includeLayers: "",
  excludeLayers: "",
}

export function buildConvertFormData(
  file: File,
  options: ConvertOptions
): FormData {
  const body = new FormData()
  body.append("file", file)
  body.append("dxf_version", options.dxfVersion)
  body.append("explode_blocks", String(options.explodeBlocks))
  body.append("convert_splines", String(options.convertSplines))
  body.append("explode_proxies", String(options.explodeProxies))
  body.append("include_display_only", "false")
  body.append("flatten_z", String(options.flattenZ))
  const includeLayers = options.includeLayers.trim()
  const excludeLayers = options.excludeLayers.trim()
  if (includeLayers) body.append("include_layers", includeLayers)
  if (excludeLayers) body.append("exclude_layers", excludeLayers)
  return body
}

function detailMessage(payload: ConvertResult | { detail?: unknown }): string {
  const detail = "detail" in payload ? payload.detail : undefined
  if (typeof detail === "string") return detail
  if (Array.isArray(detail)) {
    return detail
      .map((item) =>
        typeof item === "object" && item && "msg" in item
          ? String((item as { msg: unknown }).msg)
          : String(item)
      )
      .join("; ")
  }
  return "Conversion failed."
}

export type ConvertJobSuccess = {
  payload: ConvertResult
  blobUrl?: string
  filename: string
  status: string
}

export async function runConvertJob(
  file: File,
  options: ConvertOptions
): Promise<ConvertJobSuccess> {
  const body = buildConvertFormData(file, options)

  const metaResponse = await fetch("/api/convert", {
    method: "POST",
    body,
  })
  const payload = (await metaResponse.json().catch(() => ({}))) as ConvertResult
  if (!metaResponse.ok) {
    throw new Error(detailMessage(payload))
  }

  const proxyNote = payload.proxy_carriers_exploded
    ? ` Recovered ${payload.proxy_carriers_exploded} Civil 3D proxy object(s).`
    : ""
  const status = payload.stakeable_count
    ? `Ready — ${payload.stakeable_count} stakeable entities.${proxyNote}`
    : "Conversion finished — check warnings."

  const filename =
    payload.output_name ||
    file.name.replace(/\.(dwg|dxf)$/i, "") + "_trimble_access.dxf"

  try {
    const fileResponse = await fetch("/api/convert-file", {
      method: "POST",
      body: buildConvertFormData(file, options),
    })
    if (fileResponse.ok) {
      const blob = await fileResponse.blob()
      return {
        payload,
        blobUrl: URL.createObjectURL(blob),
        filename,
        status,
      }
    }
  } catch {
    // Fall back to JSON download_url
  }

  return { payload, filename, status }
}

export async function fetchGuide(): Promise<GuidePayload | null> {
  try {
    const response = await fetch("/api/guide")
    if (!response.ok) return null
    return (await response.json()) as GuidePayload
  } catch {
    return null
  }
}
