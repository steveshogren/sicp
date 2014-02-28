(define x 10)

(parallel-execute (lambda () (set! x (* x x)))
                  (lambda () (set! x (+ x 1))))

;; with interleaving, all these are possible:
;; 101 - p1, then p2
;; 121 - p2, then p1
;; 110 - interleaved..
;; 11 - interleaved..
;; 100 - interleaved..

;; (make-serializer <p>) will ensure no other process
;; can be interleavened with p's execution

;; 3.39
;; What are the possible results of this?
(define x 10)
(define s (make-serializer))
(parallel-execute (lambda () (set! x ((s (lambda () (* x x))))))a
                  (s (lambda () (set! x (+ x 1)))))

;; because the serializer will still prevent interleavening,
;; regardless of the lambda, only 101, and 121 will be options

;; 3.40
;; All possible values of x:
(define x 10)
(parallel-execute (lambda () (set! x (* x x)))
                  (lambda () (set! x (* x x x))))

;; a12->b123 = 10*10 = 100 * 100 * 100 = 1000000
;; b123->a12 = 10*10*10 = 1000 * 1000  = 1000000
;; a1->b123->a2 = 10 * (1000)          = 10000
;; b1->a12->b23 = 10 * (100) * (100)   = 100000
;; b12->a12->b3 = 10 * 10 * (100)      = 10000

(define x 10)
(define s (make-serializer))
(parallel-execute (s (lambda () (set! x (* x x))))
                  (s (lambda () (set! x (* x x x)))))
;; a12->b123 = 10*10 = 100 * 100 * 100 = 1000000
;; b123->a12 = 10*10*10 = 1000 * 1000  = 1000000

;; 3.41
(define (make-account balance)
  (define (withdraw amount)
    (if (>= balance amount)
        (begin (set! balance (- balance amount))
               balance)
        "Insufficient funds"))
  (define (deposit amount)
    (set! balance (+ balance amount))
    balance)
  (let ((protected (make-serializer)))
    (define (dispatch m)
      (cond ((eq? m 'withdraw) (protected withdraw))
            ((eq? m 'deposit) (protected deposit))
            ((eq? m 'balance) ((protected (lambda () balance))))
            (else (error "Unknown request -- MAKE-ACCOUNT"
                         m))))
    dispatch))


;; This new make-account can prevent interleavening such as:
(define a (make-account 50))
(parallel-execute (lambda () ((a 'withdraw) 50))
                  (lambda () ((a 'withdraw) 50)))
;; Which could result in both checks to (>= balance amount)
;; happening at the same time, before the (set!) occurs

;; 3.42
;; Ben's new make-account with a single serialized function
(define (make-account balance)
  (define (withdraw amount)
    (if (>= balance amount)
        (begin (set! balance (- balance amount))
               balance)
        "Insufficient funds"))
  (define (deposit amount)
    (set! balance (+ balance amount))
    balance)
  (let ((protected (make-serializer)))
    (let ((protected-withdraw (protected withdraw))
          (protected-deposit (protected deposit)))
      (define (dispatch m)
        (cond ((eq? m 'withdraw) protected-withdraw)
              ((eq? m 'deposit) protected-deposit)
              ((eq? m 'balance) balance)
              (else (error "Unknown request -- MAKE-ACCOUNT"
                           m)))))
    dispatch))
;; This is a safe change to make, even the balance will never
;; be in an "intermediate" state, it is either before or after,
;; no invalid between


;; Demontration of when a simple serializer breaks down,
;; i.e. the withdraw then deposit between two accounts
(define (exchange account1 account2)
  (let ((difference (- (account1 'balance)
                       (account2 'balance))))
    ((account1 'withdraw) difference)
    ((account2 'deposit) difference)))

;; This works for two accounts, a1 and a2, but breaks down when
;; there are three, i.e. a1->a2 and a1->a3 concurrently


;; One way to solve this is to get a reference to the
;; serializer used in the account function

(define (make-account balance)
  (define (withdraw amount)
    (if (>= balance amount)
        (begin (set! balance (- balance amount))
               balance)
        "Insufficient funds"))
  (define (deposit amount)
    (set! balance (+ balance amount))
    balance)
  (let ((balance-serializer (make-serializer)))
    (define (dispatch m)
      (cond ((eq? m 'withdraw) protected-withdraw)
            ((eq? m 'deposit) protected-deposit)
            ((eq? m 'balance) balance)
            ((eq? m 'serializer) balance-serializer)
            (else (error "Unknown request -- MAKE-ACCOUNT"
                         m))))
    dispatch))

;; To use this we must now correctly use the serializer to
;; combine to get our desired behavior
(define (deposit account amount)
  (let ((s (account 'serializer))
        (d (account 'deposit)))
    ((s d) amount)))

(define (serialized-exchange account1 account2)
  (let ((serializer1 (account1 'serializer))
        (serializer2 (account2 'serializer)))
    ((serializer1 (serializer2 exchange))
     account1
     account2)))

;; 3.44
;; Does this need a sophisticated method for transacting,
;; like with exchange?
(define (transfer from-account to-account amount)
  ((from-account 'withdraw) amount)
  ((to-account 'deposit) amount))

;; A transfer does not need anything special, since it is
;; acceptable to have a point when the money is "nowhere",
;; unless there is a concern over the machine failing
;; partway through the transaction, and then the money would
;; be lost.

;; 3.45
;; Is this a better way to mix the account serializing
;; but also get access to the serializer for combinations?
(define (make-account-and-serializer balance)
  (define (withdraw amount)
    (if (>= balance amount)
        (begin (set! balance (- balance amount))
               balance)
        "Insufficient funds"))
  (define (deposit amount)
    (set! balance (+ balance amount))
    balance)
  (let ((balance-serializer (make-serializer)))
    (define (dispatch m)
      (cond ((eq? m 'withdraw) (balance-serializer protected-withdraw))
            ((eq? m 'deposit) (balance-serializer protected-deposit))
            ((eq? m 'balance) balance)
            ((eq? m 'serializer) balance-serializer)
            (else (error "Unknown request -- MAKE-ACCOUNT"
                         m))))
    dispatch))

;; No, now the serialized-exchange will be trying to serialize
;; the same function twice, or rather "grouping" them, which
;; should result in an infinite loop as the lock of the outer
;; is never released to let the inner start. To do this, a more
;; sophisticated "inner" and "outer" serializer would be needed.


