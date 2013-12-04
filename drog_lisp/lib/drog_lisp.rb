
require 'drog_lisp/grammar'
require 'drog_lisp/identifiers'
require 'ostruct'
require 'continuation'
require 'pry'

module LispMachine
  SYMBOL_TABLE = [{ }]
  
  @last_evaluated
  
  # Information about tail call optimization
  @tail_call
  
  # Helper method to run embedded programs quickly
  def self.run(prog)
    parsed = Parser.new.parse prog
    LispMachine::interpret(parsed)
    LispMachine.instance_variable_get('@last_evaluated')
  end

  def self.preload(attrs)
    attrs.each do |k,v|
      LispMachine::SYMBOL_TABLE[0][k] = v
    end
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
   
    POSITION_OF_ARG_SIMPLE_0 = 1
    POSITION_OF_ARG_SIMPLE_1 = 2

    POSITION_OF_ARGS_IN_DEFINITION = 2
    POSITION_OF_CLOSED_OVER_VARIABLES = 3

    # Start of args in function call
    POSITION_OF_COMPLEX_ARGS_START = 2
    
    def self.extract_args_from_definition(x)
      return [x[POSITION_OF_ARGS_IN_DEFINITION]] 
    end

    def self.process_message branch
      LispMachine.interpret [branch[1]]
      message = LispMachine.instance_variable_get '@last_evaluated'

      LispMachine.interpret [branch[2]]
      receiver = LispMachine.instance_variable_get '@last_evaluated'
      
      result = receiver.send message.to_sym
      LispMachine.instance_variable_set '@last_evaluated', result
    end

    def self.create_struct_from branch
      result = OpenStruct.new
      params = branch.flatten
      1.upto params.length - 1 do |i|
        result.send "#{params[i]}=", nil  
      end
      result
    end
    
    def self.close_over_variables(branch)
      closed_over = branch[POSITION_OF_CLOSED_OVER_VARIABLES]
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
      LispMachine::interpret([branch[POSITION_OF_ARG_SIMPLE_0]])
      res << LispMachine.instance_variable_get('@last_evaluated')
      
      LispMachine::interpret([branch[POSITION_OF_ARG_SIMPLE_1]])
      res << LispMachine.instance_variable_get('@last_evaluated')
      
      return res
    end
        
    # Extract and set up a function call
    def self.extract_complex_args_func_call(branch)
      result = {
        func_name: branch[1]
      }
      if (branch.length > POSITION_OF_COMPLEX_ARGS_START) then
        args = []
        
        flattened = branch#.flatten(1)
        POSITION_OF_COMPLEX_ARGS_START.upto(branch.length - 1).each do |i|
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
        LispMachine.instance_variable_set('@last_evaluated', args[:args][0])
      end

      if func_find.kind_of? Continuation
        func_find.call
        return
      end
        
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

    # remap variables without a new function call
    # (used for tail call optimization)
    def self.replace_args_for_function(branch, args = extract_complex_args_func_call(LanguageHelpers.tail_call))
      branch[:arguments].flatten.each_with_index do |a, i|
        LispMachine::SYMBOL_TABLE[-1]["#{a}".to_sym] = args[:args][i]
      end
      LispMachine.instance_variable_set '@tail_call', nil
    end

    def self.tail_call
      LispMachine.instance_variable_get '@tail_call'
    end
    
    def self.pass_execution_to_function(branch)
      # trampoline the function call to support tail call optimization
      while true
        LispMachine.interpret(branch[:contents])
        if LanguageHelpers.tail_call
          LanguageHelpers.replace_args_for_function branch
        else
          break
        end
      end
      # Gather new closed values
      reclosed = LanguageHelpers.save_closed_variables_from_scope branch[:closed_over]

      LispMachine::pop_scope()

      return reclosed
    end

    def self.check_for_struct struct, v
      if not struct.kind_of? OpenStruct
        throw :not_a_struct
      end

      has_entry = struct.marshal_dump.has_key? v.to_sym

      if not has_entry
        throw "no_such_value_#{v}".to_sym
      end

    end
    
  end

  def self.interpret(tree)
    
    return unless tree    
    
    branch = tree[0]
    
    if branch.nil? 
      @last_evaluated = nil
      return @last_evaluated
    end
    
    if branch.length == 1
      @last_evaluated = branch[0]
      return @last_evaluated
    end
    
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
      
    elsif Identifier.is_evaluate(branch) then
      LispMachine.interpret [branch[1]]
      sexp = [:Do, @last_evaluated].to_sxp
      LispMachine.run sexp

    elsif Identifier.is_let(branch) then
      LispMachine.interpret([branch[2]])
      LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym] = @last_evaluated
    
    elsif Identifier.is_send(branch) then
      LanguageHelpers.process_message branch
  
    elsif Identifier.is_set(branch) then
      LispMachine.interpret [branch[2]]
      struct = @last_evaluated

      LispMachine.interpret [branch[3]]
      value = @last_evaluated

      value_to_set = branch[1].match(/[^\-]+$/)[0]
      LanguageHelpers.check_for_struct struct, value_to_set

      struct.send "#{value_to_set}=", value

    elsif Identifier.is_gets(branch) then
      LispMachine.interpret [branch[2]]
      struct = @last_evaluated
      to_get = branch[1].match(/[^\-]+$/)[0]
      LanguageHelpers.check_for_struct struct, to_get

      @last_evaluated = struct.send to_get
  
    elsif Identifier.is_quote(branch) then
      @last_evaluated = branch[1].to_sym
    
    elsif Identifier.is_const(branch) then
      @last_evaluated = branch[1]
      return @last_evaluated
    
    elsif Identifier.is_struct(branch) then
      @last_evaluated = LanguageHelpers.create_struct_from branch

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
    
    elsif Identifier.is_loopuntil(branch) then
      cond = branch[1]
      LispMachine::interpret [cond]
      while not @last_evaluated
        LispMachine::interpret branch[2]
        LispMachine::interpret [cond]
      end

    elsif Identifier.is_a_show(branch) then
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
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0].to_i * args[1].to_i
    
    elsif Identifier.is_an_adder(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0].to_i + args[1].to_i
    
    elsif Identifier.is_sub(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0].to_i - args[1].to_i

    elsif Identifier.is_eq(branch) then
      args = LanguageHelpers.extract_simple_args(branch)
      @last_evaluated = args[0] == args[1]

    elsif Identifier.is_reccall(branch)
      LispMachine.instance_variable_set '@tail_call', branch

    elsif Identifier.is_call(branch)
      args = LanguageHelpers.extract_complex_args_func_call(branch)
      LanguageHelpers.map_params_for_function(args)
    end
   
    LispMachine.interpret(tree[1])
  #  return tree[1]
  end
end
