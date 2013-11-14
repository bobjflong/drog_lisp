
load 'd2.rb'
load 'machine_identifiers.rb'

require 'continuation'

module LispMachine
  SYMBOL_TABLE = [{
    :m => 4
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
      #puts "def = #{x}"
      if x[2]
        return [x[2]]
      end
    end
    
    def self.close_over_variables(branch)
      closed_over = branch[3]
      saved_as = {}
      if (closed_over)
        [closed_over].flatten.each do |var|
          saved_as[var.to_sym] = LispMachine.lookup LispMachine::SYMBOL_TABLE.length-1, var
        end
        LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym][:closed_over] = saved_as
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
        
        flattened = branch#.flatten(1)
        2.upto(branch.length - 1).each do |i|
          wrapper = [branch[i]]
          LispMachine.interpret wrapper
          
          args << LispMachine.instance_variable_get('@last_evaluated')
        end
        result[:args] = args
      end
      
      return result
    end
    
    def self.push_closed_variables_to_scope(closed)
      if closed
        closed.each do |k,v|
          LispMachine::SYMBOL_TABLE[-1][k] = v
        end
      end
    end

    def self.save_closed_variables_from_scope(closed)
      result = {}
      if closed
        closed.each do |k, v|
          result[k.to_sym] = LispMachine::SYMBOL_TABLE[-1][k.to_sym]
        end
      end
      result
    end
    
    # Set up a symbol table for a function call
    def self.map_params_for_function(args, cc = false)

      #puts "self.map_params_for_function #{args} #{cc}"
      func_find = LispMachine::lookup(LispMachine::SYMBOL_TABLE.length - 1, args[:func_name])

      #puts "func_find #{func_find}"
      if func_find.kind_of? Continuation and cc
        #puts "yo 1"
        LispMachine.instance_variable_set('@last_evaluated', args[:args][0])
      end

      if func_find.kind_of? Continuation
        #puts "yo 2"
        func_find.call
        return
      end
        
      #puts "here #{func_find} #{@las}"

      if not func_find or func_find[:type] != 'definition'
        throw :no_such_function
      else
        
        # Begin the mapping by creating a new scope

        LispMachine::push_scope()
        
        func_find[:arguments].flatten.each_with_index do |a, i|
          LispMachine::SYMBOL_TABLE[-1]["#{a}".to_sym] = args[:args][i]
        end
        
        LanguageHelpers.push_closed_variables_to_scope(func_find[:closed_over])
        reclosed = LanguageHelpers.pass_execution_to_function func_find

        if reclosed
          LispMachine::lookup(LispMachine::SYMBOL_TABLE.length - 1, args[:func_name])[:closed_over] = reclosed
        end

      end
    end
    
    def self.pass_execution_to_function(branch)
      LispMachine.interpret(branch[:contents])

      # Gather new closed values
      reclosed = LanguageHelpers.save_closed_variables_from_scope branch[:closed_over]

      LispMachine::pop_scope()

      return reclosed
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
    if Identifier.is_a_definition(branch) then
      
      LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym] = {
        type: 'definition',
        contents: branch[-1],
        arguments: LanguageHelpers::extract_args_from_definition(branch),
        name: branch[1].to_sym
      }
      
      LanguageHelpers::close_over_variables(branch)
      
      @last_evaluated = LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym]
      
    #  puts "symbol = #{LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym]}"
    
    elsif Identifier.is_let(branch) then
      LispMachine.interpret([branch[2]])
      LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym] = @last_evaluated
    
    elsif Identifier.is_const(branch) then
      @last_evaluated = branch[1]
      return @last_evaluated

    elsif Identifier.is_callcc(branch) then
      func_to_call = branch[1]
      callcc do |cont|
        args = [cont]

        # Give passed function the continuation as only parameter
        params = { func_name: func_to_call, args: args }

        LanguageHelpers.map_params_for_function params, true

      end
    
    elsif Identifier.is_a_getter(branch) then 
      @last_evaluated = lookup(LispMachine::SYMBOL_TABLE.length-1, branch[1])

    elsif Identifier.is_a_show(branch) then
      #puts LispMachine::SYMBOL_TABLE
      LispMachine.interpret([branch[1]])
      if @last_evaluated.kind_of? Array and @last_evaluated.length > 1
        if @last_evaluated[0] == 'const'
          print @last_evaluated[1]
        end
      else
        print @last_evaluated
      end
      print "\n"
    
    elsif Identifier.is_gt(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0] < args[1]
    
    elsif Identifier.is_car(branch) then
      LispMachine.interpret([branch[1]])
      @last_evaluated = @last_evaluated[0]
    
    elsif Identifier.is_cdr(branch) then
      LispMachine.interpret([branch[1]])
      result = @last_evaluated[1..-1]
      if result.empty?
        @last_evaluated = nil
      else
        @last_evaluated = result
      end
    
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
      args = LanguageHelpers.extract_complex_args_func_call(branch)
      LanguageHelpers.map_params_for_function(args)
    #  puts "AFTER CALL #{@last_evaluated}"
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
