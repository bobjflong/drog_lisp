
require 'minitest/autorun'
require 'drog_lisp/analyzer'
require 'drog_lisp'
require 'ostruct'

describe "cond analysis" do
  
  it "should turn an if statement into a function" do
    if_expr = ["if", ["<", ["get", "x"], ["get", "ten"]], ["get", "y"], ["get", "z"]]

    LispMachine::SYMBOL_TABLE[0][:x] = 1 
    LispMachine::SYMBOL_TABLE[0][:y] = 2
    LispMachine::SYMBOL_TABLE[0][:z] = 3
    LispMachine::SYMBOL_TABLE[0][:ten] = 10

    LispMachine.interpret [if_expr]
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 2
    
    LispMachine.instance_variable_set('@last_evaluated', nil)
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), nil

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch if_expr

    assert analyzed.kind_of? Proc
    analyzed.call
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 2


  end
end

describe "call analysis" do

  it "should turn a call into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    LispMachine::SYMBOL_TABLE[0][:ten] = 10
    LispMachine::SYMBOL_TABLE[0][:z] = 3
    
    analyzer = Analyzer.new

    LispMachine::SYMBOL_TABLE[0][:f] = {
      type: 'definition',
      contents: analyzer.dispatch([["if", ["<", ["get", "x"], ["get", "ten"]], ["get", "y"],
      ["get", "z"]]]),
      arguments: ['x','y'],
      name: :f
    }

    call_expr = ["call", "f", ["const", 5], ["const", 40]]

    analyzed = analyzer.dispatch call_expr
    assert analyzed.kind_of? Proc

    analyzed.call

    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 40

  end
end

describe "let binding analysis" do

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

describe "struct analysis" do

  it "should turn a struct directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    struct_expr = ["struct", "name", "age"]
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch struct_expr

    analyzed.call
    assert LispMachine.instance_variable_get('@last_evaluated').kind_of? OpenStruct
  end

  it "should turn a struct-set directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    struct_expr = ["let", "bob",["struct", "name", "age"]]
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch struct_expr

    analyzed.call
    struct_set_expr = ["set", "Set-name", ["get", "bob"], ["const", "bobaroo"]]

    analyzed = analyzer.dispatch struct_set_expr
    analyzed.call
    assert_equal LispMachine.lookup(LispMachine::SYMBOL_TABLE.length - 1, 'bob').name, "bobaroo"
  end

  it "should turn a struct-get directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    struct_expr = ["let", "bob",["struct", "name", "age"]]
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch struct_expr

    analyzed.call
    struct_set_expr = ["set", "Set-name", ["get", "bob"], ["const", "bobaroo"]]

    analyzed = analyzer.dispatch struct_set_expr
    analyzed.call
    
    struct_get_expr = ["gets", "Get-name", ["get", "bob"]]
    analyzed = analyzer.dispatch struct_get_expr
    analyzed.call
   
  end
end

describe "func definition analysis" do

  it "should store a function definition as a ruby proc" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    
    func_expr = ["def", "add_together", ["a","b"], [], [["+", ["get", "a"], ["get" ,"b"]]]]
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch func_expr
    
    assert !(analyzed.respond_to? :call)
    assert LispMachine.lookup(LispMachine::SYMBOL_TABLE.length - 1, 'add_together')[:contents].kind_of? Proc

    call_expr = ["call", "add_together", ["const",13], ["const", 3]]
    analyzer.dispatch(call_expr).call

    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 16

  end
end

describe "list analysis" do

  it "should turn a cons directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    
    cons_expr = ["cons", ["const", 1], ["cons", ["const", 2], ["cons", ["const",3], ["const",
    4]]]]

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch cons_expr
    analyzed.call

    assert_equal [1,2,3,4], LispMachine.instance_variable_get('@last_evaluated')
  end

  it "should turn a car directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)

    car_expr = ["car", ["cons", ["const", 1], ["cons", ["const", 2], ["const", 3]]]]
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch car_expr
    analyzed.call

    assert_equal 1, LispMachine.instance_variable_get('@last_evaluated')
  end


  it "should turn a cdr directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)

    cdr_expr = ["cdr", ["cons", ["const", 1], ["cons", ["const", 2], ["const", 3]]]]
    
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch cdr_expr
    analyzed.call

    assert_equal [2,3], LispMachine.instance_variable_get('@last_evaluated')
  end
end

describe "quoting analysis" do
  it "should turn an quote directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    
    quote_expr = ["quote", "x"]

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch quote_expr
    analyzed.call
  
    assert LispMachine.instance_variable_get('@last_evaluated').kind_of? Symbol
    assert_equal LispMachine.instance_variable_get('@last_evaluated'), :x

  end
end

describe "evaluation analysis" do
  it "should turn an evaluate directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    
    eval_expr = ["evaluate", ["cons", ["quote", "+"], ["cons", ["const", 1], ["const", 2]]]]
  
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch eval_expr
    analyzed.call

    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 3

  end

  it "should turn a reccall directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    
    reccall_expr = ["reccall", "function_to_reccall", "1", "2"]
    
    analyzer = Analyzer.new
    analyzed = analyzer.dispatch reccall_expr
    analyzed.call

    assert_equal reccall_expr, LispMachine.instance_variable_get('@tail_call')
    
    LispMachine.instance_variable_set('@tail_call', nil)

  end

end

describe "send analysis" do

  it "should turn a send directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    
    send_expr = ["send", ["quote", "length"], ["cons", ["const", 1], ["const", 2]]]

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch send_expr
    analyzed.call

    assert_equal LispMachine.instance_variable_get('@last_evaluated'), 2
  end
end

describe "show analysis" do
  it "should turn a show directive into a function" do
    LispMachine.instance_variable_set('@last_evaluated', nil)
    

    show_expr = [["show", ["const", 1]], ["show",["const", "bob"]]]

    analyzer = Analyzer.new
    analyzed = analyzer.dispatch show_expr
    
    assert_output "1\nbob\n" do
      analyzed.call
    end

  end
end    
