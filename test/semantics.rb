
require 'minitest/autorun'
require 'drog_lisp'
require 'ostruct'

describe "immediate function execution" do
  it "allows functions to be defined and evaluated immediately" do
    assert_equal 10, LispMachine.run(%Q(
        (Do
          (Func _ x y z)
            (Do
              (Func _ void ~(x y z))
              (Do
                ( * z ( + x y ) )
              )
            )
          (Call (Call _ 4 1 2) void)
        )
      )
    )
  end
  
  it "allows function definitions in Call directives" do
    assert_equal 13, LispMachine.run(%Q(
          (Do

            (Call
              
              (Func add x y)
                (Do (+ x y))
            
            10 3)
        )
      )
    )
  end

  it "allows anonymous functions" do
    assert_equal 42, LispMachine.run(%Q(
        (Do
          (Call
            (lambda void
              (Do
                (Call
                  (lambda x
                    (Do x)
                  )
                  42
                )
              )
            )
            void
          )
        )
      )
    )
  end
end

describe "comments" do
  it "allows comments to be written using semicolon" do
    assert_output "hello world\n" do
      LispMachine.run """
        (Do
          ; This prints out hello world
          (Show \"hello world\")
        )
      """
    end
  end

  it "doesn't interfere with semicolons in strings" do
    assert_output "hello; world\n" do
      LispMachine.run """
      (Do
        ; This is a comment
        (Show \"hello; world\")
      )
      """
    end
  end
end

describe "structs" do
  it "can create an underlying OpenStruct given field parameters" do
    assert_equal (LispMachine.run """
      (Do
        (Struct name age)
      )
    """).class, OpenStruct
  end

  it "creates the correct variable entries on creation" do
    assert_output "#<OpenStruct name=nil, age=nil>\n" do 
      (LispMachine.run """
        (Do
          (Show (Struct name age))
        )
      """)
    end
  end
  
  it "generates dynamic setters for fields" do 
    assert_output "#<OpenStruct name=\"bob\", age=21>\n" do
      (LispMachine.run """
        (Do
          (Let bob (Struct name age))
          (Set-age bob 21)
          (Set-name bob \"bob\")
          (Show bob)
        )
      """)
    end
  end

  it "generates dynamic getters for fields" do 
    assert_output "bob\n" do
      (LispMachine.run """
        (Do
          (Let bob (Struct name age))
          (Set-age bob 21)
          (Set-name bob \"bob\")
          (Show (Get-name bob))
        )
      """)
    end
  end
end

describe "escaping" do
  it "escapes lists" do
    assert_equal [1,2,3], LispMachine.run(%Q(
      (Do
        (!
          !(1 2 3)
        !)
      )
    ))
  end
end

describe "variadic functions" do
  it "passes all arguments as a list" do
    assert_equal [1,2,3], LispMachine.run(%Q(
      (Do
        (Func add x y)
          (Do
            (+ x y)
            arguments)
          (Call add 1 2 3)
      )
    ))
  end
end

describe "tail optimization" do
  it "can handle crazy levels of recursion" do
    assert_output "done\n" do
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
    end
  end

  it "can switch between functions in a tail call" do
    assert_output "1\n2\n" do
      LispMachine.run """
      (Do
        (Func two void)
          (Do
            (Show 2)
          )

        (Func one void)
          (Do
            (Show 1)
            (RecCall two void)
          )

        (Call one void)
      )
      """
    end
  end

  it "supports function literals in tail calls" do
    assert_output "1\n2\n" do
      LispMachine.run """
      (Do
        (Func one void)
          (Do
            (Show 1)
            (RecCall (Func _ void) (Do (Show 2)) void)
          )

        (Call one void)
      )
      """
    end
  end
end

describe "basic arithmetic" do
  it "can add numbers" do
    assert_equal (LispMachine.run """
      (Do
        (+ 10 3)
      )
    """), 13
  end

  it "can sub numbers" do
    assert_equal (LispMachine.run """
      (Do
        (- 16 3)
      )
    """), 13
  end

  it "can div numbers" do
    assert_equal (LispMachine.run """
      (Do (/ 15 5))
    """), 3
  end
end

describe "test recursion" do
  it "can use the typical recursive definition to calculate factorial" do
    
    number = 10
    assert_equal (LispMachine.run """
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
    """), 3628800
  end
end

describe "test cons" do
  it "can compute ranges using cons" do
    assert_equal (LispMachine.run """
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

        (Call range 1 10)

      )
      """), [1,2,3,4,5,6,7,8,9,10]
  end 

end

