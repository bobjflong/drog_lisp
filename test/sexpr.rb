
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
          (Swap (a) (b))
          (When (x y z) j)
          (unless (k) (l y) m)
        )
    )

    called = false

    foo = LispMacro.new 'Swap' do |ast|
      assert_equal 3, ast.length
      assert_equal :Swap, ast[0]

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


        (b)
        (a)

          (When (x y z) j)
          (unless (k) (l y) m)
        )).gsub(/\s+/,''), prog.gsub(/\s+/,'')
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

  it "Allows list literals to be built" do
    prog = %Q(
    (Do
      (Show (Evaluate (list (:Do (:Show \"hello\")))))
      (Show
        (Evaluate
          (list 
            (:Do 
              (:Func :f :x :y )
                (:Do
                  (:Show \"inside\")
                  (:+ :x :y)
                )
              (:Call :f 10 2)
            )
          )
        )
      )
    )
    )

    list_literal = LispMacro.new 'list' do |ast|
      elems = ast.drop(1)
      elems.to_cons
    end

    LispPreprocessor.preprocess prog, MacroList.new([list_literal])

    assert_output "hello\nhello\ninside\n12\n" do
      LispMachine.run prog
    end
  end

  it "Allows macros to use other macros in their definition" do
    prog = %Q(
    
    (Do
      (inc 10)
    )

    )

    add = LispMacro.new 'add' do |ast|
      left = ast[1].to_sxp
      right = ast[2].to_sxp
      "(+ #{left} #{right})"
    end

    inc = LispMacro.new 'inc' do |ast|
      left = ast[1].to_sxp
      right = 1.to_sxp
      "(add #{left} #{right})"
    end

    LispPreprocessor.preprocess prog, MacroList.new([add, inc])
    assert_equal LispMachine.run(prog), 11
  end

  it "allows code to be mutated" do
    list_literal = LispMacro.new '`' do |ast|
      elems = ast.drop(1)
      elems.to_cons
    end

    class Array
      def setzero x
        self[0] = x
      end
    end
  
    prog = """
    (Do
      (Let my-prog
        (`
          (:Func :inc :x)
            (:Do 
              (:+ :x 1)
            )

          (:Call :inc 1)
        )
      )

      (Show (Evaluate my-prog))
      
      (Let replace-with-minus-args (`( :setzero :- )))
      (Send replace-with-minus-args (Car (Cdr (Car (Cdr (my-prog))))))

      (Show (Evaluate my-prog))
    )
    """
    LispPreprocessor.preprocess prog, MacroList.new([list_literal])

    assert_output "2\n0\n" do
      LispMachine.run prog
    end
    
  end

  it "allows the example from the blog" do
    list_literal = LispMacro.new '`' do |ast|
      elems = ast.drop(1)
      elems.to_cons
    end
  
    prog = """
      (Do
        (Let my-prog
          (`
            (:Do (:Func :add :x :y)
              (:Do 
                (:+ :x :y)
              )

            (:Call :add 1 2)
            )
          )
        )

        (Show (Evaluate my-prog))
      )
    """
    
    LispPreprocessor.preprocess prog, MacroList.new([list_literal])

    assert_output "3\n" do
      LispMachine.run prog
    end
  end
  
  it "does not interfere with brackets in strings" do
    display = LispMacro.new "display" do |ast|
      """(Show #{ast[1].to_sxp})"""
    end
    
    prog = """
    (Do
      (display \"hello :)\")
    )
    """
    
    LispPreprocessor.preprocess prog, MacroList.new([display])
    
    assert_output "hello :)\n" do
      LispMachine.run prog
    end
  end
end
