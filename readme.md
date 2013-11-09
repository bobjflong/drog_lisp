##drog_lisp

#####Friendly embedded scheme/lisp for ruby.

Dynamic scoping + recursion.

<pre>

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
</pre>
Macros are coming soon.