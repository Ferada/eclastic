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
  (:documentation
   "Import and re-export the symbols that make up the public interface
   of Eclastic.")
  (:use :eclastic.generic
        :eclastic.server
        :eclastic.document
        :eclastic.search
        :eclastic.script
        :eclastic.bulk)
  (:export :get*
           :index
           :create
           :update
           :delete*

           :<server>
           :host
           :port
           :index-name
           :<type>
           :type-name

           :<document>
           :document-id
           :document-source
           :version
           :routing
           :parent-of
           :document-not-found
           :document-with-id
           :document-by-id

           :<search>
           :new-search
           :sort-by

           :<script>
           :define-script
           :encode-script

           :with-bulk-documents))
