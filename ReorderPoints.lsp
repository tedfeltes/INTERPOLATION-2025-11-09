;;| 	Lisp to reorder existing points using new point numbers, in the order in which they are selected.
	Application allows for single selection or fence selection of points.
	Points can only be renumbered higher than the greatest existing point number.
	
	Originally Created by Jeff Mishler, January 2012;
	For use in C3D 2010 - 2012
	   
	Modified by Gavin Rouleau, March 2012;
	Addition of fence selection option in addition to original single selection mode.
	Changes to existing prompts and selection checking.  Addition of new prompts.
	   
	Modified by Jeff Mishler, April 2012;
	Improvements to existing prompts.  Addition of fence line highlighting.
	   
	Modified by Gavin Rouleau, April 2012;
	Based on discussions with Jeff revised fence zoom procedures including test code.
	Modified fence to use polylines instead of lines per Jeff's example code.
	Modified other procedures to work with polylines instead of lines.
	Combined setq function calls in some instances.
	Modified single and fence selection prompts to allow for carriage return to end selection.
	Modifed user point number entry to accept numbers larger than 32,767
	
	Modified by Gavin Rouleau, April 2013;
	Updated to work with C3D 2013 and 2014
	Corrected error with fence selection when undoing two one point then selecting 2nd point
	
	Modified by Ross Dunkley, July 2014;
	Updated to work with C3D 2015;

	Revised method to retrieve AeccVersion, should work with all current and future versions. Sept. 2014
	Also added check for existence of CogoPoints in the drawing, as an error is thrown by the C3d API when none are found.
	by Jeff Mishler

	Modified July 2026;
	Updated to work with C3D 2026 (and remain compatible with older/newer releases).
	The previous version derived the AeccApplication COM version solely from the
	registry "Release" value with no error handling.  On some installs (including
	C3D 2026) that produced an invalid ProgID and the C3D API aborted the command
	with "error: Civil 3D API; the parameter is incorrect".
	The version handshake is now performed by a resilient helper (getAeccApp) that
	first tries the registry-derived version and then falls back through the known
	release ProgIDs (2026 = 13.8, 2025 = 13.7, 2024 = 13.6, ...), trapping errors so
	the raw COM error is never surfaced to the user.
 |;

