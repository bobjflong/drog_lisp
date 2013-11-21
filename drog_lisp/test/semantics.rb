
require 'minitest/autorun'
require 'drog_lisp'
require 'ostruct'

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
          (Set-name bob 'bob')
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
          (Set-name bob 'bob')
          (Show (Get-name bob))
        )
      """)
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
end

describe "test recursion" do
  it "returns the factorial of the number 10" do
    
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
                (Call apply-list (Cdr n))
              )
              (Cons (Call f (Car n)) null)
            )
          )
        
        (Call apply-list (Call range 1 10) double)

      )
      """), [2,4,6,8,10,12,14,16,18,20]
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

