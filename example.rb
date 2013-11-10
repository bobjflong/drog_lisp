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

puts "======================================="

print LispMachine.run """
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

  (Call range 0 10)
)
"""

print "\n"
