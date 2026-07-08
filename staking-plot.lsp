;;; staking-plot.lsp
;;; Creates a plot-boundary rectangle on the VIEW layer for staking setups.
;;;
;;; Command: STAKINGPLOT
;;;   1. Enter plot scale (drawing units per inch on paper; e.g. 20 for 1"=20')
;;;   2. Choose ANSI paper size (A, B, C, or D)
;;;   3. Choose paper orientation (Landscape or Portrait)
;;;   4. Pick the lower-left corner of the rectangle in model space
;;;   5. Create the VIEW layer rectangle and open the Plot window for preview/print
;;;
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

(defun staking--read-base-point (/ pt)
  (setq pt (getpoint "\nPick lower-left corner of plot boundary: "))
  (if (not pt)
    (princ "\nPoint entry cancelled.")
  )
  pt
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

(defun c:STAKINGPLOT (/ *error* old-cmdecho old-osmode layer-name scale
                        paper-code orientation paper-inches paper-width
                        paper-height rect-width rect-height base-point result)
  (setq *error*
        (lambda (msg)
          (if (and msg (not (member msg '("Function cancelled" "quit / exit abort"))))
            (princ (strcat "\nError: " msg))
          )
          (if old-cmdecho (setq cmdecho old-cmdecho))
          (if old-osmode (setq osmode old-osmode))
          (princ)
        )
        old-cmdecho cmdecho
        old-osmode   osmode
        layer-name   "VIEW"
  )

  (setq cmdecho 0
        osmode   0
  )

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
      (progn
        (princ
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
        T
      )
      (setq base-point (staking--read-base-point))
    )
    (progn
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
          (setq cmdecho 1)
          (staking--plot-rectangle base-point rect-width rect-height scale orientation paper-code)
        )
        (princ "\nUnable to create plot boundary.")
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
