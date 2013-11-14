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

  (Func create-adder start void)
    (Do
      (Let x start)
      (Func adder val ~(x))
        (Do
          (Let x (+ x val))
        )
    )
    
  (Let my-adder (Call create-adder 5))
  (Show (Call my-adder 5))
  (Show (Call my-adder 5))

)
"""

puts "----------------------------"
puts "Continuations"
puts "----------------------------"

LispMachine.run """

(Do

  (Func count-part-two cont)
    (Do
      (Show 2)
      (Call cont 1)
    )

  (Func count-part-one c)
    (Do
      (Show 3)
      (Call count-part-two c)
    )

  (Show (+ 0 (CallCC count-part-one)))

)

"""

puts "----------------------------"
puts "Coroutines"
puts "----------------------------"

LispMachine.run """

(Do

  (Func routine-even other-routine)
    (Do
      (Show 2)
      (Let other-routine (CallCC other-routine))
      
      (Show 4)
      (Let other-routine (CallCC other-routine))
    )
  
  (Func routine-odd other-routine)
    (Do
      (Show 1)
      (Let other-routine (CallCC other-routine))

      (Show 3)
      (Let other-routine (CallCC other-routine))
    )
  
  (Call routine-odd routine-even)

)

"""


