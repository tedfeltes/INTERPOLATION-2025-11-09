# web — StakeDXF field-kit UI (shadcn)

Vite + React 19 + Tailwind v4 + [shadcn/ui](https://ui.shadcn.com) frontend for
**StakeDXF**: Civil 3D DWG → Trimble TSC5 DXF convert flow. This is a parallel
React surface; it does not replace the FastAPI-served pages in `../static/`.

## What the page does

- Brand-first field-kit convert UI (iPhone · TSC5 · OneDrive)
- DWG file pick / drag-drop, advanced DXF options, **Convert for TSC5**
- Posts to `/api/convert` + `/api/convert-file` (same FormData as `static/app.js`)
- Shows download link, stakeable/proxy/engine/DXF stats, layers, messages
- Field guide for iPhone convert, TSC5 copy, and Power Automate

## Develop

```bash
cd web
pnpm install
pnpm dev            # http://localhost:5173
```

Vite proxies `/api` and `/static` to the FastAPI app at `http://127.0.0.1:8000`.
Run the API separately if you want live conversion; without it the UI still
loads and shows a clear error on convert.

Other scripts: `pnpm build`, `pnpm preview`, `pnpm lint`, `pnpm typecheck`.

## Add shadcn components

```bash
pnpm dlx shadcn@latest add <component> -y
```

Components install into `src/components/ui/`. Feature UI lives in
`src/components/` (not under `ui/`).

## Theme

StakeDXF tokens live in `src/index.css` (deep field green, sage ink, terracotta
CTA primary, Syne + Instrument Sans + JetBrains Mono). Dark is the default.
