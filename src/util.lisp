;; Copyright © 2014 FMAP SVERIGE AB

;; This file is part of Eclastic

;; Eclastic is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Lesser General Public License as
;; published by the Free Software Foundation, either version 3 of the
;; License, or (at your option) any later version.

;; Eclastic is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; Lesser General Public License for more details.

;; You should have received a copy of the GNU Lesser General Public
;; License along with Eclastic.  If not, see
;; <http://www.gnu.org/licenses/>.

(in-package :cl-user)
(defpackage :eclastic.util
  (:use :cl)
  (:import-from :yason
                :encode-object
                :encode-object-element
                :with-object-element)
  (:export :encode-object-element*
           :with-object-element*))

(in-package :eclastic.util)

(defmacro encode-object-element* (key value)
  "Encode key-value pair only if VALUE is non-NIL"
  `(when ,value
     (encode-object-element ,key ,value)))

(defmacro with-object-element* ((key predicate) &body body)
  "Encode key-body only if PREDICATE is non-NIL"
  `(when ,predicate
     (with-object-element (,key) ,@body)))

(defun inspect-json (object &optional (stream *standard-output*))
  (yason:with-output (stream :indent t)
    (encode-object object)))
