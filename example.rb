load 'machine.rb'

number = 10
=begin
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
=end
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

)
"""

print "\n"

print LispMachine.run """
(Do
  
  (Func double x)
    (Do
      (* x 2)
    )

  (Func apply-list n f)
    (Do
      (If (Cdr n)
        (Cons (Call f (Car n))
          (Call apply-list (Cdr n))
        )
        null
      )
    )
  
  (Call apply-list (Call range 1 11) double)

)
"""

print "\n"