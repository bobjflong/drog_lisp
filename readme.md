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

######Using cons to calculate ranges:

```ruby
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

# => [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]

```