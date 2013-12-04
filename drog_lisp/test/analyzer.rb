
require 'minitest/autorun'
require 'drog_lisp/analyzer'
require 'drog_lisp'

describe "if analysis" do
  it "should turn an if statement into a function" do
    if_expr = ["if", ["<", ["get", "x"], ["get", "ten"]], ["get", "y"], ["get", "z"]]

    LispMachine::SYMBOL_TABLE[0][:x] = 1 
    LispMachine::SYMBOL_TABLE[0][:y] = 2
    LispMachine::SYMBOL_TABLE[0][:z] = 3
    LispMachine::SYMBOL_TABLE[0][:ten] = 10

#Double check we can still evaluate this stuff
    LispMachine.interpret [if_expr]
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 2
#Reset
    LispMachine.instance_variable_set('@last_evaluated', nil)
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), nil

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch if_expr

    assert analyzed.kind_of? Proc
    analyzed.call
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 2


  end    

  it "should turn a call into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    LispMachine::SYMBOL_TABLE[0][:ten] = 10
    LispMachine::SYMBOL_TABLE[0][:z] = 3

    LispMachine::SYMBOL_TABLE[0][:f] = {
      type: 'definition',
      contents: [["if", ["<", ["get", "x"], ["get", "ten"]], ["get", "y"], ["get", "z"]]],
      arguments: ['x','y'],
      name: :f
    }

    call_expr = ["call", "f", ["const", 5], ["const", 40]]

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch call_expr
    assert analyzed.kind_of? Proc

    analyzed.call
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 40

  end

  it "should turn a let into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)

    let_expr = ["let", "val", ["const", 10]]
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch let_expr
    assert analyzed.kind_of? Proc

    analyzed.call
    assert_equal LispMachine.lookup(LispMachine::SYMBOL_TABLE.length - 1, 'val'), 10
  end 
      
  
end
