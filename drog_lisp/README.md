##drog_lisp

Embedded functional language for Ruby --- resembles scheme/lisp but with unique semantics.

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
        (Cons (Call f (Car n)) null)
      )
    )

  (Call apply-list (Call range 1 10) double)

)
"""

# => [2, 4, 6, 8, 10, 12, 14, 16, 18, 20]
```

######Enforcing lexical scoping + closures

You can store values alongside function definitions to enforce lexical scoping and closure functionality using the tilde "~" directive:

```ruby
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

#> 4
#> 5
# Original value of x was used in function as it was included in the closure list using "~"


```

######Closures

Classic example of closures, an accumulative adder:

```ruby
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

#> 10
#> 15
```

######Continuations

drog_lisp neatly wraps Ruby's callcc function to provide expressive continuation support. In the following example I use the CallCC directive to return to a calling function after making nested calls:

```ruby
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
      (Show 13)
    )

  (Show (+ 0 (CallCC count-part-one)))

)

"""

#> 3
#> 2
#> 1
```

In the next example I use continuations to produce couroutines easily:

```ruby
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

#> 1
#> 2
#> 3
#> 4
```

######Structs

Setters & getter functions handled dynamically

```ruby
LispMachine.run """

(Do
  (Let bob (Struct name age))
    (Set-age bob 21)
    (Set-name bob 'bob')
    (Show (Get-name bob))
)
"""
```