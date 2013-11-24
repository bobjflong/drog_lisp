
require 'minitest/autorun'
require 'drog_lisp/sexprparser'
require 'drog_lisp'

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

    # Check that the found sexprs have correct corresponding positions in the real prog
    a.parsed.each_with_index do |v,i|
      assert_equal v, prog[a.positions[i].start..a.positions[i].end]
    end
    
  end

  it "Provides macro definitions with the AST of matching S-Exprs in the program" do
    
    prog = %Q(
        (Do
          (Swap (x) (y))
          (When (x y z) j)
          (unless (k) (l y) m)
        )
    )

    called = false

    foo = LispMacro.new 'Swap' do |ast|
      assert_equal 3, ast.length
      assert_equal :Swap, ast[0]
      assert_equal [:x], ast[1]
      assert_equal [:y], ast[2]

      called = true
      
      %Q(
        #{ast[2].to_sxp}
        #{ast[1].to_sxp}
      )

    end

    LispPreprocessor::preprocess prog, MacroList.new([foo])

    assert_equal true, called

    assert_equal %Q(
        (Do
          
        (y)
        (x)
      
          (When (x y z) j)
          (unless (k) (l y) m)
        )).strip, prog.strip
  end
  
  it "Allows for argument extraction and complex macros" do
    
    prog = %Q(
      (Do
        
        (letin (a 1) (b 2) (Do (Show (+ a b))))
  
      )
    )

    letin = LispMacro.new 'letin' do |ast|
      
      body = ast[-1].to_sxp
      
      func_params = ''
      func_args   = ''

      ast[1..-2].each do |param|
        func_params += "#{param[0].to_sxp} "
        func_args += "#{param[1].to_sxp} "
      end
      
      %Q(
        (Func tmp #{func_params})
          #{body}

        (Call tmp #{func_args})
      
      )
    end

    LispPreprocessor.preprocess prog, MacroList.new([letin])

    assert_output "3\n" do 
      LispMachine.run(prog)
    end

  end
  
end
