
require 'minitest/autorun'
require 'drog_lisp'

describe "stdlib functions" do
  it "map" do
    machine = LispMachine.new

    assert_equal [2,3,4,5], LispMachine.run(%Q(
      (Do
        (Func inc x) (Do (+ 1 x))
        (Call map inc (Cons 1 (Cons 2 (Cons 3 (Cons 4 null)))))
      )
    ))
  end

  it "filter" do
    machine = LispMachine.new

    assert_equal [2,4], LispMachine.run(%Q(
      (Do
        (Func is_even x) (Do (= (Send "to_f" 0) (% x (Send "to_f" 2))) )
        (Call filter is_even (Cons 1 (Cons 2 (Cons 3 (Cons 4 null)))))
      )
    ))
  end

  it "folds" do
    machine = LispMachine.new

    assert_equal 10, LispMachine.run(%Q(
      (Do
        (Call fold (lambda x y (+ x y)) 0 (`(1 2 4 3)))
      )
    ))
  end
end

describe "stdlib macros" do
  it "escaping" do
    assert_equal [1,2,3,4], LispMachine.run(%Q(
      (Do
        (`(1 2 3 4))
      )
    ))
  end

  it "function wrap" do
    assert_equal 4, LispMachine.run(%Q(
      (Do
        (Call
          (fwrap (+ 1 3))
        void)
      )
    ))

    assert_equal 4, LispMachine.run(%Q(
      (Do
        (Call
          (fwrap (+ (send_all (Cons :+ 1) 0) 3))
        void)
      )
    ))
  end

  it "message sending threading" do
    assert_equal "2013-03-04", LispMachine.run(%Q(
      (Do
        (send_all "to_s" (`(:new 2013 3 4)) :Date)
      )
    ))
    assert_equal "2013-03-04", LispMachine.run(%Q(
      (Do
        (-> "to_s" (`(:new 2013 3 4)) :Date)
      )
    ))
  end

  it "allows dot syntax for sending" do
    assert_equal Time, LispMachine.run(%Q(
      (Do (. :class (. :new :Time) ) )
    ))
  end

  it "allows sequences to be escaped" do
    assert_equal [:Foo, [1, 2, 3]], LispMachine.run(%Q(
      (Do
        (' (Foo (1 2 3)) )
      )
    ))
  end
  
  it "allows lambdas!" do
    assert_equal 42, LispMachine.run(%Q(
      (Do
        (Func adder x)
          (Do
            (lambda y ~(x) (+ x y)))

        (Let two-adder (Call adder 2))
        (Call two-adder 40)
      )
    ))
  end
end

