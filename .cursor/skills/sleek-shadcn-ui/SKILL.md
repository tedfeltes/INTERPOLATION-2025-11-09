---
name: sleek-shadcn-ui
description: Designs and builds sleek StakeDXF UI with shadcn/ui (Vite + React + Tailwind v4). Use when creating or refining web UI, adding shadcn components, theming, forms, dialogs, tables, or when the user mentions shadcn, sleek UI, or the web/ frontend.
---

# Sleek shadcn UI

Build polished StakeDXF interfaces by **invoking the shadcn CLI** — never hand-copy component source from docs or GitHub.

## Project surface

| Path | Role |
|------|------|
| `web/` | Vite + React 19 + Tailwind v4 + shadcn (`base-nova`, Lucide) |
| `web/components.json` | shadcn config |
| `web/src/components/ui/` | Installed components (owned source) |
| `static/` | Legacy FastAPI HTML — do not replace unless asked |

If `web/` is missing, do not apply shadcn to the legacy static UI or import another branch silently. Determine whether the task authorizes creating the React frontend. Use `origin/cursor/integrate-shadcn-ui-4295` as a reference, or initialize shadcn in a new Vite app under `web/`, only when that choice is in scope.

## Invoke shadcn (required)

Always use the project package runner from `web/`:

```bash
cd web
pnpm dlx shadcn@latest add <component...> -y
```

Examples:

```bash
pnpm dlx shadcn@latest add button card input label dialog table tabs select checkbox dropdown-menu separator scroll-area -y
pnpm dlx shadcn@latest add --dry-run button   # preview only
pnpm dlx shadcn@latest add --diff button      # compare local vs registry
pnpm dlx shadcn@latest info                   # project + installed components
```

Rules:

- Prefer CLI over pasting registry code.
- Use `--dry-run` / `--diff` / `--view` to inspect before overwriting.
- Import via aliases: `import { Button } from "@/components/ui/button"`.
- Do not edit generated `ui/*` unless customizing for brand; prefer composition in feature components.

## Design direction (StakeDXF)

Preserve field-kit branding — not generic dashboard chrome.

**Tokens (map into CSS variables / Tailwind theme):**

- Deep field green background (`#10160f` / near-black green)
- Soft panel surfaces with subtle translucency
- Ink `#e8efe4`, muted `#9aab93`
- Accent terracotta `#e4572e` (CTA only — sparingly)
- Field green `#6f9b5a` for positive / secondary actions
- Display: Syne or strong heading; body: Instrument Sans (or Geist if already in `web/`); mono: JetBrains Mono for DXF/engine metadata

**Composition:**

1. One job per viewport/section — brand + one headline + one short lede + one CTA group.
2. Hero/brand must read without the nav; brand name is hero-level.
3. Add restrained atmosphere through gradients or topographic texture when it supports the composition.
4. Cards only for interactive containers (forms, job panels). No card chrome in heroes.
5. No purple-on-white, no cream+serif+terracotta brochure look, no glow stacks, no emoji decoration, no pill-cluster clutter.
6. Touch-friendly for iPhone / TSC5: large tap targets, clear primary CTA.
7. Use intentional motion (for example, rise-in or a subtle dropzone pulse) to explain state and orientation, never to meet an animation quota.

## Workflow

1. **Orient** — Read `web/components.json`, list `web/src/components/ui/`, skim `static/styles.css` for brand tokens.
2. **Plan components** — Name the shadcn primitives needed (button, dialog, table, …).
3. **Add via CLI** — `pnpm dlx shadcn@latest add … -y` from `web/`.
4. **Compose** — Feature components under `web/src/components/` (not inside `ui/`).
5. **Theme** — Align `src/index.css` CSS variables with StakeDXF tokens; keep light/dark coherent via theme provider.
6. **Verify** — `pnpm typecheck && pnpm lint && pnpm build` in `web/`. Check desktop + narrow mobile widths.

## Output expectations

- Sleek, sparse layouts with strong hierarchy
- shadcn primitives for all controls (no one-off CSS button systems)
- Accessible labels, keyboard focus, and `aria-*` on custom interactive regions
- Copy that matches field language: DWG → DXF, TSC5, OneDrive, proxies, stakeable points

## Additional resources

- Component recipes and patterns: [reference.md](reference.md)
