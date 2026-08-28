;;; interp-elev.lsp
;;; Linear elevation interpolation between two points (or along a polyline)
;;; with live elevation preview at the cursor.
;;;
;;; Command: INTERPELEV
;;;   1. Choose path type: Line or Polyline
;;;   2. Line: pick two points / Polyline: select a polyline
;;;   3. Elevations come from point/vertex Z values, unless missing
;;;   4. Move along the path; interpolated elevation previews live
;;;   5. Click to place a POINT at that elevation; Enter exits
;;;
;;; Sentinel Z values treated as missing elevation:
;;;   -0.999999 (and near-null Civil values like -99999)
;;;   Exact 0.0 is treated as a valid elevation.

(vl-load-com)

(defun interp--2d (pt)
  (if pt (list (car pt) (cadr pt)))
)

(defun interp--3d (pt / )
  (if pt
    (list (car pt) (cadr pt) (if (caddr pt) (caddr pt) 0.0))
  )
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
       (not (< z -90000.0))
  )
)

(defun interp--read-elev (label current / elev)
  (if (interp--valid-elev current)
    current
    (progn
      (setq elev
            (getreal
              (strcat
                "\nEnter elevation for "
                label
                (if (and current (numberp current))
                  (strcat " <Z=" (rtos current 2 4) " missing>: ")
                  ": "
                )
              )
            )
      )
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
  (if pt (interp--3d pt))
)

(defun interp--read-path-type (/ choice)
  (initget "Line Polyline")
  (setq choice (getkword "\nPath type [Line/Polyline] <Line>: "))
  (if (not choice) "Line" choice)
)

(defun interp--polyline-vertices (ename / obj elev pts i n pt)
  (setq obj  (vlax-ename->vla-object ename)
        elev (if (vlax-property-available-p obj 'Elevation)
               (vla-get-Elevation obj)
               0.0
             )
        pts  nil
        i    0
        n    (vlax-curve-getEndParam obj)
  )
  (while (<= i n)
    (setq pt (vlax-curve-getPointAtParam obj i))
    (if (and (caddr pt) (not (equal (caddr pt) 0.0 1e-12)))
      (setq pts (cons (interp--3d pt) pts))
      (setq pts (cons (list (car pt) (cadr pt) elev) pts))
    )
    (setq i (1+ i))
  )
  (reverse pts)
)

(defun interp--draw-callout (pt / p h)
  (setq p (interp--2d pt)
        h (* (getvar "VIEWSIZE") 0.012)
  )
  (grdraw p (list (+ (car p) h) (+ (cadr p) h)) 2 0)
  (grdraw
    (list (+ (car p) h) (+ (cadr p) h))
    (list (+ (car p) (* h 3.5)) (+ (cadr p) h))
    2
    0
  )
)

(defun interp--pick-polyline (/ ss ename)
  (princ "\nSelect a polyline path: ")
  (setq ss (ssget "_+.:E:S" '((0 . "LWPOLYLINE,POLYLINE"))))
  (if (and ss (> (sslength ss) 0))
    (progn
      (setq ename (ssname ss 0))
      (if (< (length (interp--polyline-vertices ename)) 2)
        (progn
          (princ "\nPolyline must have at least two vertices.")
          nil
        )
        ename
      )
    )
    (progn
      (princ "\nNo polyline selected.")
      nil
    )
  )
)

(defun interp--project-on-segment (a b p / ax ay bx by px py ab ap ab2 tval)
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
    (list ax ay 0.0 0.0)
    (progn
      (setq tval (/ (+ (* ap ab) (* (- py ay) (- by ay))) ab2))
      (if (< tval 0.0) (setq tval 0.0))
      (if (> tval 1.0) (setq tval 1.0))
      (list
        (+ ax (* tval ab))
        (+ ay (* tval (- by ay)))
        tval
        (sqrt (* tval tval ab2))
      )
    )
  )
)

(defun interp--project-on-curve (ename p / pt param dist total)
  (setq p     (interp--2d p)
        pt    (vlax-curve-getClosestPointTo ename p)
        param (vlax-curve-getParamAtPoint ename pt)
        dist  (vlax-curve-getDistAtParam ename param)
        total (vlax-curve-getDistAtParam ename (vlax-curve-getEndParam ename))
  )
  (list (car pt) (cadr pt) (if (> total 1e-12) (/ dist total) 0.0) dist total)
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
    "Elev: "
    (interp--format-elev z)
    "  Dist: "
    (interp--format-dist dist)
    "  ("
    (rtos (* tval 100.0) 2 2)
    "%)"
  )
)

(defun interp--draw-path-line (pt1 pt2 / )
  (grdraw (interp--2d pt1) (interp--2d pt2) 3 1)
)

(defun interp--draw-path-poly (verts / a b)
  (setq a (car verts)
        verts (cdr verts)
  )
  (while verts
    (setq b (car verts)
          verts (cdr verts)
    )
    (grdraw (interp--2d a) (interp--2d b) 3 1)
    (setq a b)
  )
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
  (if old-pt
    (progn
      (interp--draw-marker old-pt)
      (interp--draw-callout old-pt)
    )
  )
  (if new-pt
    (progn
      (interp--draw-marker new-pt)
      (interp--draw-callout new-pt)
    )
  )
)

(defun interp--place-point (pt / )
  (entmake
    (list
      '(0 . "POINT")
      '(100 . "AcDbEntity")
      '(100 . "AcDbPoint")
      (cons 10 pt)
    )
  )
)

(defun interp--safe-pick-pt (data / snap)
  (setq data (interp--2d data)
        snap (vl-catch-all-apply 'osnap (list data "_nea,_end,_mid,_int"))
  )
  (if (and snap (not (vl-catch-all-error-p snap)))
    (interp--2d snap)
    data
  )
)

(defun interp--track (path-type pt1 pt2 z1 z2 poly-ename / total done gr code data
                        proj tval dist z pct insert-pt old-proj old-z
                        result label poly)
  (setq poly  (if poly-ename (vlax-ename->vla-object poly-ename))
        total (if poly
                (vlax-curve-getDistAtParam poly (vlax-curve-getEndParam poly))
                (interp--distance pt1 pt2)
              )
        done   nil
        result nil
        old-proj nil
        old-z nil
  )
  (if (<= total 1e-8)
    (princ "\nPath length is zero; cannot interpolate.")
    (progn
      (princ
        (strcat
          "\nPath length = "
          (interp--format-dist total)
          ". Move along path for live elev. Click to place, Enter to exit."
        )
      )
      (if poly-ename
        (interp--draw-path-poly (interp--polyline-vertices poly-ename))
        (interp--draw-path-line pt1 pt2)
      )
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
              (if poly
                (setq proj (interp--project-on-curve poly data)
                      tval (caddr proj)
                      dist (nth 3 proj)
                      total (nth 4 proj)
                )
                (setq proj (interp--project-on-segment pt1 pt2 data)
                      tval (caddr proj)
                      dist (* tval total)
                )
              )
              (setq z (interp--elev-at z1 z2 tval)
                    pct tval
                    insert-pt (list (car proj) (cadr proj) z)
                    label (interp--status-text z dist tval)
              )
              (if (not (and old-proj
                            (equal (interp--2d insert-pt) (interp--2d old-proj) 1e-8)
                            (equal z old-z 1e-8)
                       )
                  )
                (progn
                  (interp--move-marker old-proj insert-pt)
                  (grtext -1 label)
                  (setq old-proj insert-pt
                        old-z    z
                  )
                )
              )
             )
             ((= code 3)
              (setq data (interp--safe-pick-pt data))
              (if poly
                (setq proj (interp--project-on-curve poly data)
                      tval (caddr proj)
                      dist (nth 3 proj)
                )
                (setq proj (interp--project-on-segment pt1 pt2 data)
                      tval (caddr proj)
                      dist (* tval total)
                )
              )
              (setq z (interp--elev-at z1 z2 tval)
                    insert-pt (list (car proj) (cadr proj) z)
              )
              (grtext -1 "")
              (redraw)
              (interp--place-point insert-pt)
              (princ
                (strcat
                  "\nPoint placed at elev "
                  (interp--format-elev z)
                  " (dist "
                  (interp--format-dist dist)
                  ")."
                )
              )
              (if poly-ename
                (interp--draw-path-poly (interp--polyline-vertices poly-ename))
                (interp--draw-path-line pt1 pt2)
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
              (setq data (interp--safe-pick-pt data))
              (if poly
                (setq proj (interp--project-on-curve poly data)
                      tval (caddr proj)
                      dist (nth 3 proj)
                )
                (setq proj (interp--project-on-segment pt1 pt2 data)
                      tval (caddr proj)
                      dist (* tval total)
                )
              )
              (setq z (interp--elev-at z1 z2 tval)
                    insert-pt (list (car proj) (cadr proj) z)
                    result insert-pt
              )
              (grtext -1 "")
              (redraw)
              (princ
                (strcat
                  "\nSelected elev "
                  (interp--format-elev z)
                  " at dist "
                  (interp--format-dist dist)
                  "."
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

(defun interp--run-line (/ pt1 pt2 z1 z2)
  (and
    (setq pt1 (interp--pick-point "\nPick first point: "))
    (setq z1 (interp--read-elev "first point" (caddr pt1)))
    (setq pt2 (interp--pick-point "\nPick second point: "))
    (setq z2 (interp--read-elev "second point" (caddr pt2)))
    (progn
      (princ
        (strcat
          "\nElev1 = "
          (interp--format-elev z1)
          ", Elev2 = "
          (interp--format-elev z2)
          ", length = "
          (interp--format-dist (interp--distance pt1 pt2))
          "."
        )
      )
      (interp--track
        "Line"
        (interp--2d pt1)
        (interp--2d pt2)
        z1
        z2
        nil
      )
      T
    )
  )
)

(defun interp--run-polyline (/ ename verts first last z1 z2)
  (setq ename (interp--pick-polyline))
  (if (not ename)
    nil
    (progn
      (setq verts (interp--polyline-vertices ename)
            first (car verts)
            last  (last verts)
            z1    (interp--read-elev "start of polyline" (caddr first))
            z2    (if z1 (interp--read-elev "end of polyline" (caddr last)))
      )
      (if (and z1 z2)
        (progn
          (princ
            (strcat
              "\nStart elev = "
              (interp--format-elev z1)
              ", end elev = "
              (interp--format-elev z2)
              ", length = "
              (interp--format-dist
                (vlax-curve-getDistAtParam
                  (vlax-ename->vla-object ename)
                  (vlax-curve-getEndParam (vlax-ename->vla-object ename))
                )
              )
              "."
            )
          )
          (interp--track
            "Polyline"
            (interp--2d first)
            (interp--2d last)
            z1
            z2
            ename
          )
          T
        )
        nil
      )
    )
  )
)

(defun c:INTERPELEV (/ *error* old-osmode path-type)
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

  (setq path-type (interp--read-path-type)
        osmode old-osmode
  )
  (if (= path-type "Polyline")
    (interp--run-polyline)
    (interp--run-line)
  )

  (grtext -1 "")
  (setq osmode old-osmode)
  (princ)
)

(princ "\nINTERPELEV loaded. Type INTERPELEV to interpolate elevations along a path.")
(princ)
