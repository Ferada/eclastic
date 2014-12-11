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

(in-package #:cl-user)
(defpackage #:elastic.query
  (:use #:cl
        #:elastic.util)
  (:import-from #:yason
                #:encode
                #:encode-slots
                #:encode-object
                #:encode-object-element
                #:with-array
                #:encode-array-elements
                #:with-object
                #:with-object-element
                #:with-output-to-string*
                #:*json-output*)
  (:export #:match
           #:bool
           #:filtered))

(in-package #:elastic.query)

(defmacro encode-object-element* (key value)
  `(when ,value
     (encode-object-element ,key ,value)))

(defmacro with-object-element* ((key) &body body)
  `(when ,key
     (with-object-element (,key) ,@body)))

(defclass <query> ()
  ())

(defclass <filter> ()
  ())

(defgeneric encode-subquery (subquery))

(defmethod encode-subquery ((this <query>))
  (encode-object this))

(defmethod encode-subquery ((this cons))
  (with-array ()
    (loop for subquery in this do
         (encode-subquery subquery))))

(defclass <string-query> (<query>)
  ((query-string :initarg :query-string
                 :reader query-string)))

(defclass <fuzzy-query> (<query>)
  ((fuzziness :initarg :fuzziness
              :reader fuzziness)))

(defclass <boolean-query> (<query>)
  ((operator :initarg :operator
             :reader operator)))

(defclass <field-query> (<query>)
  ((search-field :initarg :search-field
                 :reader search-field)))

(defclass <zero-terms-query> (<query>)
  ((zero-terms-query :initarg :zero-terms-query
                     :reader zero-terms-query)))

(defclass <cutoff-frequency-query> (<query>)
  ((cutoff-frequency :initarg :cutoff-frequency
                     :reader cutoff-frequency)))

(defclass <boost-query> (<query>)
  ((boost :initarg :boost
          :reader boost)))

(defclass <match> (<string-query>
                   <fuzzy-query>
                   <boolean-query>
                   <field-query>
                   <zero-terms-query>
                   <cutoff-frequency-query>)
  ((match-type :initarg :match-type
               :reader match-type)))

(defmethod encode-slots progn ((this <match>))
  (with-object-element ((match-type this))
    (with-object ()
      (with-object-element ((search-field this))
        (with-object ()
          (encode-object-element "query" (query-string this))
          (encode-object-element* "operator" (operator this))
          (encode-object-element* "zero_terms_query"
                                  (zero-terms-query this))
          (encode-object-element* "cutoff_frequency"
                                  (cutoff-frequency this)))))))

(defun match (query-string field &key
                                   (operator :or)
                                   (type :match)
                                   fuzziness
                                   (zero-terms-query :none)
                                   cutoff-frequency)
  (make-instance '<match>
                 :query-string query-string
                 :search-field field
                 :operator (ecase operator
                             (:or "or")
                             (:and "and"))
                 :match-type (ecase type
                               (:match "match")
                               (:match-phrase "match_phrase")
                               (:match-phrase-prefix "match-phrase-prefix"))
                 :fuzziness fuzziness
                 :zero-terms-query (ecase zero-terms-query
                                     (:none "none")
                                     (:all "all"))
                 :cutoff-frequency cutoff-frequency))

(defclass <bool> (<boost-query> <filter>)
  ((must :initarg :must
         :reader must)
   (must-not :initarg :must-not
               :reader must-not)
   (should :initarg :should
           :reader should)
   (minimum-should :initarg :minimum-should
                   :reader minimum-should)))

(defmethod encode-slots progn ((this <bool>))
  (with-object-element ("bool")
    (with-object ()
      (with-object-element* ("must")
        (encode-subquery (must this)))
      (with-object-element* ("must_not")
        (encode-subquery (must-not this)))
      (with-object-element* ("should")
        (encode-subquery (should this)))
      (encode-object-element* "minimum_should_match" (minimum-should this))
      (encode-object-element* "boost" (boost this)))))

(defun bool (&key must must-not should minimum-should boost)
  (make-instance '<bool>
                 :must must
                 :must-not must-not
                 :should should
                 :minimum-should minimum-should
                 :boost boost))

(defclass <filtered> (<query>)
  ((query :initarg :query
          :reader query)
   (filter :initarg :filter
           :reader filter)
   (strategy :initarg :strategy
             :reader strategy)))

(defmethod encode-slots progn ((this <filtered>))
  (with-object-element ("filtered")
    (with-object ()
      (with-object-element ("query")
        (encode-object (query this)))
      (with-object-element ("filter")
        (encode-object (filter this)))
      (encode-object-element* "strategy" (strategy this)))))

(defun filtered (query filter &key strategy)
  (make-instance '<filtered>
                 :query query
                 :filter filter
                 :strategy (when strategy
                             (if (numberp strategy)
                                 (format nil "random_access_~D" strategy)
                                 (ecase strategy
                                   (:leap-frog-query-first
                                    "leap_frog_query_first")
                                   (:leap-frog-filter-first
                                    "leap_frog_filter_first")
                                   (:leap-frog
                                    "leap_frog")
                                   (:query-first
                                    "query_first")
                                   (:random-access-always
                                    "random_access_always"))))))