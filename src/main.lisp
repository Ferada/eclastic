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
(defpackage :eclastic
  (:use :cl
        :eclastic.util)
  (:import-from :yason
                :parse
                :encode
                :encode-slots
                :encode-object
                :encode-object-element
                :with-object
                :with-object-element
                :with-output-to-string*
                :*json-output*)
  (:import-from :drakma
                :http-request
                :*text-content-types*)
  (:import-from :flexi-streams
                :octets-to-string)
  (:import-from :anaphora
                :awhen
                :it)
  (:export :get*
           :new-search
           :document-by-id
           :document-not-found
           :document-id
           :document-source
           :<document>
           :<server>
           :<index>
           :<type>
           :<search>))

(in-package :eclastic)

(defclass <server> ()
  ((host :initarg :host
         :initform "localhost"
         :reader host)
   (port :initarg :port
         :initform 9200
         :reader port)))

(defgeneric get-uri (entity))

(defmethod get-uri ((this <server>))
  (format nil "http://~A:~A"
          (host this)
          (port this)))

(defun send-request (uri method &key data parameters)
  (let ((*text-content-types*
          '(("application" . "json"))))
    (multiple-value-bind (body status headers uri stream closep reason)
        (http-request uri
                      :method method
                      :content data
                      :content-type "application/json"
                      :external-format-in :utf-8
                      :external-format-out :utf-8
                      :parameters parameters
                      :want-stream T)
      (declare (ignore status headers uri stream reason))
      (unwind-protect
           (parse body)
        (when closep
          (close body))))))

(defclass <index> (<server>)
  ((index-name :initarg :index
               :reader index-name)))

(defclass <type> (<index>)
  ((type-name :initarg :type
              :reader type-name)))

(defmethod get-uri ((this <index>))
  (format nil "~A/~A"
               (call-next-method)
               (index-name this)))

(defmethod get-uri ((this <type>))
  (format nil "~A/~A"
               (call-next-method)
               (type-name this)))

(defgeneric get* (place contents))

(defclass <document> (<type>)
  ((id :initarg :id
       :reader document-id)
   (source :initarg :source
           :accessor document-source)
   (version :initarg :version
            :accessor version)
   (parent :initarg :parent
           :accessor parent)
   (fields :initarg :fields
           :accessor fields)))

(defmethod print-object ((obj <document>) stream)
   (print-unreadable-object (obj stream :type t :identity t)
     (format stream "/~A/~A/~A"
             (index-name obj)
             (type-name obj)
             (document-id obj))))

(defun pophash (key hash-table &optional default)
  (prog1 (gethash key hash-table default)
    (remhash key hash-table)))

(defun hash-to-document (hash-table &key host port)
  (let ((fields (gethash "fields" hash-table)))
    (make-instance '<document>
                   :index (gethash "_index" hash-table)
                   :type (gethash "_type" hash-table)
                   :id (gethash "_id" hash-table)
                   :version (gethash "_version" hash-table)
                   :source (or (and fields (car (pophash "_source" fields)))
                               (gethash "_source" hash-table))
                   :parent (and fields (pophash "_parent" fields))
                   :fields fields
                   :host host
                   :port port)))

(defclass <search> ()
  ((query :initarg :query
          :reader query)
   (timeout :initarg :timeout
            :reader timeout)
   (from :initarg :from
         :reader from)
   (size :initarg :size
         :reader size)
   (fields :initarg :fields
           :reader fields)
   (partial-fields :initarg :partial-fields
                   :reader partial-fields)
   (search-type :initarg :search-type)
   (query-cache :initarg :query-cache)
   (terminate-after :initarg :terminate-after
                    :reader terminate-after)
   (aggregations :initarg :aggregations
                 :reader aggregations)
   (suggestions :initarg :suggestions
                :reader suggestions)))

(defgeneric get-query-params (object))

(defmethod get-query-params ((this <search>))
  (awhen (slot-value this 'search-type)
    (cons (cons "search_type" it)
          (awhen (slot-value this 'query-cache)
            (list (cons "query_cache" it))))))

(defun new-search (query &key aggregations timeout
                           from size fields partial-fields
                           search-type query-cache
                           terminate-after suggestions)
  (make-instance '<search>
                 :query query
                 :timeout timeout
                 :from from
                 :size size
                 :fields (when fields)
                 :partial-fields partial-fields
                 :search-type (when search-type
                                (ecase search-type
                                  (:dfs-query-then-fetch
                                   "dfs_query_then_fetch")
                                  (:dfs-query-and-fetch
                                   "dfs_query_and_fetch")
                                  (:query-then-fetch
                                   "query_then_fetch")
                                  (:query-and-fetch
                                   "query_then_fetch")
                                  (:count
                                   "count")
                                  (:scan
                                   "scan")))
                 :query-cache (when query-cache
                                (ecase query-cache
                                  (:enable "true")
                                  (:disable "false")))
                 :terminate-after terminate-after
                 :aggregations aggregations
                 :suggestions suggestions))

(defmethod encode-slots progn ((this <search>))
  (with-object-element* ("query" (query this))
    (encode-object (query this)))
  (encode-object-element* "timeout" (timeout this))
  (encode-object-element* "from" (from this))
  (encode-object-element* "size" (size this))
  (encode-object-element* "terminate_after" (terminate-after this))
  (with-object-element* ("aggregations" (aggregations this))
    (with-object ()
      (loop for pair in (aggregations this) do
           (with-object-element ((car pair))
             (encode-object (cdr pair))))))
  (with-object-element* ("suggest" (suggestions this))
    (with-object ()
      (loop for pair in (suggestions this) do
           (with-object-element ((car pair))
             (encode-object (cdr pair))))))
  (encode-object-element* "fields" (fields this))
  (encode-object-element* "partial_fields" (partial-fields this)))

(defmethod get* ((place <server>) (query <search>))
  (let* ((result
          (send-request (format nil "~A/_search"
                                (get-uri place))
                        :get
                        :data (with-output-to-string* ()
                                (encode-object query))
                        :parameters (get-query-params query)))
         (hits (gethash "hits" result))
         (shards (gethash "_shards" result)))
    (values (mapcar #'hash-to-document (gethash "hits" hits))
            (gethash "aggregations" result)
            (list :hits (gethash "total" hits)
                  :shards (list :total (gethash "total" shards)
                                :failed (gethash "failed" shards)
                                :successful (gethash "successful" shards))
                  :timed-out (gethash "timed_out" result)
                  :took (gethash "took" result)))))

(defmethod get* ((place <type>) (document <document>))
  (let ((result
         (send-request
          (format nil "~A/~A" (get-uri place) (document-id document))
          :get)))
    (unless (gethash "found" result)
      (warn 'document-not-found))
    (hash-to-document result)))

(define-condition document-not-found (warning)
  ())

(defun document-by-id (place id)
  (get* place (make-instance '<document> :id id)))
