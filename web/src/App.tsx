import { useState } from "react"
import { FileUpIcon, GaugeIcon, MoonIcon, SunIcon } from "lucide-react"

import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  Card,
  CardAction,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { useTheme } from "@/components/theme-provider"

export function App() {
  const { theme, setTheme } = useTheme()
  const [job, setJob] = useState("PHEASANT_FARM")

  return (
    <div className="min-h-svh bg-background text-foreground">
      <header className="flex items-center justify-between border-b px-6 py-4">
        <div className="flex items-center gap-2">
          <GaugeIcon data-icon="inline-start" />
          <span className="font-heading text-base font-semibold">StakeDXF</span>
          <Badge variant="secondary">shadcn/ui</Badge>
        </div>
        <Button
          variant="outline"
          size="icon"
          aria-label="Toggle dark mode"
          onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
        >
          {theme === "dark" ? <MoonIcon /> : <SunIcon />}
        </Button>
      </header>

      <main className="mx-auto flex w-full max-w-2xl flex-col gap-6 px-6 py-10">
        <div className="flex flex-col gap-1">
          <h1 className="font-heading text-2xl font-semibold">
            shadcn/ui integration
          </h1>
          <p className="text-sm text-muted-foreground">
            A Vite + React + Tailwind v4 surface wired up with shadcn/ui
            components.
          </p>
        </div>

        <Card>
          <CardHeader className="border-b">
            <CardTitle>New conversion job</CardTitle>
            <CardDescription>
              Configure a Civil 3D DWG → Trimble Access DXF run.
            </CardDescription>
            <CardAction>
              <Badge>R2010</Badge>
            </CardAction>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            <div className="flex flex-col gap-2">
              <Label htmlFor="job">Project name</Label>
              <Input
                id="job"
                value={job}
                onChange={(event) => setJob(event.target.value)}
                placeholder="e.g. PHEASANT_FARM"
              />
            </div>
            <div className="flex flex-col gap-2">
              <Label htmlFor="engine">Preferred engine</Label>
              <Input id="engine" defaultValue="ezdwg" />
            </div>
          </CardContent>
          <CardFooter className="justify-between">
            <span className="text-sm text-muted-foreground">
              Output: {job || "drawing"}_trimble_access.dxf
            </span>
            <Button>
              <FileUpIcon data-icon="inline-start" />
              Convert for TSC5
            </Button>
          </CardFooter>
        </Card>

        <div className="flex flex-wrap items-center gap-2">
          <Badge variant="secondary">Stakeable: 1</Badge>
          <Badge variant="outline">Proxies recovered: 0</Badge>
          <Badge>Engine: ezdwg</Badge>
        </div>
      </main>
    </div>
  )
}

export default App
