;;; staking-plot.lsp
;;; Creates a plot-boundary rectangle on the VIEW layer for staking setups.
;;;
;;; Command: STAKINGPLOT
;;;   1. Enter plot scale (drawing units per inch on paper; e.g. 20 for 1"=20')
;;;   2. Choose ANSI paper size (A, B, C, or D)
;;;   3. Choose paper orientation (Landscape or Portrait)
;;;   4. Pick the lower-left corner of the rectangle in model space
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
        (princ
          (strcat
            "\nPlot boundary created on layer "
            layer-name
            "."
          )
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
