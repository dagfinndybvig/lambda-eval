(define Y
  (lambda (f)
    ((lambda (x) (f (lambda (v) ((x x) v))))
     (lambda (x) (f (lambda (v) ((x x) v))))))
)

(define fact
  (Y
    (lambda (fact)
      (lambda (n)
        (if (= n 0)
            1
            (* n (fact (- n 1)))))))
)

(fact 5)
