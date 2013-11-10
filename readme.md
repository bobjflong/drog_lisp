##drog_lisp

#####Friendly embedded scheme/lisp for ruby.

Dynamic scoping + recursion.

#####Examples:
######Recursive factorial:

```ruby
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

# => 3628800
```

######Higher orderism, using cons, car cdr:

```ruby
#Double every number from 1 to 10
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

# => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
```