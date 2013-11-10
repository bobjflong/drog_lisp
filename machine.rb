
load 'd2.rb'
load 'machine_identifiers.rb'

module LispMachine
  SYMBOL_TABLE = [{
  }]
  
  @last_evaluated
  
  # Helper method to run embedded programs quickly
  def self.run(prog)
    parsed = Parser.new.parse prog
    LispMachine::interpret(parsed)
    LispMachine.instance_variable_get('@last_evaluated')
  end
  
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
        
        #puts "EXTRACTING ARGS NORM: #{branch}"
        flattened = branch#.flatten(1)
        2.upto(branch.length - 1).each do |i|
          #puts "Mapping: #{branch[i]}"
          wrapper = [branch[i]]
          #puts "Wrapped for exec: #{wrapper}"
          LispMachine.interpret wrapper
          
          #puts "last evaled #{LispMachine.instance_variable_get('@last_evaluated')}"
          args << LispMachine.instance_variable_get('@last_evaluated')
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
        ####puts LispMachine::SYMBOL_TABLE
        
        # Attempt to map params to arguments
        # Flatten arguments here?
        
        ####puts "FUNC ARGS = #{args}"
        func_find[:arguments].flatten.each_with_index do |a, i|
          ####puts "mapping #{a} = #{args[:args][i]}"          
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
    
    ####puts "BRANCH IS #{branch}"
    
    if branch.nil? 
      @last_evaluated = nil
      return @last_evaluated
    end
    
    ####puts "Branch = #{branch}"
    return unless branch
    
    # ["def", "f", ["+", 1, 2]], ["+", 1, 2]
    if Identifier::is_a_definition(branch) then
      LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym] = {
        type: 'definition',
        contents: branch[-1],
        arguments: LanguageHelpers::extract_args_from_definition(branch)
      }
    
    elsif Identifier.is_const(branch) then
      @last_evaluated = branch[1]
      return @last_evaluated
    
    elsif Identifier.is_a_getter(branch) then
      
      ####puts "getting #{branch[1]}"
      @last_evaluated = lookup(LispMachine::SYMBOL_TABLE.length-1, branch[1])
    
    elsif Identifier.is_a_show(branch) then
      ####puts "showing #{branch[1]}"
      LispMachine.interpret([branch[1]])
      puts @last_evaluated
    
    elsif Identifier.is_gt(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0] < args[1]
    
    elsif Identifier.is_cons(branch) then
      LispMachine::interpret([branch[1]])
      left = @last_evaluated
      
      LispMachine::interpret([branch[2]])
      right = @last_evaluated
      
      ###puts "CONS: #{left} #{right}"
            
      if not right
        @last_evaluated = left
      else
        @last_evaluated = [left, right].flatten 1
      end
    
    elsif Identifier.is_cond(branch) then
      LispMachine::interpret([branch[1]])
      if @last_evaluated then
        LispMachine::interpret([branch[2]])
      else
        LispMachine::interpret([branch[3]])
      end
    
    elsif Identifier.is_mul(branch) then
      ####puts "#{branch[1]} * #{branch[2]}"
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0].to_i * args[1].to_i
      ####puts "AFTER MUL, @last_evaluated = #{@last_evaluated}"
    
    elsif Identifier.is_an_adder(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0].to_i + args[1].to_i
    
    elsif Identifier.is_sub(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0].to_i - args[1].to_i

    elsif Identifier.is_eq(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      ###puts "EQ: #{args}"
      @last_evaluated = args[0] == args[1]
    
    elsif Identifier.is_call(branch)
     # ###puts "IS_CALL #{branch}"
      args = LanguageHelpers.extract_complex_args_func_call(branch)
      LanguageHelpers.map_params_for_function(args)
      
    end
   
    ####puts "\nlast evaluated = #{@last_evaluated}"
    ####puts LispMachine::SYMBOL_TABLE
    #####puts "\ncontinuing with #{tree[1]}\n"
    LispMachine.interpret(tree[1])
  end
end

#parsed = Parser.new.parse """
#
#(Do
#
#  (Func fact x)
#    (Do
#      (If (< x 1)
#        1
#        (* x (Call fact (- x 1)))
#      )
#    )
#  (Call fact 5)
#
#)
#
#"""
#
##print parsed
#LispMachine::interpret(parsed)
####puts "last evaluated"
####puts LispMachine.instance_variable_get('@last_evaluated')
#
#####puts ""
#print LispMachine::SYMBOL_TABLE
#####puts ""

#####puts ""
