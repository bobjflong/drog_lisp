require 'minitest/autorun'
require 'drog_lisp'
require 'drog_lisp/sexprparser'
require 'drog_lisp/matcher'
require 'sxp'

describe "the drog_pattern array helper" do
  it "Allows easy macro definition using drog_patterns" do
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

    assert_equal 3, LispMachine.run(prog)

  end
end

