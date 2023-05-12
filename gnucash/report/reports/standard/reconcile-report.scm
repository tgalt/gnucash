;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; reconcile-report.scm : Reconciliation report
;;
;; calls functions defined in trep-engine.scm with defaults suitable
;; for a reconciliation report including alternative date filtering
;; strategy
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 2 of
;; the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, contact:
;;
;; Free Software Foundation           Voice:  +1-617-542-5942
;; 51 Franklin Street, Fifth Floor    Fax:    +1-617-542-2652
;; Boston, MA  02110-1301,  USA       gnu@gnu.org
;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(define-module (gnucash reports standard reconcile-report))

(use-modules (gnucash engine))
(use-modules (gnucash core-utils))
(use-modules (gnucash app-utils))
(use-modules (gnucash report))

(define (reconcile-report-options-generator)
  (let ((options (gnc:trep-options-generator)))
    (GncOption-set-value
     (gnc-lookup-option options "Sorting" "Primary Key") 'reconciled-status)
    (GncOption-set-value
     (gnc-lookup-option options "Sorting" "Secondary Key")   'date)
    (GncOption-set-value
     (gnc-lookup-option options "Sorting" "Secondary Subtotal for Date Key") 'none)
    (GncOption-set-value
     (gnc-lookup-option options gnc:pagename-general "Start Date")
     (cons 'relative 'start-prev-quarter))
    (GncOption-set-value
     (gnc-lookup-option options gnc:pagename-general "End Date")
     (cons 'relative 'today))
    (GncOption-set-value
     (gnc-lookup-option options gnc:pagename-general "Date Filter")
     'reconciled)
    (GncOption-set-value
     (gnc-lookup-option options gnc:pagename-display "Reconciled Date") #t)
    (GncOption-set-value
     (gnc-lookup-option options gnc:pagename-display "Running Balance") #f)
    (GncOption-set-value
     (gnc-lookup-option options gnc:pagename-display "Memo") #f)
    (GncOptionDBPtr-make-internal options gnc:pagename-display "Running Balance")
    options))

(define reconcile-report-instructions
  (gnc:make-html-text
   (G_ "The reconcile report is designed to be similar to the formal \
reconciliation tool. Please select the account from Report \
Options. Please note the dates specified in the options will apply \
to the Reconciliation Date.")
   (gnc:html-markup-br)
   (gnc:html-markup-br)))

(define (reconcile-report-calculated-cells options)
  (letrec
      ((split-amount (lambda (s tr?)
                       (if (gnc:split-voided? s)
                           (xaccSplitVoidFormerAmount s)
                           (xaccSplitGetAmount s))))
       (split-currency (compose xaccAccountGetCommodity xaccSplitGetAccount))
       (amount (lambda (s tr?)
                 (gnc:make-gnc-monetary (split-currency s) (split-amount s tr?))))
       (debit-amount (lambda (s tr?)
                       (and (positive? (split-amount s tr?))
                            (amount s tr?))))
       (credit-amount (lambda (s tr?)
                        (and (not (positive? (split-amount s tr?)))
                             (gnc:monetary-neg (amount s tr?))))))
    ;; similar to default-calculated-cells but disable dual-subtotals.
    (list (list (cons 'heading (G_ "Funds In"))
                (cons 'calc-fn debit-amount)
                (cons 'reverse-column? #f)
                (cons 'subtotal? #t)
                (cons 'start-dual-column? #f)
                (cons 'friendly-heading-fn (const ""))
                (cons 'merge-dual-column? #t))
          (list (cons 'heading (G_ "Funds Out"))
                (cons 'calc-fn credit-amount)
                (cons 'reverse-column? #f)
                (cons 'subtotal? #t)
                (cons 'start-dual-column? #f)
                (cons 'friendly-heading-fn (const ""))
                (cons 'merge-dual-column? #f)))))

(define (reconcile-report-renderer rpt)
  (gnc:trep-renderer
   rpt
   #:custom-calculated-cells reconcile-report-calculated-cells
   #:empty-report-message reconcile-report-instructions))

(gnc:define-report
 'version 1
 'name (G_ "Reconciliation Report")
 'report-guid "e45218c6d76f11e7b5ef0800277ef320"
 'options-generator reconcile-report-options-generator
 ;; the renderer is the same as trep, however we're using a different
 ;; split-date strategy.  we're comparing reconcile date for
 ;; inclusion, and if split is unreconciled, include it anyway.
 'renderer reconcile-report-renderer)

