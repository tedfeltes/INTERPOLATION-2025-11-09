# Civil 3D — ZHOVER

Hover any entity and the elevation at that spot is drawn **next to the cursor in magenta**.

## Load

1. Civil 3D → type `APPLOAD`
2. Pick `civil3d/ZHOVER.lsp`
3. Type `ZHOVER` (or `ZH`)

To load in every drawing, add this to `acaddoc.lsp` on the support path:

```lisp
(load "ZHOVER.lsp")
```

## Use

Move the crosshair over linework, 3D polylines, feature lines, TIN/grid surfaces, COGO points, 3D faces, pipes — anything with elevation. Italic magenta `000.00` follows the cursor on a color-251 rectangle at 75% opacity.

- **Click** prints that Z on the command line
- **Esc / Enter / Space / right-click** exits

The value is always two decimal places (`000.00`). The label is temporary and is deleted when you exit. Run this in model space (or an active floating viewport).