describe "first class functions" do
  it "can double a list using first class functions, cons, car, cdr" do
    assert_equal (LispMachine.run """
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
        
        (Func double x)
          (Do
            (* x 2)
          )

        (Func apply-list n f )
          (Do
            (If (Cdr n)
              (Cons (Call f (Car n))
                (Call apply-list (Cdr n) f)
              )
              (Cons (Call f (Car n)) null)
            )
          )
        
        (Call apply-list (Call range 1 10) double)

      )
      """), [2,4,6,8,10,12,14,16,18,20]
  end
end

describe "function application" do
  it "exposes an 'Apply' function" do
    assert_equal 42, (LispMachine.run """
      (Do
        (Apply
          (Func _ x y)
            (Do (+ x y))
         
         (Cons 40 2)
        )
      )
    """)
  end

  it "allows the ycombinator to be written" do
    assert_equal 720, (LispMachine.run """
      (Do
        
        (Func y f)
          (Do
            (Call
              (Func _ x)
                (Do (Call x x))

              (Func _ g ~(f))
                (Do
                  (Call f
                    (Func _ args ~(g))
                      (Do
                        (Apply (Call g g) args)
                      )
                  )
                )
            )
          )

        (Func factorial f)
          (Do
            (Func fact-inner n ~(f))
              (Do
                (If (< n 2)
                  1
                  (* n (Call f (- n 1)))
                )
              )
          )
        (Call (Call y factorial) 6)
      )
    """)
  end
end

describe "closures" do
  it "closes over variables in scope" do

    assert_output "4\n5\n" do
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
    end
  end

  it "closes over variables after execution" do
    assert_output "10\n15\n12\n20\n" do
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
          (Let my-adder-six (Call create-adder 6))
          (Show (Call my-adder-six 6))
          (Show (Call my-adder 5))
        )
      """
    end
  end
end

describe "continuations" do
  it "allows continuations to be used as 'early return'" do
    assert_output "3\n2\n1\n" do
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
    end
  end

  it "allows continuations to be used to construct continuations" do
    assert_output "1\n2\n3\n4\n" do
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
    end
  end
end

describe "symbols" do
  it "allows symbols to be created using a quote syntax" do
    assert_equal (LispMachine.run """
    
    (Do
      :x
    )
  
    """), :x
  end

  it "allows code as data to be built up" do
    assert_equal (LispMachine.run """
      
    (Do
      (Let operator :+)
      (Cons operator (Cons 1 2))

    )

    """), [:+, 1, 2]
  end

  it "allows code as data to be executed" do
    assert_equal (LispMachine.run """
    
    (Do
      (Let operator :+)
      (Let my-calc (Cons operator (Cons 1 2)))
      (Evaluate my-calc)
    )
    
    """), 3
  end

  it "allows code as string to be evaluated" do
    assert_equal 4, LispMachine.run(%Q(
      (Do
        (Evaluate "(Do (+ 1 3))")
      )
    ))
  end
end

describe "message sending" do
  it "should be able to communicate with ruby native types" do
    assert_equal (LispMachine.run """
    (Do
      (Let list (Cons 1 (Cons 2 (Cons 3 (Cons 4 5)))))
      (Let answer (Send :length list))
    )
  
    """), 5
  end

  it "should allow arguments to be passed to ruby native types" do
    assert_equal (LispMachine.run """
    (Do
      (Send (Cons :delete \"h\") \"hello\")
    )
    """), "ello"
  end

  it "should allow static ruby methods to be called" do
    assert_equal (LispMachine.run """
    (Do
      (Let time (Send :new :Time))
      (Send :class time)
    )
    """), Time
  end

end

describe "preloading objects" do
  it "allows objects to be loaded before execution" do
    
    class Dog
      def bark
        puts "woof"
      end
    end
  
    jim = Dog.new

    assert_output "woof\n" do
   
      LispMachine.run """
      (Do
        (Send :bark mydog)
      )
      """, { mydog: jim }
    end

  end
end

describe "mutable variables" do
  it "allows symbol table entries to be overwritten" do
    assert_equal (LispMachine.run """
      (Do
        (Let x 5)

        (Func overwrite void)
          (Do (Reset x 6) )

        (Call overwrite void)
        (x)
      )
    """), 6
  end
end

describe "logic operations" do
  it "allows logical operations to be performed" do
    
    assert_equal (LispMachine.run """
    (Do

      (Func and x y)
        (Do
          (If x y x)
        )

      (Call and (< 1 2) (< 2 3))

    )
    """), true

    assert_equal (LispMachine.run """
    (Do
      (Func or x y)
        (Do
          (If x x y)
        )

      (Call or (< 1 2) (< 3 2))
    )
    """), true
  end
end


