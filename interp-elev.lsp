;;; interp-elev.lsp
;;; Linear elevation interpolation between two points with live preview.
;;;
;;; Command: INTERPELEV
;;;   1. Pick first point (uses Z unless missing or sentinel value)
;;;   2. Pick second point (uses Z unless missing or sentinel value)
;;;   3. Move cursor along the path; interpolated elevation previews live
;;;   4. Click to place a point at the interpolated elevation
;;;      Enter / Space / right-click exits
;;;
;;; Sentinel Z values treated as missing elevation:
;;;   -0.999999 and 0.0

(vl-load-com)

(defun interp--2d (pt)
  (if pt (list (car pt) (cadr pt)))
)

(defun interp--distance (a b / dx dy)
  (setq a (interp--2d a)
        b (interp--2d b)
        dx (- (car b) (car a))
        dy (- (cadr b) (cadr a))
  )
  (sqrt (+ (* dx dx) (* dy dy)))
)

(defun interp--valid-elev (z / )
  (and z
       (numberp z)
       (not (equal z -0.999999 1e-6))
       (not (equal z 0.0 1e-6))
  )
)

(defun interp--read-elev (label current / elev)
  (if (interp--valid-elev current)
    current
    (progn
      (setq elev (getreal (strcat "\nEnter elevation for " label ": ")))
      (if (not elev)
        (progn
          (princ (strcat "\nElevation entry cancelled for " label "."))
          nil
        )
        elev
      )
    )
  )
)

(defun interp--pick-point (prompt / pt)
  (setq pt (getpoint prompt))
  (if pt (list (car pt) (cadr pt) (if (caddr pt) (caddr pt) 0.0)))
)

(defun interp--project-on-segment (a b p / ax ay bx by px py ab ap ab2 tval qx qy)
  (setq a  (interp--2d a)
        b  (interp--2d b)
        p  (interp--2d p)
        ax (car a)  ay (cadr a)
        bx (car b)  by (cadr b)
        px (car p)  py (cadr p)
        ab (- bx ax)
        ap (- px ax)
        ab2 (+ (* ab ab) (* (- by ay) (- by ay)))
  )
  (if (<= ab2 1e-12)
    (list ax ay 0.0)
    (progn
      (setq tval (/ (+ (* ap ab) (* (- py ay) (- by ay))) ab2))
      (if (< tval 0.0) (setq tval 0.0))
      (if (> tval 1.0) (setq tval 1.0))
      (list (+ ax (* tval ab)) (+ ay (* tval (- by ay))) tval)
    )
  )
)

(defun interp--elev-at (z1 z2 tval)
  (+ z1 (* tval (- z2 z1)))
)

(defun interp--format-elev (z / )
  (rtos z 2 4)
)

(defun interp--format-dist (d / )
  (rtos d 2 4)
)

(defun interp--status-text (z dist tval / )
  (strcat
    "Interpolated elev: "
    (interp--format-elev z)
    "  Dist: "
    (interp--format-dist dist)
    "  ("
    (rtos (* tval 100.0) 2 2)
    "%)"
  )
)

(defun interp--draw-path (pt1 pt2 / )
  (grdraw (interp--2d pt1) (interp--2d pt2) 3 1)
)

(defun interp--draw-marker (pt / p size)
  (setq p    (interp--2d pt)
        size (* (getvar "VIEWSIZE") 0.004)
  )
  (grdraw p (list (+ (car p) size) (cadr p)) 1 1)
  (grdraw p (list (- (car p) size) (cadr p)) 1 1)
  (grdraw p (list (car p) (+ (cadr p) size)) 1 1)
  (grdraw p (list (car p) (- (cadr p) size)) 1 1)
)

(defun interp--move-marker (old-pt new-pt / )
  (if old-pt (interp--draw-marker old-pt))
  (if new-pt (interp--draw-marker new-pt))
)

