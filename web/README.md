# web — shadcn/ui frontend

A Vite + React + TypeScript app with [shadcn/ui](https://ui.shadcn.com/docs/installation)
integrated (Tailwind CSS v4, `base-nova` style, Lucide icons). This is a
standalone frontend surface; it does not replace the FastAPI-served static site
in `../static/`.

## Stack

- Vite + React 19 + TypeScript
- Tailwind CSS v4 (via `@tailwindcss/vite`)
- shadcn/ui — components live in `src/components/ui/`, config in `components.json`
- `@` path alias → `src/`

## Develop

```bash
cd web
pnpm install        # first time only
pnpm dev            # http://localhost:5173
```

Other scripts: `pnpm build`, `pnpm preview`, `pnpm lint`, `pnpm typecheck`.

## Add shadcn components

```bash
pnpm dlx shadcn@latest add <component>   # e.g. dialog table tabs
```

Components install into `src/components/ui/`. Import via the alias:

```tsx
import { Button } from "@/components/ui/button"
```

## Notes

- The generated `src/components/ui/**` files intentionally export variant helpers
  (e.g. `buttonVariants`), so `react-refresh/only-export-components` is disabled
  for that directory in `eslint.config.js`.
- Dark mode is handled by `src/components/theme-provider.tsx` (toggles the `dark`
  class on `<html>`; press `d` or use the toggle button).
