;; wok.scm -- statically typed concatenative language compiler.
;; Copyright (C) 2019 Wolfgang Jährling

(define defs '((+ (int int) (int))
               (drop (any) ())
               (= (int int) (bool))
               (foo () ((addr int)))
               (at ((addr int)) (int))
               (nil? ((ptr any)) (bool))
               (not (bool) (bool))))

(define (fail)
  (eval '(#f)))

(define (say . text)
  (for-each display text)
  (newline))

(define (error . text)
  (apply say text)
  (fail))

(define current '())

(define (set-current! types)
  ;(say "new:" types)
  (set! current types))

(define (current+ t)
  (set-current! (cons t current)))

(define (current- t)
  (if (null? current)
      (error "requested " t " but stack is empty")
      (if (use-as-type? t (car current))
          (set-current! (cdr current))
          (error "requested " t " but having " (car current)))))

(define (apply-call-effect op)
  (let ((effect (cdr (assq op defs))))
    (current-replace (car effect) (cadr effect))))

(define (current-replace old new)
  (current-multi- old)
  (current-multi+ new))

(define (current-multi+ types)
  (for-each current+ (reverse types)))

(define (current-multi- types)
  (for-each current- types))

(define (apply-effect code)
  (for-each (lambda (element)
              (cond ((symbol? element) (apply-call-effect element))
                    ((number? element) (current+ 'int))
                    ((list? element) (apply-structure-effect element))))
            code))

(define (apply-structure-effect struct)
  (case (car struct)
    ((eif) (begin
            (current- 'bool)
            (let ((prev current))
              (apply-effect (cadr struct))
              (let ((t-branch current))
                (if (not (null? (cddr struct)))
                    (begin
                      (set-current! prev)
                      (apply-effect (caddr struct))
                      (if (not (branch= t-branch current))
                          (error "incompatible branches from " prev " to "
                                 t-branch " vs. " current)
                          (unify-branches t-branch current))))))))
    ((if) (begin
            (current- 'bool)
            (let ((prev current))
              (apply-effect (cadr struct))
              (if (not (branch= prev current))
                  (error "then-branch left stack as " current
                         "instead of " prev)
                  (unify-branches prev current)))))
    ((on) (fail))
    ((eon) (fail))
    ((cast) (if (null? current)
                (error "cast to " (cadr struct) " on empty stack")
                (set-current! (cons (cadr struct)
                                    (cdr current)))))
    ((break) (fail))
    ((loop) (fail))))

(define (branch= variant1 variant2)
  (cond ((null? variant1) (null? variant2))
        ((null? variant2) #f)
        ((type= (car variant1) (car variant2))
         (branch= (cdr variant1) (cdr variant2)))
        (else #f)))

(define (type= t1 t2)
  (or (eq? t1 'any)
      (eq? t2 'any)
      (eq? t1 t2)
      (and (list? t1)
           (list? t2)
           (eq? (car t1) (car t2))
           (type= (cadr t1) (cadr t2)))))

(define (use-as-type? sup sub)
  (or (eq? sup 'any)
      (eq? sub 'any)
      (eq? sub sup)
      (and (list? sup)
           (list? sub)
           (eq? (car sup) (car sub))
           (type= (cadr sup) (cadr sub)))
      (and (list? sup)
           (list? sub)
           (eq? 'ptr (car sup))
           (eq? 'addr (car sub))
           (type= (cadr sup) (cadr sub)))))

(define (unify-branches b1 b2)
  (set-current! (map (lambda (t1 t2)
                       (if (eq? t1 'any) t2 t1))
                     b1 b2)))

(define (unify-types t1 t2)
  (cond ((eq? t1 t2) t1)
        ((eq? t1 'any) t2)
        ((eq? t2 'any) t1)
        ((and (list? t1)
              (list? t2)
              (or (and (eq? (car t1) 'addr)
                       (eq? (car t2) 'ptr))
                  (and (eq? (car t1) 'ptr)
                       (eq? (car t2) 'addr)))) (cons 'ptr (car t1)))))

(apply-effect '(1 (cast any)
                  1 1 1 1 = (eif (+) (drop)) (cast bool)
                  (if (drop 1))))
(apply-effect '(1 (cast (addr int)) at))
(apply-effect '(1 (cast (addr int)) nil?))

(display current)
(newline)

;; what is nonsymmetrical about typechecks?
;; can use @foo as ^foo, but not inverse
