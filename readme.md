##drog_lisp

Embedded functional language for Ruby --- resembles scheme/lisp but with unique semantics.


#####Key features
* First class functions
* Closures
* Powerful macros, writable in Ruby
* Uses Ruby types, fully interoperable with Ruby
* Homoiconicity - write code that writes code
* Tail call optimization

#####Code samples:
* [Numerical differentiation + Newton's method](https://gist.github.com/bobjflong/7984315)
* [A static site generator](https://github.com/bobjflong/brig)

#####Examples:
######Recursive factorial:

```ruby
require 'drog_lisp'

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

######Closures

You can store values alongside function definitions to create closures using the tilde "~" directive:

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

  (Func create-adder start)
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
    (Set-name bob \"bob\")
    (Show (Get-name bob))
)
"""
```

######Macros

drog\_lisp includes an optional preprocessor that lets you design your own syntactic constructs. In this example I produce a scheme-like "let", which shifts and binds values into scope for a block. See a similar example at http://en.wikipedia.org/wiki/Scheme_(programming_language)#Minimalism. Note that this example is different to the primitive Let function in drog_lisp (which explictly writes a variable to the symbol table).

```ruby
require 'drog_lisp'
require 'drog_lisp/sexprparser'
require 'drog_lisp/matcher'
require 'sxp'

having = LispMacro.new 'having' do |ast|
  
  ast.drog_pattern 'having:variables:body' do |vars|
    
    #Grab entries from AST pattern
    having, variables, body = vars[:having], vars[:variables], 
      vars[:body]
    
    #Extract the binding names
    names = variables.map { |v| v[0] }
    #Extract the values
    values = variables.map { |v| v[1] }
    #Construct the anonymous function prototype
    prototype = [:Func, :_] + names
    (
      [
        :Call,
        prototype,
        [
          :Do,
          body
        ],
      ] + values
    ).to_sxp
  end
end

prog = %Q(
  (Do
    (having ((x 1) (y 2))
      (+ x y)
    )
  )
)

LispPreprocessor.preprocess prog, MacroList.new([having])

LispMachine.run(prog)
    

#=> 3


```

######Code as data

Build up your own expressions as data, then execute them:

```ruby
LispMachine.run """

(Do
  (Let operator :+)
  (Let my-calc (Cons operator (Cons 1 2)))
  (Evaluate my-calc)
)

"""

#=> 3
```

######Tail call optimization

You can instruct the interpreter to run your recursive definitions as a loop using the <code>RecCall</code> directive. This means that you won't run into stack overflows with deep recursion. Of course in order for this to work correctly the <code>RecCall</code> must be the last action of your function.

```ruby
LispMachine.run """
(Do
  (Func loop x)
    (Do
      (If (= x 100000)
        (Show \"done\")
        (RecCall loop (+ x 1))
      )
    )
  (Call loop 0)
)
"""

#=> done.
```

######Communicating with ruby objects

Use Send to send messages to underlying Ruby objects.

```ruby
len = LispMachine.run """
(Do
  (Let list (Cons 1 (Cons 2 (Cons 3 (Cons 4 5)))))
  (Let answer (Send :length list))
)
"""

# len = 5
```

```ruby
LispMachine.run """
(Do
  (Let time (Send :new :Time))
  (Send :class time)
)
"""

# => Time
```