;;; Returns the "major.minor" version string (e.g. "13.8") derived from the
;;; AutoCAD/Civil 3D registry "Release" value, or nil if it cannot be read.
(defun ReorderPoints-GetReleaseVersion ( / key rel firstdot seconddot)
  (setq key (strcat "HKEY_LOCAL_MACHINE\\"
		    (if	vlax-user-product-key
		      (vlax-user-product-key)
		      (vlax-product-key)
		    )
	    )
  )
  (setq rel (vl-catch-all-apply 'vl-registry-read (list key "Release")))
  (if (or (vl-catch-all-error-p rel) (not rel))
    nil
    (progn
      (setq firstdot (vl-string-search "." rel))
      (if firstdot
	(setq seconddot (vl-string-search "." rel (1+ firstdot)))
      )
      (if seconddot
	(substr rel 1 seconddot)
	nil
      )
    )
  )
)

;;; Resilient replacement for the old inline version handshake.
;;; module must be "Land", "Pipe", "Roadway", or "Survey".
;;; Returns the Aecc application object, or nil if none could be obtained.
(defun ReorderPoints-GetAeccApp (module / *acad* regver verlst app progid try)
  (vl-load-com)
  (setq *acad* (vlax-get-acad-object))
  ;; Known AeccApplication versions, newest first, used as fallbacks.
  ;;   13.8 = C3D 2026   13.7 = C3D 2025   13.6 = C3D 2024
  ;;   13.5 = C3D 2023   13.4 = C3D 2022   13.3 = C3D 2021
  ;;   13.2 = C3D 2020   13.0 = C3D 2019   12.0 = C3D 2018   11.0 = C3D 2017
  (setq verlst '("13.8" "13.7" "13.6" "13.5" "13.4" "13.3" "13.2" "13.0" "12.0" "11.0"))
  ;; Prefer the version reported by the running install's registry entry.
  (setq regver (ReorderPoints-GetReleaseVersion))
  (if (and regver (not (member regver verlst)))
    (setq verlst (cons regver verlst))
    (if regver (setq verlst (cons regver (vl-remove regver verlst))))
  )
  (setq app nil)
  (foreach ver verlst
    (if (and *acad* (null app))
      (progn
	(setq progid (strcat "AeccXUi" module
			     ".Aecc"
			     (if (= (strcase module) "LAND") "" module)
			     "Application."
			     ver
		     )
	)
	(setq try (vl-catch-all-apply 'vla-getinterfaceobject (list *acad* progid)))
	(if (not (vl-catch-all-error-p try))
	  (setq app try)
	)
      )
    )
  )
  app
)

(defun c:reorderpoints ()
							
	(vl-load-com)
  (if (ssget "x" '((0 . "AECC_COGO_POINT")))
    (reorderpoints)
    (princ "\nNo points found in drawing, exiting!")
    )
  (princ)
  )
  
(defun reorderpoints (/ *ACAD* C3D C3DDOC ENT GETNUM NEXTPOINT POINTS PTOBJ 
							STYP TNIL PT1 PT2 PTLST MINPT MAXPT MINXY MAXXY PDST ZMMINPT ZMMAXPT  
							VCTR VHGHT SSIZE VWDTH VWMINX VWMINY VWMAXX VWMAXY ZTRU SSPTS N FDEF 
							FSTAT PLLST NPTS PLKP MODEL PLINE FPTLST)
  (setq	*acad* (vlax-get-acad-object)
	C3D (ReorderPoints-GetAeccApp "Land")
  )
  (if (not C3D)
    (princ "\nUnable to connect to the Civil 3D API - command aborted.")
    (if (and *acad*
		c3d
		(setq C3Ddoc (vla-get-activedocument C3D))
		)
		(progn
			(setq points nil)
			(vlax-for point (vlax-get-property c3ddoc 'points)
				(setq points (cons (vlax-get point 'number) points))
			)
			(setq points (vl-sort points '>))
			(setq nextpoint (car points))
			(while 
				(<= nextpoint (car points))			
				(setq getnum (getreal (strcat "\nPoint number to start the reordering at <" 
					(itoa (1+ nextpoint)) ">: ")))
				(cond
					(
						(and getnum (/= (fix getnum) getnum))
						(princ "\Point Number must be an Integer!")
					)
					(
						(and getnum (> getnum nextpoint))
						(setq nextpoint (fix getnum))
					)
					(
						(and getnum (<= getnum nextpoint))
						(princ (strcat "\nPoint Number must be Greater than Existing Point #" (itoa nextpoint) "."))
					)
					(
						(not getnum)
						(setq nextpoint (1+ nextpoint))
					)
				)
			) ;;End While
			(initget "Single Fence")
			(setq styp (getkword "\nSpecify Selection Type [Single/Fence] <Single>: "))
			(if (not styp)
				(setq styp "Single")
			)
			(cond
				( ;;Begin Single Selection Condition
					(= styp "Single")
					(setq ent nil)
					(vla-StartUndoMark C3Ddoc)
					(while (/= ent "exit")
						(while 
							(and
								(/= ent "exit")
								(null (setq ent (entsel (strcat "\nSelect point to change to #" (itoa nextpoint) ": "))))
							)
							(setq tnil (getvar "errno"))
							(if (= tnil 7)
								(princ "\n...nothing selected, try again!")
								(setq ent "exit")
							)
						)
						(if (/= ent	"exit")
							(if (eq (cdr (assoc 0 (entget (car ent)))) "AECC_COGO_POINT")
								(progn
									(setq ptobj (vlax-ename->vla-object (car ent)))
									(vlax-put ptobj 'number nextpoint)
									(vla-update ptobj)
									(setq nextpoint (1+ nextpoint))
								)
								(princ "\n...not a point object, try again!")
							)
						)
					) 
					(vla-EndUndoMark C3Ddoc)
				) ;;End Single Selection Condition
				( ;;Begin Fence Selection Condition
					(= styp "Fence")
					(setq 
						model (vla-get-modelspace C3Ddoc)
						pllst '()
						fdef "Yes"
					)
					(vla-StartUndoMark C3Ddoc)
					(while (= fdef "Yes") ;;Begin While Loop to Create Fence and Select Points
						(setq 
							ptlst '()
							pline nil
							pt1 nil
						)
						(while ;;Begin Fence Creation Process
							(and
								(= fdef "Yes")
								(null (setq pt1 (getpoint 
									(strcat "\nSpecify First Fence Point (Next Point #" (itoa nextpoint)"): "))))
							)
							(setq fdef "No")
						)
						(if (= fdef "Yes") 
							(progn 
								(setq 
									npts 1
									ptlst (list (car pt1) (cadr pt1))
									fstat nil
								)
								(while (/= fstat "End") ;;Continue Fence Creation Process
									(initget "Undo")
									(setq pt2 (getpoint pt1 "\nSpecify Next Fence Point or [Undo]: "))
									(if (/= pt2 nil)
										(progn
											(if (/= pt2 "Undo")
												(progn
													(setq 
														npts (1+ npts)
														ptlst (append ptlst (list (car pt2) (cadr pt2)))
													)
													(if (not pline)
														(progn
															(setq pline (vlax-invoke model 'addlightweightpolyline ptlst))
															(vla-highlight pline :vlax-true)																
														)
														(progn
															(vlax-put pline 'coordinates ptlst)
															(vla-highlight pline :vlax-true)															
														)
													)											
													(setq pt1 pt2)
												)
												(progn
													(if (= npts 1)
														(setq 
															ptlst '()
															fstat "End"
															sspts '()
														)
														(progn
															(setq
																ptlst (reverse (cddr (reverse ptlst)))
																pt1 (list (cadr (reverse ptlst)) (last ptlst))
																npts (1- npts)
															)
															(if (> npts 1)
																(progn
																	(vlax-put pline 'coordinates ptlst)
																	(vla-highlight pline :vlax-true)
																)
																(progn
																	(vla-delete pline)
																	(setq pline nil)
																)
															)
														)
													)
												)
											)
										)
										(setq fstat "End")
									)
								) ;;End Fence Creation Process
								(if (> npts 1)  ;;Begin Fence Point Selection Process
									(progn
										(vla-GetBoundingBox pline 'minpt 'maxpt)
										(setq 
											minxy (reverse (cdr (reverse (vlax-safearray->list minpt))))
											maxxy (reverse (cdr (reverse (vlax-safearray->list maxpt))))								
											pdst (/ (distance minxy maxxy) 10)							
											zmminpt (polar minxy (/ (* 225 pi) 180) pdst)
											zmmaxpt (polar maxxy (/ (* 45 pi) 180) pdst)
											vctr (getvar "viewctr")
											vhght (getvar "viewsize")
											ssize (getvar "screensize")
											vwdth (* (/ (car ssize) (cadr ssize)) vhght)
											vwminx (- (car vctr) (/ vwdth 2))
											vwminy (- (cadr vctr) (/ vhght 2))
											vwmaxx (+ (car vctr) (/ vwdth 2))
											vwmaxy (+ (cadr vctr) (/ vhght 2))
										)
										(if (or 
												(< (car zmminpt) vwminx)
												(< (cadr zmminpt) vwminy)
												(> (car zmmaxpt) vwmaxx)
												(> (cadr zmmaxpt) vwmaxy)
											)
											(progn
												(vla-ZoomWindow *acad* (vlax-3D-point zmminpt) (vlax-3D-point zmmaxpt))
												(setq ztru "yes")
											)
											(setq ztru "no")
										)
										
										;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
										;;THE CODE BELOW IS FOR TESTING ONLY AND IS INTENTIONALLY COMMENTED OUT.
										
										;;Linear Polyline corresponding the Bounding Box Diagonal
										;;(vlax-invoke model 'addlightweightpolyline (append minxy maxxy))
										
										;;Linear Polyline corresponding to Zoom Limits Diagonal
										;;(vlax-invoke model 'addlightweightpolyline (append zmminpt zmmaxpt))
										
										;;Rectangular Polyline that corresponds to Zoom Limits
										;;(vla-put-closed (vlax-invoke model 'addlightweightpolyline (append zmminpt 
										;;	(list (car zmmaxpt) (cadr zmminpt)) zmmaxpt 
										;;	(list (car zmminpt) (cadr zmmaxpt)))) :vlax-true)
										
										;;Rectangular Polyline that corresponds to View Limits
										;;(vla-put-closed (vlax-invoke model 'addlightweightpolyline 
										;;	(append (list vwminx vwminy) (list vwmaxx vwminy) 
										;;	(list vwmaxx vwmaxy) (list vwminx vwmaxy))) :vlax-true)								
										
										;;Prompt to create delay between zoom procedures
										;;(getstring "\nHit Return to Continue!")
										;;END OF TEST CODE
										;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
										
										(setq 
											fptlst '()
											n 0
										)
										(repeat (/ (length ptlst) 2)
											(setq
												fptlst (append fptlst (list (list (nth n ptlst) (nth (+ n 1) ptlst))))
												n (+ n 2)
											)
										)
										(setq sspts (ssget "F" fptlst '((0 . "AECC_COGO_POINT"))))
										(if (= ztru "yes")
											(vla-ZoomPrevious *acad*)								
										)
										(if (= sspts '())
											(progn
												(princ "\n...nothing selected, try again!")
												(vla-delete pline)
											)
											(setq pllst (append pllst (list (vlax-vla-object->ename pline))))
										)
									)
								)  ;;End Fence Point Selection Process
								(setq n 0)
								(if (/= sspts '())  ;;Renumber Selected Points
									(progn
										(princ (strcat "\nNumber of Points Selected with Current Fence: " (itoa (sslength sspts))))
										(repeat (sslength sspts)
											(setq ptobj (vlax-ename->vla-object (ssname sspts n)))
											(vlax-put ptobj 'number nextpoint)
											(vla-update ptobj)
											(setq 
												nextpoint (1+ nextpoint)
												n (1+ n)
											)
										)
									)
								)
								(initget "Yes No")
								(setq fdef (getkword "\nDefine Additional Fence Selections [Yes/No] <Yes>: "))
								(if (not fdef)
									(setq fdef "Yes")
								)
							)
						)
					) ;;End While Loop to Create Fence and Select Points
					(setq n 0)
					(if (/= pllst '())
						(progn
							(initget "Yes No")
							(setq plkp (getkword "\nErase Fence Lines? [Yes/No] <Yes>: "))
							(repeat (length pllst)
								(setq pline (vlax-ename->vla-object (nth n pllst)))
								(if (or (not plkp) (= plkp "Yes"))
									(vla-delete pline)
									(vla-highlight pline :vlax-false)
								)
								(setq n (1+ n))						
							)							
						)
					)
					(vla-EndUndoMark C3Ddoc)					
				) ;;End Fence Selection Condition
			) ;;End Condition Statement
		)
	)
  )
  (princ)
)