(defun interp--track-elevations (pt1 pt2 z1 z2 / total len done gr code data proj
                                   tval dist z pct old-proj old-z old-dist old-pct
                                   insert-pt result)
  (setq total (interp--distance pt1 pt2)
        done  nil
        result nil
  )
  (if (<= total 1e-8)
    (princ "\nPoints are coincident; cannot interpolate.")
    (progn
      (princ
        (strcat
          "\nPath length = "
          (interp--format-dist total)
          ". Move cursor along path, click to place point, Enter to exit."
        )
      )
      (setq old-proj nil
            old-z    nil
            old-dist nil
            old-pct  nil
      )
      (interp--draw-path pt1 pt2)
      (while (not done)
        (setq gr (vl-catch-all-apply 'grread (list T 15 0)))
        (cond
          ((or (not gr) (vl-catch-all-error-p gr))
           (grtext -1 "")
           (redraw)
           (princ "\nInterpolation ended.")
           (setq done T)
          )
          (T
           (setq code (car gr)
                 data (cadr gr)
           )
           (cond
             ((= code 5)
              (setq proj (interp--project-on-segment pt1 pt2 data)
                    tval (caddr proj)
                    dist (* tval total)
                    z    (interp--elev-at z1 z2 tval)
                    pct  tval
                    insert-pt (list (car proj) (cadr proj) z)
              )
              (if (not (and old-proj
                            (equal (interp--2d insert-pt) (interp--2d old-proj) 1e-8)
                            (equal z old-z 1e-8)
                       )
                  )
                (progn
                  (interp--move-marker old-proj insert-pt)
                  (grtext -1 (interp--status-text z dist pct))
                  (setq old-proj insert-pt
                        old-z    z
                        old-dist dist
                        old-pct  pct
                  )
                )
              )
             )
             ((= code 3)
              (setq proj (interp--project-on-segment pt1 pt2 (osnap (interp--2d data) "_nearest"))
                    tval (caddr proj)
                    dist (* tval total)
                    z    (interp--elev-at z1 z2 tval)
                    insert-pt (list (car proj) (cadr proj) z)
              )
              (grtext -1 "")
              (redraw)
              (entmake
                (list
                  '(0 . "POINT")
                  '(100 . "AcDbEntity")
                  '(100 . "AcDbPoint")
                  (cons 10 insert-pt)
                )
              )
              (princ
                (strcat
                  "\nPoint placed at elevation "
                  (interp--format-elev z)
                  " (dist "
                  (interp--format-dist dist)
                  " from first point)."
                )
              )
              (setq old-proj nil)
             )
             ((= code 2)
              (if (or (= data 13) (= data 32))
                (progn
                  (grtext -1 "")
                  (redraw)
                  (princ "\nInterpolation ended.")
                  (setq done T)
                )
              )
             )
             ((or (= code 11) (= code 25))
              (setq proj (interp--project-on-segment pt1 pt2 data)
                    tval (caddr proj)
                    dist (* tval total)
                    z    (interp--elev-at z1 z2 tval)
                    insert-pt (list (car proj) (cadr proj) z)
                    result insert-pt
              )
              (grtext -1 "")
              (redraw)
              (princ
                (strcat
                  "\nSelected elevation "
                  (interp--format-elev z)
                  " at dist "
                  (interp--format-dist dist)
                  " from first point."
                )
              )
              (setq done T)
             )
           )
          )
        )
      )
    )
  )
  result
)

(defun c:INTERPELEV (/ *error* old-osmode pt1 pt2 z1 z2)
  (setq *error*
        (lambda (msg)
          (grtext -1 "")
          (redraw)
          (if (and msg (not (member msg '("Function cancelled" "quit / exit abort"))))
            (princ (strcat "\nError: " msg))
          )
          (if old-osmode (setq osmode old-osmode))
          (princ)
        )
        old-osmode osmode
  )

  (if
    (and
      (setq pt1 (interp--pick-point "\nPick first point: "))
      (setq z1 (interp--read-elev "first point" (caddr pt1)))
      (setq pt2 (interp--pick-point "\nPick second point: "))
      (setq z2 (interp--read-elev "second point" (caddr pt2)))
    )
    (progn
      (princ
        (strcat
          "\nFirst elevation = "
          (interp--format-elev z1)
          ", second elevation = "
          (interp--format-elev z2)
          ", path length = "
          (interp--format-dist (interp--distance pt1 pt2))
          "."
        )
      )
      (setq osmode old-osmode)
      (interp--track-elevations
        (list (car pt1) (cadr pt1))
        (list (car pt2) (cadr pt2))
        z1
        z2
      )
    )
  )

  (grtext -1 "")
  (setq osmode old-osmode)
  (princ)
)

(princ "\nINTERPELEV loaded. Type INTERPELEV to interpolate elevations along a path.")
(princ)
