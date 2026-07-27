---
name: sleek-ui-design
description: Designs and refines sleek, production-ready StakeDXF interfaces with intentional hierarchy, responsive behavior, accessibility, and polished interaction states. Use for UI/UX work, screens, components, styling, design systems, or visual reviews; invokes shadcn for component discovery and implementation guidance.
disable-model-invocation: true
---

# Sleek UI Design

## Required workflow

1. Inspect the target surface, user flow, existing design tokens, and framework before proposing changes.
2. Identify the primary user action, information hierarchy, responsive constraints, and all loading, empty, success, disabled, and error states.
3. Invoke shadcn before writing UI:
   - Prefer the configured shadcn MCP tools to search the registry, inspect component source and documentation, and install compatible components.
   - If MCP is unavailable, use the repository's package runner or `npx shadcn@latest`.
   - Useful fallback commands:

     ```bash
     npx shadcn@latest info
     npx shadcn@latest search @shadcn -q "<interface need>"
     npx shadcn@latest view <component...>
     npx shadcn@latest docs <component>
     npx shadcn@latest add <component...> --dry-run
     ```

   - Name the shadcn primitives or blocks consulted in the final handoff.
4. Implement the smallest coherent design system needed for the task. Reuse tokens and shared primitives instead of adding one-off styles.
5. Validate behavior, accessibility, responsive layouts, and visual polish with the repository's automated and manual test workflow.

## Install or adapt

- In a compatible React project with `components.json`, install only the required shadcn items with `shadcn add`, inspect the generated source, and customize it to the product.
- In a compatible React project without shadcn configuration, run `shadcn init` only when the task authorizes project setup and no existing component system would be displaced.
- For StakeDXF's Flutter and plain HTML/CSS surfaces, use shadcn registry items as design and interaction references. Do not add React or Tailwind solely to consume shadcn.
- Translate primitives to the native stack: for example, map Dialog, Sheet, Card, Alert, Progress, Tabs, Select, and Toast to Material 3 widgets or accessible semantic HTML/CSS/JavaScript.
- Preserve the reference component's semantics, focus behavior, keyboard operation, disabled state, and screen-reader labeling.
- Treat a framework migration as a separate architectural change that requires explicit scope.

## StakeDXF visual direction

- Optimize first for phone and Trimble TSC5 field use: fast scanning, direct copy, high contrast, and touch targets of at least 48 logical pixels.
- Preserve established product colors unless the task requests a rebrand: deep green-black backgrounds, restrained green support tones, and orange for the primary action.
- Use a deliberate spacing rhythm, concise typography scale, strong alignment, and one obvious primary action per screen.
- Prefer clear labels and familiar line icons over decorative copy, emoji, or ambiguous icon-only controls.
- Keep data-dense engineering content legible. Use progressive disclosure for secondary options without hiding critical status or next steps.
- Use depth, gradients, blur, and motion sparingly. Respect reduced-motion preferences and avoid decoration that competes with field tasks.

## Quality bar

- Build complete states with real product language; do not leave placeholder content or inert controls.
- Maintain WCAG AA contrast, visible focus, logical tab order, semantic headings, and useful validation messages.
- Keep layouts stable during loading and responsive without horizontal overflow.
- Preserve existing behavior and platform conventions unless a change is part of the request.
- Run relevant lint and automated tests. For visual changes, exercise the real flow at a compact field-device viewport and a wider viewport, then capture the minimal useful walkthrough artifact.

## Handoff

Report:

- the user-flow and visual improvements;
- the shadcn components or blocks installed or adapted;
- the validation performed and its result;
- any remaining compatibility or accessibility concerns.
