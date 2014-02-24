
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
end

describe "stdlib macros" do
  it "escaping" do
    assert_equal [1,2,3,4], LispMachine.run(%Q(
      (Do
        (`(1 2 3 4))
      )
    ))
  end
end

