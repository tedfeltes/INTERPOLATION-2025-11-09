;| 	Lisp to reorder existing points using new point numbers, in the order in which they are selected.
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
	Updated to work with C3D 2026 (and all other releases).
	Earlier versions connected to the version-specific AeccApplication COM object
	(AeccXUiLand.AeccApplication.<ver>) just to read the existing point numbers.
	That handshake is fragile - on some installs (including C3D 2026) accessing the
	AeccDocument 'points collection throws "error: Civil 3D API: The parameter is
	incorrect" and aborts the command.
	It is not needed: a point's number can be read and written directly from the
	AECC_COGO_POINT object itself.  This version therefore drops the AeccApplication
	dependency entirely and works purely at the AutoCAD document / entity level,
	which is version-independent.
 |;

;;; Safely assign a new point number to a CogoPoint object.
;;; Returns T on success, nil on failure (trapping any C3D API error such as
;;; "The parameter is incorrect" instead of aborting the whole command).
(defun ReorderPoints-SetNumber (ptobj num / res)
  (setq res (vl-catch-all-apply
	      '(lambda ()
		 (vlax-put ptobj 'number num)
		 (vla-update ptobj)
	       )
	    )
  )
  (not (vl-catch-all-error-p res))
)

(defun c:reorderpoints ()
							
	(vl-load-com)
  (if (ssget "x" '((0 . "AECC_COGO_POINT")))
    (reorderpoints)
    (princ "\nNo points found in drawing, exiting!")
    )
  (princ)
  )
  
(defun reorderpoints (/ *ACAD* ACDOC ENT GETNUM NEXTPOINT POINTS PTOBJ 
							STYP TNIL PT1 PT2 PTLST MINPT MAXPT MINXY MAXXY PDST ZMMINPT ZMMAXPT  
							VCTR VHGHT SSIZE VWDTH VWMINX VWMINY VWMAXX VWMAXY ZTRU SSPTS N FDEF 
							FSTAT PLLST NPTS PLKP MODEL PLINE FPTLST PTSS PIDX PNUM)
  (setq	*acad* (vlax-get-acad-object)
	acdoc (vla-get-activedocument *acad*)
  )
  (if acdoc
		(progn
			;; Determine the highest existing point number by reading the
			;; Number property directly off each AECC_COGO_POINT object.
			;; (The AeccDocument 'points collection is avoided on purpose - in
			;; recent Civil 3D releases accessing it throws
			;; "Civil 3D API: The parameter is incorrect".)
			(setq points nil)
			(setq ptss (ssget "x" '((0 . "AECC_COGO_POINT"))))
			(if ptss
				(progn
					(setq pidx 0)
					(repeat (sslength ptss)
						(setq pnum (vl-catch-all-apply 'vlax-get
							(list (vlax-ename->vla-object (ssname ptss pidx)) 'Number)))
						(if (and (not (vl-catch-all-error-p pnum)) pnum)
							(setq points (cons pnum points))
						)
						(setq pidx (1+ pidx))
					)
				)
			)
			(if (not points)
				(setq points (list 0))
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
					(vla-StartUndoMark acdoc)
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
									(if (ReorderPoints-SetNumber ptobj nextpoint)
										(setq nextpoint (1+ nextpoint))
										(princ (strcat "\n...unable to renumber this point to #" (itoa nextpoint) ", try another!"))
									)
								)
								(princ "\n...not a point object, try again!")
							)
						)
					) 
					(vla-EndUndoMark acdoc)
				) ;;End Single Selection Condition
				( ;;Begin Fence Selection Condition
					(= styp "Fence")
					(setq 
						model (vla-get-modelspace acdoc)
						pllst '()
						fdef "Yes"
					)
					(vla-StartUndoMark acdoc)
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
											(if (ReorderPoints-SetNumber ptobj nextpoint)
												(setq nextpoint (1+ nextpoint))
												(princ (strcat "\n...unable to renumber a point to #" (itoa nextpoint) ", skipped!"))
											)
											(setq n (1+ n))
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
					(vla-EndUndoMark acdoc)					
				) ;;End Fence Selection Condition
			) ;;End Condition Statement
		)
	)
  (princ)
)
