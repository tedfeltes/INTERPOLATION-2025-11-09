;;; ZHOVER.lsp
;;; Civil 3D / AutoCAD - live elevation readout at the cursor.
;;;
;;; Command: ZHOVER   (alias ZH)
;;;   Hover any entity. The elevation at that spot is drawn next to the
;;;   cursor as italic magenta digits (000.00) on a color-251 rectangle
;;;   at 75% opacity. Click prints the value on the command line.
;;;   Esc, Enter, Space, or right-click to finish.
;;;
;;; Load with APPLOAD, or (load "ZHOVER.lsp") from acaddoc.lsp.

(vl-load-com)

(setq *zhover-label*    nil
      *zhover-box*      nil
      *zhover-last-str* nil
      *zhover-last-h*   nil
      *zhover-relbox*   nil
)

(defun zhover--try (fn args / res)
  (setq res (vl-catch-all-apply fn args))
  (if (vl-catch-all-error-p res) nil res)
)

(defun zhover--ptz (pt)
  (if (and pt (caddr pt)) (caddr pt) 0.0)
)

(defun zhover--as-3d (pt)
  (if pt
    (list (car pt) (cadr pt) (zhover--ptz pt))
  )
)

(defun zhover--com-pt (val)
  (cond
    ((null val) nil)
    ((vl-consp val) val)
    ((= (type val) 'VARIANT)
     (zhover--com-pt (zhover--try 'vlax-variant-value (list val)))
    )
    ((= (type val) 'SAFEARRAY)
     (zhover--try 'vlax-safearray->list (list val))
    )
  )
)

(defun zhover--vla-pt (obj names / name val)
  (foreach name names
    (if (not val)
      (setq val (zhover--com-pt (zhover--try 'vlax-get (list obj name))))
    )
  )
  val
)

(defun zhover--format-z (z)
  (rtos z 2 2)
)

;; Barycentric Z on triangle ABC, using XY of pick point P (WCS).
;; Returns nil when P is outside the triangle or the face is vertical.
(defun zhover--bary-z (a b c p / v0x v0y v1x v1y v2x v2y d00 d01 d11 d02 d12 den u v w)
  (setq v0x (- (car b) (car a))
        v0y (- (cadr b) (cadr a))
        v1x (- (car c) (car a))
        v1y (- (cadr c) (cadr a))
        v2x (- (car p) (car a))
        v2y (- (cadr p) (cadr a))
        d00 (+ (* v0x v0x) (* v0y v0y))
        d01 (+ (* v0x v1x) (* v0y v1y))
        d11 (+ (* v1x v1x) (* v1y v1y))
        d02 (+ (* v0x v2x) (* v0y v2y))
        d12 (+ (* v1x v2x) (* v1y v2y))
        den (- (* d00 d11) (* d01 d01))
  )
  (if (equal den 0.0 1e-12)
    nil
    (progn
      (setq u (/ (- (* d11 d02) (* d01 d12)) den)
            v (/ (- (* d00 d12) (* d01 d02)) den)
            w (- 1.0 u v)
      )
      (if (and (>= u -1e-6) (>= v -1e-6) (>= w -1e-6))
        (+ (* w (zhover--ptz a)) (* u (zhover--ptz b)) (* v (zhover--ptz c)))
      )
    )
  )
)

(defun zhover--face-z (en p-ucs / e a b c d p z)
  (setq e (entget en)
        a (cdr (assoc 10 e))
        b (cdr (assoc 11 e))
        c (cdr (assoc 12 e))
        d (cdr (assoc 13 e))
        p (trans (zhover--as-3d p-ucs) 1 0)
  )
  (cond
    ((setq z (zhover--bary-z a b c p)) z)
    ((and d (not (equal c d 1e-8)) (setq z (zhover--bary-z a c d p))) z)
    ((and d (not (equal b d 1e-8)) (setq z (zhover--bary-z a b d p))) z)
  )
)

(defun zhover--curve-pt (obj p-wcs / n pt)
  (setq n (zhover--try 'trans (list (getvar "VIEWDIR") 1 0)))
  (if (not n) (setq n '(0.0 0.0 1.0)))
  (setq pt (zhover--try 'vlax-curve-getClosestPointToProjection (list obj p-wcs n)))
  (if (not pt)
    (setq pt (zhover--try 'vlax-curve-getClosestPointTo (list obj p-wcs)))
  )
  pt
)

(defun zhover--z-of (en p-ucs / obj dxf typ p-wcs z pt)
  (setq obj   (zhover--try 'vlax-ename->vla-object (list en))
        dxf   (zhover--try 'entget (list en))
        typ   (if dxf (cdr (assoc 0 dxf)))
        p-wcs (trans (zhover--as-3d p-ucs) 1 0)
  )
  (cond
    ((not dxf) nil)
    ;; Civil 3D TIN / grid / volume surface - interpolated Z at XY
    ((and obj typ
          (wcmatch (strcase typ) "*SURFACE*")
          (setq z (zhover--try 'vlax-invoke
                               (list obj 'FindElevationAtXY (car p-wcs) (cadr p-wcs))))
     )
     z
    )
    ;; COGO / survey points
    ((and obj
          (member typ '("AECC_COGO_POINT" "AECC_SV_POINT"))
          (setq z (zhover--try 'vlax-get (list obj 'Elevation)))
     )
     z
    )
    ;; 3D faces
    ((member typ '("3DFACE" "SOLID" "TRACE"))
     (zhover--face-z en p-ucs)
    )
    ;; Lines, polylines, arcs, splines, feature lines, alignments, ...
    ((and obj (setq pt (zhover--curve-pt obj p-wcs)))
     (zhover--ptz pt)
    )
    ;; Point-like insertions (not interpolated along geometry)
    ((and obj
          (member typ '("POINT" "INSERT" "TEXT" "MTEXT" "SHAPE" "ATTDEF" "ATTRIB"
                        "AECC_STRUCTURE"))
          (setq pt (zhover--vla-pt obj
                    '(InsertionPoint Coordinates Location Position)))
     )
     (zhover--ptz pt)
    )
  )
)

(defun zhover--at-cursor (p / sel)
  (setq sel (nentselp p))
  (if sel (zhover--z-of (car sel) p))
)

(defun zhover--label-layer (/ rec flags color)
  (setq rec (tblsearch "LAYER" "DEFPOINTS"))
  (if rec
    (progn
      (setq flags (cdr (assoc 70 rec))
            color (cdr (assoc 62 rec))
      )
      (if (and (zerop (logand 1 flags))
               (zerop (logand 4 flags))
               (or (null color) (> color 0))
          )
        "DEFPOINTS"
        "0"
      )
    )
    "0"
  )
)

(defun zhover--label-anchor (p h / dcs gap)
  (setq dcs (trans (zhover--as-3d p) 1 2)
        gap (* (getvar "VIEWSIZE") 0.045)
  )
  (trans
    (list (+ (car dcs) gap)
          (+ (cadr dcs) (* gap 0.30))
          (caddr dcs)
    )
    2
    0
  )
)

(defun zhover--unit (v / len)
  (setq len (distance '(0.0 0.0 0.0) (zhover--as-3d v)))
  (if (equal len 0.0 1e-12)
    '(0.0 0.0 1.0)
    (list (/ (car v) len) (/ (cadr v) len) (/ (zhover--ptz v) len))
  )
)

;; Lift the label toward the camera so 3D contours do not draw through it.
(defun zhover--in-front (pt / d lift)
  (setq d    (zhover--unit (trans (getvar "VIEWDIR") 1 0))
        lift (* (getvar "VIEWSIZE") 0.08)
  )
  (mapcar '+ (zhover--as-3d pt)
          (list (* (car d) lift) (* (cadr d) lift) (* (caddr d) lift))
  )
)

(defun zhover--view-angle ()
  (angle (trans '(0.0 0.0 0.0) 2 0) (trans '(1.0 0.0 0.0) 2 0))
)

(defun zhover--rotate (pt base ang / dx dy)
  (setq dx (- (car pt) (car base))
        dy (- (cadr pt) (cadr base))
  )
  (list
    (+ (car base) (- (* dx (cos ang)) (* dy (sin ang))))
    (+ (cadr base) (+ (* dx (sin ang)) (* dy (cos ang))))
    (zhover--ptz base)
  )
)

;; Box in text space: (xmin ymin xmax ymax).
;; Italic (51=15) leans the glyphs right; textbox often ignores that, so the
;; right edge is the wider of textbox vs 0.90*h per character, plus slant.
(defun zhover--rel-box (str h / tb p1 p2 pad italic xmin ymin xmax ymax)
  (setq pad    (* h 0.22)
        italic (* h 0.38)
        xmin   (- 0.0 pad)
        ymin   (- (* h 0.12) pad)
        xmax   (+ (* h 0.92 (strlen str)) italic pad)
        ymax   (+ (* h 1.20) pad)
  )
  (setq tb (zhover--try 'textbox
            (list (list (cons 1 str) (cons 40 h) (cons 7 "STANDARD") (cons 51 15.0))))
  )
  (if (and tb (car tb) (cadr tb))
    (setq p1   (car tb)
          p2   (cadr tb)
          xmin (min xmin (- (car p1) pad))
          ymin (min ymin (- (cadr p1) pad))
          xmax (max xmax (+ (car p2) italic pad))
          ymax (max ymax (+ (cadr p2) pad))
    )
  )
  (list xmin ymin xmax ymax)
)

(defun zhover--box-corners (pt str h ang / rel)
  (setq rel (zhover--rel-box str h))
  (zhover--apply-rel pt ang rel)
)

(defun zhover--apply-rel (pt ang rel)
  (list
    (zhover--rotate (list (+ (car pt) (nth 0 rel)) (+ (cadr pt) (nth 1 rel)) (zhover--ptz pt)) pt ang)
    (zhover--rotate (list (+ (car pt) (nth 2 rel)) (+ (cadr pt) (nth 1 rel)) (zhover--ptz pt)) pt ang)
    (zhover--rotate (list (+ (car pt) (nth 0 rel)) (+ (cadr pt) (nth 3 rel)) (zhover--ptz pt)) pt ang)
    (zhover--rotate (list (+ (car pt) (nth 2 rel)) (+ (cadr pt) (nth 3 rel)) (zhover--ptz pt)) pt ang)
  )
)

(defun zhover--front-do (en / doc obj sp dict sort)
  (setq doc  (vla-get-activedocument (vlax-get-acad-object))
        obj  (vlax-ename->vla-object en)
        sp   (vla-ObjectIdToObject doc (vla-get-OwnerID obj))
        dict (vla-GetExtensionDictionary sp)
        sort (vl-catch-all-apply 'vla-Item (list dict "ACAD_SORTENTS"))
  )
  (if (vl-catch-all-error-p sort)
    (setq sort (vla-AddObject dict "ACAD_SORTENTS" "AcDbSortentsTable"))
  )
  (vlax-invoke sort 'MoveToTop (list obj))
)

(defun zhover--front (en)
  (if en (zhover--try 'zhover--front-do (list en)))
)

(defun zhover--make-box (corners / en obj)
  (setq en
    (entmakex
      (list
        '(0 . "SOLID")
        '(100 . "AcDbEntity")
        (cons 8 (zhover--label-layer))
        '(62 . 251)
        ;; 75% opacity = 25% AutoCAD transparency (0=opaque, 90=clear)
        (cons 440 33554457)
        '(100 . "AcDbTrace")
        (cons 10 (nth 0 corners))
        (cons 11 (nth 1 corners))
        (cons 12 (nth 2 corners))
        (cons 13 (nth 3 corners))
      )
    )
  )
  (if en
    (progn
      (setq obj (zhover--try 'vlax-ename->vla-object (list en)))
      (if obj (zhover--try 'vla-put-EntityTransparency (list obj "25")))
    )
  )
  en
)

(defun zhover--mod-box (corners / el)
  (setq el (entget *zhover-box*))
  (if el
    (progn
      (foreach pair (list
                      (cons 10 (nth 0 corners))
                      (cons 11 (nth 1 corners))
                      (cons 12 (nth 2 corners))
                      (cons 13 (nth 3 corners))
                      '(62 . 251)
                    )
        (if (assoc (car pair) el)
          (setq el (subst pair (assoc (car pair) el) el))
          (setq el (append el (list pair)))
        )
      )
      (entmod el)
      *zhover-box*
    )
  )
)

(defun zhover--make-label (pt str h ang)
  (entmakex
    (list
      '(0 . "TEXT")
      '(100 . "AcDbEntity")
      (cons 8 (zhover--label-layer))
      '(62 . 6)
      '(100 . "AcDbText")
      (cons 10 pt)
      (cons 40 h)
      (cons 1 str)
      (cons 50 ang)
      (cons 51 15.0)
      '(7 . "STANDARD")
      '(72 . 0)
      '(73 . 0)
    )
  )
)

(defun zhover--mod-label (pt str h ang / el)
  (setq el (entget *zhover-label*))
  (if el
    (progn
      (foreach pair (list (cons 10 pt) (cons 1 str) (cons 40 h) (cons 50 ang) (cons 51 15.0) '(62 . 6))
        (if (assoc (car pair) el)
          (setq el (subst pair (assoc (car pair) el) el))
          (setq el (append el (list pair)))
        )
      )
      (entmod el)
      *zhover-label*
    )
  )
)

(defun zhover--erase-label ()
  (if *zhover-label*
    (progn
      (zhover--try 'entdel (list *zhover-label*))
      (setq *zhover-label* nil)
    )
  )
  (if *zhover-box*
    (progn
      (zhover--try 'entdel (list *zhover-box*))
      (setq *zhover-box* nil)
    )
  )
  (setq *zhover-last-str* nil
        *zhover-last-h*   nil
        *zhover-relbox*   nil
  )
)

(defun zhover--show (p z / str h lab ang corners created)
  (setq str (zhover--format-z z)
        h   (* (getvar "VIEWSIZE") 0.011)
        lab (zhover--in-front (zhover--label-anchor p h))
        ang (zhover--view-angle)
  )
  (if (not (and *zhover-relbox*
                (equal str *zhover-last-str*)
                (equal h *zhover-last-h* 1e-8)
           )
      )
    (setq *zhover-relbox*   (zhover--rel-box str h)
          *zhover-last-str* str
          *zhover-last-h*   h
    )
  )
  (setq corners (zhover--apply-rel lab ang *zhover-relbox*)
        created nil
  )
  (if (and *zhover-box* (entget *zhover-box*))
    (if (not (zhover--mod-box corners))
      (setq *zhover-box* (zhover--make-box corners)
            created T
      )
    )
    (setq *zhover-box* (zhover--make-box corners)
          created T
    )
  )
  (if (and *zhover-label* (entget *zhover-label*))
    (if (not (zhover--mod-label lab str h ang))
      (setq *zhover-label* (zhover--make-label lab str h ang)
            created T
      )
    )
    (setq *zhover-label* (zhover--make-label lab str h ang)
          created T
    )
  )
  (if created
    (progn
      (zhover--front *zhover-box*)
      (zhover--front *zhover-label*)
    )
  )
)

(defun zhover--cleanup (old-echo old-macro old-nomutt old-fill old-dimzin)
  (zhover--erase-label)
  (if old-echo   (setvar "CMDECHO" old-echo))
  (if old-macro  (setvar "MODEMACRO" old-macro))
  (if old-nomutt (setvar "NOMUTT" old-nomutt))
  (if old-fill   (setvar "FILLMODE" old-fill))
  (if old-dimzin (setvar "DIMZIN" old-dimzin))
  (princ "\nZHOVER off.")
)

(defun c:zhover ( / *error* old-echo old-macro old-nomutt old-fill old-dimzin done gr code data z)
  (setq old-echo   (getvar "CMDECHO")
        old-macro  (getvar "MODEMACRO")
        old-nomutt (getvar "NOMUTT")
        old-fill   (getvar "FILLMODE")
        old-dimzin (getvar "DIMZIN")
  )
  (defun *error* (msg)
    (zhover--cleanup old-echo old-macro old-nomutt old-fill old-dimzin)
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*QUIT*,*EXIT*")))
      (princ (strcat "\nZHOVER: " msg))
    )
    (princ)
  )
  (setvar "CMDECHO" 0)
  (setvar "NOMUTT" 1)
  (setvar "FILLMODE" 1)
  (setvar "DIMZIN" 0)
  (princ "\nZHOVER: HOVER APERTURE OVER ENTITY TO DISPLAY IT'S Z VALUE. CLICK TO PRINT AT COMMAND LINE.")
  (setq done nil)
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
          (setq z (zhover--at-cursor data))
          (if z
            (progn
              (zhover--show data z)
              (setvar "MODEMACRO" (zhover--format-z z))
            )
            (progn
              (zhover--erase-label)
              (setvar "MODEMACRO" "")
            )
          )
         )
         ((= code 3)
          (setq z (zhover--at-cursor data))
          (if z
            (princ (strcat "\n" (zhover--format-z z)))
            (princ "\nNo elevation at that point.")
          )
         )
         ((= code 2)
          (if (member data '(13 32 27)) (setq done T))
         )
         ((or (= code 11) (= code 25))
          (setq done T)
         )
       )
      )
    )
  )
  (zhover--cleanup old-echo old-macro old-nomutt old-fill old-dimzin)
  (princ)
)

(defun c:zh () (c:zhover))

(princ "\nZHOVER loaded. Type ZHOVER or ZH to show elevations at the cursor.")
(princ)
