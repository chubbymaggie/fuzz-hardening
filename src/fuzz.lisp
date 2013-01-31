(in-package :software-evolution)
(use-package :cl-ppcre)
(use-package :curry-compose-reader-macros)
(eval-when (:compile-toplevel :load-toplevel :execute)
  (enable-curry-compose-reader-macros))

(defvar *test* "../../bin/test-indent.sh"
  "The indent test script with fuzzing.")

(defvar *fuzz* "../../bin/break-indent.sh"
  "Script to break indent with fuzzing.")

(defvar *orig* (from-file (make-instance 'cil) "indent/indent_comb.c")
  "The original program.")

(defvar *work-dir* "sh-runner/work/"
  "Needed because SBCL chokes after too many shell outs.")

(setf *max-population-size* (expt 2 7))

(setf *tournament-size* 2)

(defmethod fuzz ((variant cil))
  (with-temp-file (file)
    (phenome variant :bin file)
    (multiple-value-bind (stdout stderr exit)
        (shell "~a ~a 2>&1" *fuzz* file)
      (declare (ignorable stderr))
      (bind (((fuzz err-str) (split-sequence #\Space stdout)))
        (values fuzz (parse-number err-str))))))

(defmethod positive-tests ((variant cil))
  (with-temp-file (file)
    (or (ignore-errors
          (phenome variant :bin file)
          (multiple-value-bind (stdout stderr exit)
              (shell "~a ~a 2>&1" *test* file)
            (declare (ignorable stderr))
            (when (zerop exit)
              (parse-number stdout))))
        0)))

(defmethod fuzz-tests ((variant cil) fuzz-file)
  (with-temp-file (file)
    (or (ignore-errors
          (phenome variant :bin file)
          (multiple-value-bind (stdout stderr exit)
              (shell "~a ~a ~a 2>&1" *test* file fuzz-file)
            (declare (ignorable stderr))
            (if (zerop exit) 5)))
        0)))

(defun test (fuzz-file variant)
  (incf *fitness-evals*)
  (+ (positive-tests variant)
     (fuzz-tests variant fuzz-file)))

(defmethod harden ((variant cil))
  (multiple-value-bind (fuzz-file errno) (fuzz variant)
    (evolve {test fuzz-file} :max-fit 10)))

;; Run -- this will just run forever
#+run
(progn
  (setf (fitness *orig*) (positive-tests *orig*))
  (setf *population* (repeatedly *max-population-size* (copy *orig*)))
  (let ((best (copy *orig*)))
    (loop :for i :upfrom 0 :do
       (setf best (harden best))
       (store *population* (format nil "pop-~d.store" i)))))
