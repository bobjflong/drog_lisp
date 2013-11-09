
load 'd2.rb'

module LispMachine
  SYMBOL_TABLE = [{
  }]
  
  @last_evaluated
  
  def self.lookup(scope, x)
    scope.downto(0).each do |level|
      result = LispMachine::SYMBOL_TABLE[level][x.to_sym]
      return result if result
    end
    return nil
  end
  
  def self.push_scope
    LispMachine::SYMBOL_TABLE << {}
  end
  
  def self.pop_scope
    LispMachine::SYMBOL_TABLE.pop
  end
  
  module Identifier
    def self.is_a_definition(x)
      x.length > 2 and x[0] == 'def'
    end
    
    def self.is_a_show(x)
      x.length > 1 and x[0] == 'show'
    end
    
    def self.is_an_adder(x)
      x.length > 2 and x[0] == '+'
    end
    
    def self.is_call(x)
      x.length > 2 and x[0] == 'call'
    end
    
    def self.is_a_getter(x)
      x.length > 1 and x[0] == 'get'
    end
  end
  
  module LanguageHelpers
    def self.extract_args_from_definition(x)
      if x.length > 3
        results = []
        2.upto(x.length - 2) do |i|
          results << x[i]
        end
        return results
      end 
    end
    
    # Extract simple args for 2-operand operators like +, - etc.
    def self.extract_simple_args(branch)
      
      res = []
      LispMachine::interpret([branch[1]])
      res << LispMachine.instance_variable_get('@last_evaluated')
      
      LispMachine::interpret([branch[2]])
      res << LispMachine.instance_variable_get('@last_evaluated')
      
      return res
    end
    
    # Extract and set up a function call
    def self.extract_complex_args_func_call(branch)
      result = {
        func_name: branch[1]
      }
      if (branch.length > 2) then
        args = []
        2.upto(branch.length - 1).each do |i|
          args << branch[i]
        end
        result[:args] = args
      end
      
      return result
    end
    
    # Set up a symbol table for a function call
    def self.map_params_for_function(args)
      func_find = LispMachine::lookup(LispMachine::SYMBOL_TABLE.length - 1, args[:func_name])
      
      if not func_find or func_find[:type] != 'definition'
        throw :no_such_function
      else
        
        # Begin the mapping by creating a new scope

        LispMachine::push_scope()

        # Attempt to map params to arguments
        func_find[:arguments].each_with_index do |a, i|                    
          LispMachine::SYMBOL_TABLE[-1]["#{a}".to_sym] = args[:args][i]
        end
        
        LanguageHelpers.pass_execution_to_function func_find
      end
    end
    
    def self.pass_execution_to_function(branch)
      LispMachine.interpret(branch[:contents])
      
      LispMachine::pop_scope()
    end
    
  end
  
  def self.interpret(tree)
    
    return unless tree    
    
    branch = tree[0]
    
    #puts "BRANCH IS #{branch}"

    if branch.class == Fixnum
      ##puts "Sending back atom: #{branch}"
      @last_evaluated = branch
      return @last_evaluated
    end
    
    return unless branch
    
    # ["def", "f", ["+", 1, 2]], ["+", 1, 2]
    if Identifier::is_a_definition(branch) then
      LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym] = {
        type: 'definition',
        contents: branch[-1],
        arguments: LanguageHelpers::extract_args_from_definition(branch)
      }
    
    elsif Identifier.is_a_getter(branch) then
      
      #puts "getting #{branch[1]}"
      @last_evaluated = lookup(LispMachine::SYMBOL_TABLE.length-1, branch[1])
    
    elsif Identifier.is_a_show(branch) then
      #puts "showing #{branch[1]}"
      LispMachine.interpret([branch[1]])
      puts @last_evaluated
    
    elsif Identifier.is_an_adder(branch) then
      #puts "ADDER: #{branch}"
      args = LanguageHelpers.extract_simple_args(branch)
      
      ##puts "ARGS : #{args}"
      @last_evaluated = args[0].to_i + args[1].to_i
    
    elsif Identifier.is_call(branch)
      args = LanguageHelpers.extract_complex_args_func_call(branch)
      
      LanguageHelpers.map_params_for_function(args)
      
    end
   
    #puts "\nlast evaluated = #{@last_evaluated}"
    #puts LispMachine::SYMBOL_TABLE
    ##puts "\ncontinuing with #{tree[1]}\n"
    LispMachine.interpret(tree[1])
  end
end

parsed = Parser.new.parse """

(Do

  (Func f x)
    (Do
      (Show (+ 1 x))
    )
  (Call f 5)
)

"""

#print parsed
LispMachine::interpret(parsed)
##puts ""
#print LispMachine::SYMBOL_TABLE
##puts ""

##puts ""
