
require 'minitest/autorun'
require 'drog_lisp/sexprparser'

describe "S-Expression extraction" do
  it "Produces a list of correct S-Expressions given a drog_lisp program" do
    prog = %Q(
      (Do
        (If x y z)
        (When (x y z) j)
        (unless (k) (l y) m)
      )
    )

    a = SexprParser.new prog
    a.find_sexprs
    assert_equal 7, a.parsed.length

    assert_includes a.parsed, """(Do
        (If x y z)
        (When (x y z) j)
        (unless (k) (l y) m)
      )"""

    assert_includes a.parsed, """(If x y z)"""

    assert_includes a.parsed, """(When (x y z) j)"""

    assert_includes a.parsed, """(x y z)"""

    assert_includes a.parsed,  """(unless (k) (l y) m)"""

    assert_includes a.parsed,  """(k)"""

    assert_includes a.parsed,  """(l y)"""

    assert_equal 7, a.positions.length

    assert_equal true, a.positions.all? { |p| p.kind_of? Position }

    correct_positions = [[7,90],[19,28],[38,53],[44,50],[63,82],[71,73],[75,79]]

    correct_positions.each_with_index do |v,i|
      
      assert_equal true, a.positions.any? do |p|
        p.start == v[0]
        p.end   == v[1]
      end

    end
    
  end
end
