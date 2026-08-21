;;; staking-plot.lsp
;;; Creates a plot-boundary rectangle on the VIEW layer for staking setups.
;;;
;;; Command: STAKINGPLOT
;;;   1. Enter plot scale (drawing units per inch on paper; e.g. 20 for 1"=20')
;;;   2. Choose ANSI paper size (A, B, C, or D)
;;;   3. Choose paper orientation (Landscape or Portrait)
;;;   4. Pick the lower-left corner with a live bounding-box preview
;;;      Type S to change scale. After picking: Accept, Scale, or Move.
;;;   5. Optionally insert NORTH-ARROW.dwg at the plot scale
;;;   6. Create the VIEW layer rectangle and open the Plot window for preview/print
;;;
;;; Place NORTH-ARROW.dwg in the same folder as this LSP (or on the AutoCAD support path).
;;; ANSI sizes (long edge x short edge in inches):
;;;   A = 11 x 8.5, B = 17 x 11, C = 22 x 17, D = 34 x 22
;;; Portrait swaps width and height.

(vl-load-com)

(defun staking--ensure-view-layer (layer-name / )
  (if (not (tblsearch "LAYER" layer-name))
    (entmake
      (list
        '(0 . "LAYER")
        '(100 . "AcDbSymbolTableRecord")
        '(100 . "AcDbLayerTableRecord")
        (cons 2 layer-name)
        '(70 . 0)
        '(62 . 7)
        '(6 . "Continuous")
      )
    )
  )
)

(defun staking--paper-dimensions (paper-code / )
  (cond
    ((= paper-code "A") '(11.0 8.5))
    ((= paper-code "B") '(17.0 11.0))
    ((= paper-code "C") '(22.0 17.0))
    ((= paper-code "D") '(34.0 22.0))
    (T nil)
  )
)

(defun staking--read-scale (/ scale)
  (setq scale (getreal
                (strcat
                  "\nEnter plot scale <drawing units per inch on paper> "
                  "(e.g. 20 for 1\"=20'): "
                )
              ))
  (cond
    ((not scale)
     (princ "\nScale entry cancelled.")
     nil
    )
    ((<= scale 0.0)
     (princ "\nScale must be greater than zero.")
     nil
    )
    (T scale)
  )
)

(defun staking--read-paper-size (/ paper)
  (initget "A B C D")
  (setq paper (getkword "\nANSI paper size [A/B/C/D] <A>: "))
  (if (not paper) (setq paper "A"))
  paper
)

(defun staking--read-orientation (/ orientation)
  (initget "Landscape Portrait")
  (setq orientation (getkword "\nPaper orientation [Landscape/Portrait] <Landscape>: "))
  (if (not orientation) (setq orientation "Landscape"))
  orientation
)

(defun staking--oriented-dimensions (paper-inches orientation / width height)
  (setq width  (car paper-inches)
        height (cadr paper-inches)
  )
  (if (= orientation "Portrait")
    (list height width)
    (list width height)
  )
)

(defun staking--2d (pt)
  (if pt (list (car pt) (cadr pt)))
)

(defun staking--same-pt (a b)
  (and a b (equal (staking--2d a) (staking--2d b) 1e-8))
)

(defun staking--size-message (paper-code orientation paper-width paper-height scale rect-width rect-height)
  (strcat
    "\nANSI "
    paper-code
    " "
    orientation
    " ("
    (rtos paper-width 2 2)
    "\" x "
    (rtos paper-height 2 2)
    "\") at scale "
    (rtos scale 2 4)
    " = "
    (rtos rect-width 2 4)
    " x "
    (rtos rect-height 2 4)
    " drawing units."
  )
)

(defun staking--ghost-draw (pt width height / p1 p2 p3 p4)
  (if (and pt width height (> width 0.0) (> height 0.0))
    (progn
      (setq pt (staking--2d pt)
            p1 pt
            p2 (list (+ (car pt) width) (cadr pt))
            p3 (list (+ (car pt) width) (+ (cadr pt) height))
            p4 (list (car pt) (+ (cadr pt) height))
      )
      (grdraw p1 p2 -1 1)
      (grdraw p2 p3 -1 1)
      (grdraw p3 p4 -1 1)
      (grdraw p4 p1 -1 1)
    )
  )
)

(defun staking--ghost-move (old-pt old-w old-h new-pt new-w new-h)
  (if (not
        (and (staking--same-pt old-pt new-pt)
             old-w new-w (equal old-w new-w 1e-8)
             old-h new-h (equal old-h new-h 1e-8)
        )
      )
    (progn
      (staking--ghost-draw old-pt old-w old-h)
      (staking--ghost-draw new-pt new-w new-h)
    )
  )
  new-pt
)

(defun staking--read-scale-keep (current / scale)
  (setq scale (getreal (strcat "\nEnter plot scale <" (rtos current 2 4) ">: ")))
  (cond
    ((not scale) current)
    ((<= scale 0.0)
     (princ "\nScale must be greater than zero. Keeping previous scale.")
     current
    )
    (T scale)
  )
)

(defun staking--pick-osnap (pt / snap)
  (setq pt (staking--2d pt)
        snap (osnap pt "_end,_int,_mid,_cen,_nod,_qua,_ins,_nea")
  )
  (if snap (staking--2d snap) pt)
)

(defun staking--pick-boundary (scale paper-width paper-height paper-code orientation
                               / rect-width rect-height ghost-pt ghost-w ghost-h
                                 base-point done gr code data pt ch result)
  (setq rect-width  (* paper-width scale)
        rect-height (* paper-height scale)
        ghost-pt    nil
        ghost-w     rect-width
        ghost-h     rect-height
        base-point  nil
        done        nil
        result      nil
  )
  (princ "\nPick lower-left corner of plot boundary [Scale]: ")
  (while (not done)
    (setq gr (vl-catch-all-apply 'grread (list T 15 0)))
    (cond
      ((or (not gr) (vl-catch-all-error-p gr))
       (redraw)
       (princ "\nPoint entry cancelled.")
       (setq done T)
      )
      (T
       (setq code (car gr)
             data (cadr gr)
       )
       (cond
         ((= code 5)
          (if (not base-point)
            (progn
              (setq pt (staking--2d data)
                    ghost-pt (staking--ghost-move ghost-pt ghost-w ghost-h pt rect-width rect-height)
                    ghost-w rect-width
                    ghost-h rect-height
              )
            )
          )
         )
         ((= code 3)
          (setq base-point (staking--pick-osnap data)
                ghost-pt (staking--ghost-move ghost-pt ghost-w ghost-h base-point rect-width rect-height)
                ghost-w rect-width
                ghost-h rect-height
          )
          (princ "\nAccept plot boundary [Accept/Scale/Move] <Accept>: ")
         )
         ((or (= code 11) (= code 25))
          (if base-point
            (progn
              (redraw)
              (setq done T result (list base-point scale))
            )
          )
         )
         ((= code 2)
          (setq ch data)
          (cond
            ((or (= ch 83) (= ch 115))
             (redraw)
             (setq ghost-pt nil
                   scale (staking--read-scale-keep scale)
                   rect-width (* paper-width scale)
                   rect-height (* paper-height scale)
             )
             (princ
               (staking--size-message
                 paper-code orientation paper-width paper-height
                 scale rect-width rect-height
               )
             )
             (if base-point
               (progn
                 (staking--ghost-draw base-point rect-width rect-height)
                 (setq ghost-pt base-point
                       ghost-w rect-width
                       ghost-h rect-height
                 )
                 (princ "\nAccept plot boundary [Accept/Scale/Move] <Accept>: ")
               )
               (princ "\nPick lower-left corner of plot boundary [Scale]: ")
             )
            )
            ((and base-point (or (= ch 13) (= ch 32) (= ch 65) (= ch 97)))
             (redraw)
             (setq done T result (list base-point scale))
            )
            ((and base-point (or (= ch 77) (= ch 109)))
             (setq base-point nil)
             (princ "\nPick lower-left corner of plot boundary [Scale]: ")
            )
          )
         )
       )
      )
    )
  )
  result
)

(defun staking--bounds (base-point width height / x0 y0)
  (setq x0 (car base-point)
        y0 (cadr base-point)
  )
  (list (list x0 y0) (list (+ x0 width) (+ y0 height)))
)

(defun staking--ansi-media-name (paper-code orientation / )
  (cond
    ((and (= paper-code "A") (= orientation "Landscape")) "ANSI A (11.00 x 8.50 Inches)")
    ((and (= paper-code "A") (= orientation "Portrait"))  "ANSI A (8.50 x 11.00 Inches)")
    ((and (= paper-code "B") (= orientation "Landscape")) "ANSI B (17.00 x 11.00 Inches)")
    ((and (= paper-code "B") (= orientation "Portrait"))  "ANSI B (11.00 x 17.00 Inches)")
    ((and (= paper-code "C") (= orientation "Landscape")) "ANSI C (22.00 x 17.00 Inches)")
    ((and (= paper-code "C") (= orientation "Portrait"))  "ANSI C (17.00 x 22.00 Inches)")
    ((and (= paper-code "D") (= orientation "Landscape")) "ANSI D (34.00 x 22.00 Inches)")
    ((and (= paper-code "D") (= orientation "Portrait"))  "ANSI D (22.00 x 34.00 Inches)")
    (T nil)
  )
)

(defun staking--plot-warning (err-msg)
  (if err-msg
    (princ (strcat "\nPlot setup warning: " err-msg))
  )
)

(defun staking--get-canonical-media-names (layout / names err)
  (setq err (vl-catch-all-apply 'vla-RefreshPlotDeviceInfo (list layout)))
  (if (vl-catch-all-error-p err)
    (progn
      (staking--plot-warning (vl-catch-all-error-message err))
      nil
    )
    (progn
      (setq names
            (vl-catch-all-apply 'vla-GetCanonicalMediaNames (list layout))
      )
      (if (vl-catch-all-error-p names)
        (progn
          (staking--plot-warning (vl-catch-all-error-message names))
          nil
        )
        (vlax-safearray->list (vlax-variant-value names))
      )
    )
  )
)

(defun staking--match-media-name (layout paper-code orientation / target names dims w h dim-a dim-b name)
  (setq target (staking--ansi-media-name paper-code orientation)
        names  (staking--get-canonical-media-names layout)
        dims   (staking--oriented-dimensions
                  (staking--paper-dimensions paper-code)
                  orientation
                )
        w      (rtos (car dims) 2 2)
        h      (rtos (cadr dims) 2 2)
        dim-a  (strcat w "_x_" h)
        dim-b  (strcat w " x " h)
  )
  (cond
    ((and target (member target names)) target)
    ((and names
          (setq name
                (car
                  (vl-remove-if-not
                    '(lambda (item)
                       (and (vl-string-search (strcat "ANSI " paper-code) item)
                            (or (vl-string-search dim-a item)
                                (vl-string-search dim-b item)
                            )
                       )
                     )
                    names
                  )
                )
          )
     )
     name
    )
    ((and names
          (setq name
                (car
                  (vl-remove-if-not
                    '(lambda (item)
                       (vl-string-search (strcat "ANSI " paper-code) item)
                     )
                    names
                  )
                )
          )
     )
     name
    )
    (T nil)
  )
)

(defun staking--put-plot-property (layout property args / err)
  (setq err (vl-catch-all-apply property (cons layout args)))
  (if (vl-catch-all-error-p err)
    (staking--plot-warning (vl-catch-all-error-message err))
  )
)

(defun staking--configure-plot (ll ur scale orientation paper-code / acad doc layout
                                 config-name media ll-pt ur-pt)
  (setq acad   (vlax-get-acad-object)
        doc    (vla-get-ActiveDocument acad)
        layout (vla-get-ActiveLayout doc)
        config-name (vla-get-ConfigName layout)
        ll-pt  (vlax-3d-point (list (car ll) (cadr ll) 0.0))
        ur-pt  (vlax-3d-point (list (car ur) (cadr ur) 0.0))
  )
  (if (or (not config-name) (= config-name "") (= config-name "None"))
    (princ "\nNo plotter configured yet. Set printer/paper size in the Plot dialog.")
    (progn
      (setq media (staking--match-media-name layout paper-code orientation))
      (if media
        (staking--put-plot-property layout 'vla-put-CanonicalMediaName (list media))
        (princ "\nCould not match ANSI paper on the current plotter; set paper size in Plot dialog.")
      )
    )
  )
  (staking--put-plot-property layout 'vla-SetWindowToPlot (list ll-pt ur-pt))
  (staking--put-plot-property layout 'vla-put-PlotType (list 5))
  (staking--put-plot-property layout 'vla-put-CenterPlot (list :vlax-false))
  (staking--put-plot-property layout 'vla-put-UseStandardScale (list :vlax-false))
  (staking--put-plot-property layout 'vla-put-CustomScaleNumerator (list (float scale)))
  (staking--put-plot-property layout 'vla-put-CustomScaleDenominator (list 1.0))
  (staking--put-plot-property layout 'vla-put-PlotRotation (list 0))
  T
)

(defun staking--open-plot-window ( / plot-result)
  (princ "\nOpening plot window. Review settings, preview, then press Print.")
  (setq plot-result
        (vl-catch-all-apply '(lambda () (command "_.PLOT")))
  )
  (if (vl-catch-all-error-p plot-result)
    (progn
      (princ "\nPLOT command failed; trying PRINT...")
      (vl-catch-all-apply '(lambda () (command "_.PRINT")))
    )
  )
)

(defun staking--plot-rectangle (base-point rect-width rect-height scale orientation paper-code / bounds)
  (setq bounds (staking--bounds base-point rect-width rect-height))
  (staking--configure-plot
    (car bounds)
    (cadr bounds)
    scale
    orientation
    paper-code
  )
  (staking--open-plot-window)
)

(defun staking--draw-rectangle (base-point width height layer-name / x0 y0 x1 y1)
  (setq x0 (car base-point)
        y0 (cadr base-point)
        x1 (+ x0 width)
        y1 (+ y0 height)
  )
  (entmakex
    (list
      '(0 . "LWPOLYLINE")
      '(100 . "AcDbEntity")
      (cons 8 layer-name)
      '(100 . "AcDbPolyline")
      '(90 . 4)
      '(70 . 1)
      (cons 10 (list x0 y0))
      (cons 10 (list x1 y0))
      (cons 10 (list x1 y1))
      (cons 10 (list x0 y1))
    )
  )
)

(defun staking--path-join (dir name / sep)
  (setq sep (if (wcmatch dir "*\\*") "\\" "/"))
  (if (or (wcmatch dir "*\\") (wcmatch dir "*/"))
    (strcat dir name)
    (strcat dir sep name)
  )
)

(defun staking--north-arrow-path (/ found lsp dir candidate)
  (setq found (findfile "NORTH-ARROW.dwg"))
  (if found
    found
    (progn
      (setq lsp (findfile "staking-plot.lsp"))
      (if lsp
        (progn
          (setq dir (vl-filename-directory lsp)
                candidate (staking--path-join dir "NORTH-ARROW.dwg")
          )
          (if (findfile candidate) candidate nil)
        )
        nil
      )
    )
  )
)

(defun staking--insert-north-arrow (scale / path pt old-attreq old-cmdecho insert-result)
  (initget "Yes No")
  (if (= (getkword "\nInsert north arrow? [Yes/No] <Yes>: ") "No")
    nil
    (progn
      (setq path (staking--north-arrow-path))
      (cond
        ((not path)
         (princ "\nNORTH-ARROW.dwg not found. Place it next to staking-plot.lsp or on the support path.")
         nil
        )
        ((not (setq pt (getpoint "\nPick north arrow insertion point: ")))
         (princ "\nNorth arrow insertion cancelled.")
         nil
        )
        (T
         (setq old-attreq  (getvar "ATTREQ")
               old-cmdecho (getvar "CMDECHO")
               pt          (staking--2d pt)
         )
         (setvar "ATTREQ" 0)
         (setvar "CMDECHO" 0)
         (setq insert-result
               (vl-catch-all-apply
                 '(lambda ()
                    (command "_.-INSERT" path pt (float scale) (float scale) 0.0)
                  )
               )
         )
         (setvar "ATTREQ" old-attreq)
         (setvar "CMDECHO" old-cmdecho)
         (if (vl-catch-all-error-p insert-result)
           (princ
             (strcat
               "\nUnable to insert north arrow: "
               (vl-catch-all-error-message insert-result)
             )
           )
           (princ "\nNorth arrow inserted.")
         )
         T
        )
      )
    )
  )
)

(defun c:STAKINGPLOT (/ *error* old-cmdecho old-osmode layer-name scale
                        paper-code orientation paper-inches paper-width
                        paper-height rect-width rect-height pick base-point result)
  (setq *error*
        (lambda (msg)
          (if (and msg (not (member msg '("Function cancelled" "quit / exit abort"))))
            (princ (strcat "\nError: " msg))
          )
          (redraw)
          (if old-cmdecho (setq cmdecho old-cmdecho))
          (if old-osmode (setq osmode old-osmode))
          (princ)
        )
        old-cmdecho cmdecho
        old-osmode   osmode
        layer-name   "VIEW"
  )

  (setq cmdecho 0)

  (if
    (and
      (setq scale (staking--read-scale))
      (setq paper-code (staking--read-paper-size))
      (setq orientation (staking--read-orientation))
      (setq paper-inches (staking--paper-dimensions paper-code))
      (setq paper-inches (staking--oriented-dimensions paper-inches orientation)
            paper-width  (car paper-inches)
            paper-height (cadr paper-inches)
            rect-width   (* paper-width scale)
            rect-height  (* paper-height scale)
      )
    )
    (progn
      (princ
        (staking--size-message
          paper-code orientation paper-width paper-height
          scale rect-width rect-height
        )
      )
      (setq osmode old-osmode
            pick (staking--pick-boundary
                   scale paper-width paper-height paper-code orientation
                 )
      )
      (if pick
        (progn
          (setq base-point  (car pick)
                scale       (cadr pick)
                rect-width  (* paper-width scale)
                rect-height (* paper-height scale)
          )
          (staking--ensure-view-layer layer-name)
          (setq result (staking--draw-rectangle base-point rect-width rect-height layer-name))
          (if result
            (progn
              (princ
                (strcat
                  "\nPlot boundary created on layer "
                  layer-name
                  "."
                )
              )
              (staking--insert-north-arrow scale)
              (setq cmdecho 1)
              (staking--plot-rectangle base-point rect-width rect-height scale orientation paper-code)
            )
            (princ "\nUnable to create plot boundary.")
          )
        )
      )
    )
  )

  (setq cmdecho old-cmdecho
        osmode   old-osmode
  )
  (princ)
)

(princ "\nSTAKINGPLOT loaded. Type STAKINGPLOT to create a staking plot boundary.")
(princ)
