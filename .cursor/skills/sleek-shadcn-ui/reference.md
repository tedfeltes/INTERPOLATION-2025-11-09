# Sleek shadcn UI — reference

## CLI cheat sheet

Run from `web/` with `pnpm dlx shadcn@latest`:

| Command | Purpose |
|---------|---------|
| `init` | Scaffold / reconfigure shadcn in a project |
| `add <names…> -y` | Install component source into `src/components/ui/` |
| `add --all -y` | Install entire registry (rare — prefer targeted adds) |
| `add --dry-run …` | Preview file writes without changing disk |
| `add --diff [path]` | Diff local vs registry |
| `add --view [path]` | Print registry file contents |
| `info` | Framework, CSS vars, installed components |
| `docs <component>` | Open / fetch component docs hints |

Overwrite existing local customizations only with explicit `--overwrite` / `-o`.

## Suggested component sets

**Convert job form:** `button` `card` `input` `label` `select` `checkbox` `badge` `separator`

**Results / layers:** `table` `tabs` `scroll-area` `badge` `dropdown-menu`

**Confirmations / errors:** `dialog` `alert` `sonner` (or `toast`)

**Settings / advanced:** `collapsible` `accordion` `switch` `slider`

## Import pattern

```tsx
import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
```

Compose feature UI outside `components/ui/`:

```text
web/src/components/
  convert-job-form.tsx
  results-panel.tsx
  ui/          ← CLI-owned primitives
```

## Theme mapping hints

Map StakeDXF brand into shadcn CSS variables in `src/index.css`:

| Brand | shadcn token |
|-------|----------------|
| Deep field green | `--background` / dark scheme |
| Soft panel | `--card`, `--popover` |
| Ink | `--foreground` |
| Muted sage | `--muted-foreground` |
| Terracotta CTA | `--primary` (use sparingly) |
| Field green OK | success utility or secondary |

Keep radius modest (`--radius` ~ `0.4rem`–`0.625rem`) — field tool, not consumer SaaS blobs.

## Screen patterns

### Convert (primary)

- Brand-forward header: StakeDXF mark + short device context
- One convert panel: file dropzone + advanced options in collapsible
- Primary CTA: “Convert for TSC5”
- Status badges for engine / DXF version / proxy recovery

### Results

- Dense but calm mono metadata
- Layer / point tables with clear selection states
- Secondary actions as outline buttons, not competing fills

### Mobile / TSC5

- Full-width primary CTA sticky near bottom when scrolling
- Minimum ~44px tap targets
- Avoid hover-only affordances

## Anti-patterns

- Hand-pasting component files from ui.shadcn.com instead of CLI
- Replacing `static/` without an explicit request
- Purple gradient “AI default” themes
- Card wrapping the entire page / hero
- Stat strips and badge clouds in the first viewport
- Editing many `ui/*` files when a wrapper component would do
