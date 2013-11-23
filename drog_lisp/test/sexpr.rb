
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

    assert_equal """(Do
        (If x y z)
        (When (x y z) j)
        (unless (k) (l y) m)
      )""", a.parsed[0]

    assert_equal """(If x y z)""", a.parsed[1]

    assert_equal """(When (x y z) j)""", a.parsed[2]

    assert_equal """(x y z)""", a.parsed[3]

    assert_equal """(unless (k) (l y) m)""", a.parsed[4]

    assert_equal """(k)""", a.parsed[5]

    assert_equal """(l y)""", a.parsed[6]

    assert_equal 7, a.positions.length

    correct_positions = [[7,90],[19,28],[38,53],[44,50],[63,82],[71,73],[75,79]]

    correct_positions.each_with_index do |v,i|
      assert_equal Position, a.positions[i].class

      assert_equal v[0], a.positions[i].start
      assert_equal v[1], a.positions[i].end
    end
    
  end
end
