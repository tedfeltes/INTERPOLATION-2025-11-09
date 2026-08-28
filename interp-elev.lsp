;;; interp-elev.lsp
;;; Linear elevation interpolation between two points (or along a polyline)
;;; with live elevation preview at the cursor.
;;;
;;; Command: INTERPELEV
;;;   Mode Interpolate:
;;;     1. Choose path type: Line or Polyline
;;;     2. Pick endpoints / select polyline and set elevations
;;;     3. Osnap and pick along path for live interpolated elevation
;;;   Mode Hover:
;;;     1. Move cursor over entities with osnaps
;;;     2. Entity elevation displays next to the cursor when Z exists
;;;     Enter exits either mode
;;;
;;; Sentinel Z values treated as missing elevation:
;;;   -0.999999 (and near-null Civil values like -99999)
;;;   Exact 0.0 is treated as a valid elevation.

(vl-load-com)

(setq *interp-context* nil)

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

(defun interp--read-tool-mode (/ choice)
  (initget "Interpolate Hover")
  (setq choice (getkword "\nTool mode [Interpolate/Hover] <Interpolate>: "))
  (if (not choice) "Interpolate" choice)
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

(defun interp--osnap-pt (pt / snap)
  (if pt
    (progn
      (setq snap (vl-catch-all-apply 'osnap (list (interp--2d pt) "")))
      (if (and snap (not (vl-catch-all-error-p snap)))
        (interp--2d snap)
        (interp--2d pt)
      )
    )
  )
)

(defun interp--sample-at (pt / ctx pt1 pt2 z1 z2 poly-ename total proj tval dist z)
  (if (and *interp-context* pt)
    (progn
      (setq ctx        *interp-context*
            pt1        (nth 0 ctx)
            pt2        (nth 1 ctx)
            z1         (nth 2 ctx)
            z2         (nth 3 ctx)
            poly-ename (nth 4 ctx)
            total      (nth 5 ctx)
            pt         (interp--osnap-pt pt)
      )
      (if poly-ename
        (setq proj  (interp--project-on-curve poly-ename pt)
              tval  (caddr proj)
              dist  (nth 3 proj)
              total (nth 4 proj)
        )
        (setq proj (interp--project-on-segment pt1 pt2 pt)
              tval (caddr proj)
              dist (* tval total)
        )
      )
      (setq z (interp--elev-at z1 z2 tval))
      (list (list (car proj) (cadr proj) z) z dist tval)
    )
  )
)

(defun interp--live-tracker (cursor / sample)
  (if (and *interp-context* cursor)
    (progn
      (setq sample (interp--sample-at cursor))
      (if sample
        (grtext -1 (interp--status-text (nth 1 sample) (nth 2 sample) (nth 3 sample)))
      )
    )
  )
)

(defun interp--cursor-label-pt (pt / offset)
  (setq pt (interp--2d pt)
        offset (* (getvar "VIEWSIZE") 0.012)
  )
  (list (+ (car pt) offset) (+ (cadr pt) offset))
)

(defun interp--curve-elev-at (ename pt / cpt z obj elev)
  (setq cpt (vl-catch-all-apply 'vlax-curve-getClosestPointTo (list ename pt)))
  (if (vl-catch-all-error-p cpt)
    nil
    (progn
      (setq z (caddr cpt))
      (if (interp--valid-elev z)
        z
        (progn
          (setq obj (vlax-ename->vla-object ename))
          (if (and (vlax-property-available-p obj 'Elevation)
                   (interp--valid-elev (setq elev (vla-get-Elevation obj))))
            elev
            nil
          )
        )
      )
    )
  )
)

(defun interp--elev-from-entity (ename pt / typ elst z obj elev)
  (setq typ (cdr (assoc 0 (setq elst (entget ename))))
  (cond
    ((wcmatch typ "LINE,ARC,CIRCLE,*POLYLINE*,SPLINE,ELLIPSE")
     (interp--curve-elev-at ename pt)
    )
    ((= typ "POINT")
     (setq z (caddr (cdr (assoc 10 elst))))
     (if (interp--valid-elev z) z nil)
    )
    ((member typ '("INSERT" "TEXT" "MTEXT" "ATTRIB"))
     (setq z (caddr (cdr (assoc 10 elst))))
     (if (interp--valid-elev z) z nil)
    )
    ((= typ "3DFACE")
     (setq z (caddr (cdr (assoc 10 elst))))
     (if (interp--valid-elev z) z nil)
    )
    (T
     (interp--curve-elev-at ename pt)
    )
  )
)

(defun interp--probe-hover (cursor / snap nest ent pick z label-pt typ)
  (setq snap (interp--osnap-pt cursor))
  (if (and snap (setq nest (nentselp snap)))
    (progn
      (setq ent      (car nest)
            pick     (nth 1 nest)
            z        (interp--elev-from-entity ent pick)
            typ      (cdr (assoc 0 (entget ent)))
            label-pt (interp--cursor-label-pt snap)
      )
      (if z
        (list z label-pt typ snap)
        nil
      )
    )
  )
)

(defun interp--hover-label (z / )
  (strcat "Elev: " (interp--format-elev z))
)

(defun interp--clear-hover-label (label-pt / )
  (if label-pt (grtext label-pt ""))
  (grtext -1 "")
)

(defun interp--run-hover (/ done gr code data probe old-label-pt label text)
  (princ "\nHover over entities. Osnap applies. Enter to exit.")
  (setq done nil old-label-pt nil)
  (while (not done)
    (setq gr (vl-catch-all-apply 'grread (list T 15 0)))
    (cond
      ((or (not gr) (vl-catch-all-error-p gr))
       (setq done T)
      )
      (T
       (setq code (car gr)
             data (cadr gr)
       )
       (cond
         ((= code 5)
          (if (setq probe (interp--probe-hover data))
            (progn
              (setq label (nth 1 probe)
                    text  (interp--hover-label (car probe))
              )
              (if (not (equal label old-label-pt 1e-8))
                (progn
                  (interp--clear-hover-label old-label-pt)
                  (grtext label text)
                  (setq old-label-pt label)
                )
              )
              (grtext -1 (strcat text "  " (nth 2 probe)))
            )
            (progn
              (interp--clear-hover-label old-label-pt)
              (setq old-label-pt nil)
            )
          )
         )
         ((and (= code 2) (member data '(13 32)))
          (setq done T)
         )
         ((= code 3)
          (if (setq probe (interp--probe-hover data))
            (princ
              (strcat
                "\n"
                (interp--hover-label (car probe))
                " on "
                (nth 2 probe)
                "."
              )
            )
          )
         )
       )
      )
    )
  )
  (interp--clear-hover-label old-label-pt)
  (princ "\nHover ended.")
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

(defun interp--track (pt1 pt2 z1 z2 poly-ename / total pick sample insert-pt z dist)
  (setq total (if poly-ename
                (vlax-curve-getDistAtParam
                  (vlax-ename->vla-object poly-ename)
                  (vlax-curve-getEndParam (vlax-ename->vla-object poly-ename))
                )
                (interp--distance pt1 pt2)
              )
  )
  (if (<= total 1e-8)
    (princ "\nPath length is zero; cannot interpolate.")
    (progn
      (setq *interp-context* (list pt1 pt2 z1 z2 poly-ename total))
      (princ
        (strcat
          "\nPath length = "
          (interp--format-dist total)
          ". Osnap and pick along path; live elev at cursor. Enter to exit."
        )
      )
      (while
        (setq pick
              (getpoint nil "\nPick point along path: " 'interp--live-tracker)
        )
        (setq sample    (interp--sample-at pick)
              insert-pt (car sample)
              z         (nth 1 sample)
              dist      (nth 2 sample)
        )
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
      )
      (setq *interp-context* nil)
      (grtext -1 "")
    )
  )
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

(defun c:INTERPELEV (/ *error* old-osmode tool-mode path-type)
  (setq *error*
        (lambda (msg)
          (setq *interp-context* nil)
          (grtext -1 "")
          (if (and msg (not (member msg '("Function cancelled" "quit / exit abort"))))
            (princ (strcat "\nError: " msg))
          )
          (if old-osmode (setq osmode old-osmode))
          (princ)
        )
        old-osmode osmode
  )

  (setq tool-mode (interp--read-tool-mode)
        osmode    old-osmode
  )
  (if (= tool-mode "Hover")
    (interp--run-hover)
    (progn
      (setq path-type (interp--read-path-type))
      (if (= path-type "Polyline")
        (interp--run-polyline)
        (interp--run-line)
      )
    )
  )

  (grtext -1 "")
  (setq *interp-context* nil)
  (setq osmode old-osmode)
  (princ)
)

(princ "\nINTERPELEV loaded. Type INTERPELEV to interpolate elevations along a path.")
(princ)
