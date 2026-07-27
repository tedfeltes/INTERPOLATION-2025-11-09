---
name: sleek-ui-design
description: Designs and implements polished, responsive web interfaces with shadcn/ui. Use when creating or refining pages, dashboards, forms, landing pages, design systems, or reusable UI components.
disable-model-invocation: true
---

# Sleek UI Design

Create distinctive, production-ready interfaces by composing shadcn/ui primitives with the project's existing design system.

## Workflow

1. Inspect the application before editing:
   - Identify the framework, package manager, Tailwind version, and existing component conventions.
   - Read `components.json`, global styles, theme tokens, and nearby UI.
   - Preserve established behavior and visual language unless the request calls for a redesign.
2. Form a compact visual direction covering hierarchy, typography, color, spacing, and interaction.
3. Invoke shadcn before hand-coding a primitive:
   - Prefer configured shadcn registry tools to search, preview, and install components.
   - Otherwise use the project's package manager with `shadcn@latest add <component>`.
   - Reuse installed components when suitable.
   - Initialize shadcn only when the project is compatible and has no `components.json`; inspect generated changes before continuing.
4. Compose the smallest useful set of primitives. Extend them through props, variants, and theme tokens rather than duplicating their internals.
5. Validate the result at narrow and wide viewports, with keyboard navigation, visible focus, semantic labels, and relevant loading, empty, error, and disabled states.
6. Run the repository's focused tests, type checks, lint, and build as applicable. Manually exercise visible interaction changes.

## Visual Standard

- Establish one clear focal point and a deliberate information hierarchy.
- Use a restrained palette, consistent spacing rhythm, readable line lengths, and strong contrast.
- Favor purposeful whitespace and subtle depth over excessive borders or nested cards.
- Use motion only to explain state changes or improve orientation.
- Avoid generic hero copy, decorative gradient overload, mismatched icon styles, and gratuitous effects.
- Make every viewport feel composed rather than merely unbroken.

## shadcn Rules

- Treat shadcn/ui as editable source that must fit the product, not as a finished visual identity.
- Prefer shadcn primitives for standard controls, overlays, navigation, feedback, and data display.
- Do not overwrite locally customized components without reviewing the diff.
- Do not add a component, dependency, or variant unless the implemented interface uses it.
- Keep accessibility behavior supplied by Radix primitives intact.

## Completion

Report the visual direction, shadcn components invoked, files changed, and validation performed. Mention any unavailable states or viewports that could not be verified.
