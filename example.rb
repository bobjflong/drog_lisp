load 'machine.rb'

number = 10

puts LispMachine.run """
(Do

  (Func fact x)
    (Do
      (If (< x 1)
        1
        (* x (Call fact (- x 1)))
      )
    )
  (Call fact #{number})

)
"""

LispMachine.run """
(Do

  (Func range x n)
    (Do
      (If (= x n)
        (Cons x null)
        (Cons x 
          (Call range (+ 1 x) n)
        )
      )
    )

)
"""

print "\n"

print LispMachine.run """
(Do
  
  (Func double x)
    (Do
      (* x 2)
    )

  (Func apply-list n f )
    (Do
      (If (Cdr n)
        (Cons (Call f (Car n))
          (Call apply-list (Cdr n))
        )
        (Cons (Call f (Car n)) null)
      )
    )
  
  (Call apply-list (Call range 1 10) double)

)
"""
print "\n"

LispMachine.run """

(Do

  (Let x (+ 3 1))
  
  (Func example void ~(x))
    (Do
      (Show x)
    )
    
  (Let x 5)
  
  (Call example void)  
  (Show x)
  
)

"""


LispMachine.run """

(Do

  (Func create-closure void)
    (Do
      (Let x 13)
      (Func use-closed-value void ~(x))
        (Do
          (Show x)
        )
    )
    
  (Let my-closure (Call create-closure void))
  (Call my-closure void)

)
"""

