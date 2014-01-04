
require 'drog_lisp/grammar'
require 'ostruct'
require 'continuation'
require 'pry'

module LispMachine
  
  class Analyzer

    def initialize
      @replace_ops_dictionary = {
        '<' => 'lt',
        '>' => 'gt',
        '=' => 'eq',
        '+' => 'add',
        '-' => 'sub',
        '*' => 'mul',
        '/' => 'div',
        '%' => 'mod'
      }
    end

    def replace_ops op
      if op.kind_of? Array
        "compound"
      elsif @replace_ops_dictionary.has_key? op
        @replace_ops_dictionary[op]
      else
        op
      end
    end
    
    def dispatch branch
      return Proc.new { nil } unless branch
      if not branch.kind_of? Array
        branch = ["const", branch]
      end
      directive = replace_ops branch[0]
      self.send("analyze_#{directive}".to_sym, branch)
    end

    def set_last_evaluated ans
      LispMachine.instance_variable_set '@last_evaluated', ans
    end

    def analyze_loopuntil(branch)
      pred_eval = dispatch branch[1]
      body = dispatch branch[2]

      Proc.new do
        while true
          pred_eval.call
          if not LispMachine.instance_variable_get('@last_evaluated')
            body.call
          else
            break
          end
        end
      end
    end

    def is_cmpd branch
      (branch.length > 1 and branch[0].kind_of? Array)
    end

    def is_not_cmpd branch
      not is_cmpd(branch)
    end

    def wrap_unless_cmpd branch
      return [] unless branch
      if is_cmpd(branch)
        branch
      else
        [branch]
      end
    end

    def analyze_cons(branch)
      left_eval = dispatch branch[1]
      right_eval = dispatch branch[2]
      Proc.new do
        left_eval.call
        left = LispMachine.instance_variable_get '@last_evaluated'

        right_eval.call

        right = LispMachine.instance_variable_get '@last_evaluated'
        
        if not right
          set_last_evaluated left
        else

  
          #Special case with keyword :Do
          #:Do -cons with-
          #[:+, :x, :y]
          # => [:Do, [:+, :x, :y]]
          # ie. Should not be merged into one list

          if left == :Do

            if is_not_cmpd right
             set_last_evaluated [left, right] 
            else
              set_last_evaluated [left, right].flatten 1
            end
          
          else
            if left.kind_of? Array
              set_last_evaluated [left] + wrap_unless_cmpd(right)
            else
              set_last_evaluated [left,right].flatten 1
            end
          end
        end

      end
    end

    def analyze_show(branch)
      show_eval = dispatch branch[1]
      
      Proc.new do
        show_eval.call
        last_evaluated = LispMachine.instance_variable_get '@last_evaluated'
        #binding.pry
        if last_evaluated.kind_of? Array and last_evaluated.length > 1
          if last_evaluated[0] == 'const'
            print last_evaluated[1]
          else
            print last_evaluated
          end
        else
          print last_evaluated
        end
        print "\n"
      end
    end

    def analyze_reccall(branch)
      Proc.new do
        LispMachine.instance_variable_set('@tail_call', branch)
      end
    end

    def analyze_send(branch)
      send_eval = dispatch branch[1]
      receiver_eval = dispatch branch[2]

      Proc.new do
        message = send_eval.call
        receiver = receiver_eval.call

        set_last_evaluated receiver.send message
      end
    end
    
    def analyze_evaluate(branch)
      eval_eval = dispatch branch[1]
      
      Proc.new do
        to_eval = eval_eval.call

        program = LispMachine.instance_variable_get '@last_evaluated'
        sexp = nil

        if not program[0] == :Do
          sexp = [:Do, program].to_sxp
        else
          sexp = program.to_sxp
        end
        LispMachine.run sexp
      end
    end

    def analyze_callcc(branch)
      func_to_call = branch[1]
      Proc.new do
        callcc do |cont|
          args = [cont]

          # Give passed function the continuation as only parameter
          params = { func_name: func_to_call, args: args }

          LispMachine::LanguageHelpers.map_params_for_function params, true
        end
      end
    end

    def analyze_car(branch)
      list_eval = dispatch branch[1]
      Proc.new do
        list_eval.call
        set_last_evaluated LispMachine.instance_variable_get('@last_evaluated')[0]
      end
    end

    def analyze_cdr(branch)
      list_eval = dispatch branch[1]
      Proc.new do
        list_eval.call
        result = LispMachine.instance_variable_get('@last_evaluated').drop 1
        if result.empty?
          set_last_evaluated nil
        else
          set_last_evaluated result
        end
      end
    end

    def analyze_quote(branch)
      Proc.new do
        set_last_evaluated branch[1].to_sym
      end
    end

    def analyze_compound(branch)
      analyzed = branch.map { |b| dispatch(b) }
      Proc.new do
        analyzed.each do |a|
          a.call if a.respond_to? :call
        end
      end
    end

    def analyze_set(branch)
      struct_eval = dispatch(branch[2])
      val_eval    = dispatch(branch[3])
      value_to_set = match_struct_name(branch[1])
      Proc.new do
        struct_eval.call
        struct = LispMachine.instance_variable_get '@last_evaluated'

        val_eval.call
        val = LispMachine.instance_variable_get '@last_evaluated'
        
        LispMachine::LanguageHelpers.check_for_struct struct, value_to_set

        struct.send "#{value_to_set}=", val
      end
    end

    def analyze_gets(branch)
      struct_eval = dispatch branch[2]
      value_to_get = match_struct_name(branch[1])
      Proc.new do
        struct_eval.call
        struct = LispMachine.instance_variable_get '@last_evaluated'
        
        LispMachine::LanguageHelpers.check_for_struct struct, value_to_get
        set_last_evaluated(struct.send value_to_get)
      end      
    end

    def analyze_def(branch)
      name = branch[1]
      params = branch[2]
      
      result = {
        type: 'definition',
        contents: dispatch(branch[-1]),
        arguments: LispMachine::LanguageHelpers::extract_args_from_definition(branch),
        name: name 
      }
            
      LispMachine::SYMBOL_TABLE[-1][name.to_sym] = result
      LanguageHelpers::close_over_variables branch, result


      Proc.new do
        to_return = result.clone 
        LanguageHelpers::close_over_variables branch, to_return
        set_last_evaluated to_return
      end
    end

    def analyze_lt(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]
      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1 < operand_2)
      end
    end

    def analyze_gt(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]
      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1 > operand_2)
      end
    end

    def analyze_add(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]

      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1 + operand_2)
      end
    end

    def analyze_sub(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]

      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1 - operand_2)
      end
    end

    def analyze_mul(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]

      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1 * operand_2)
      end
    end
    
    def analyze_div(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]

      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1.to_f / operand_2)
      end
    end

    def analyze_mod(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]

      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1.to_f % operand_2)
      end
    end
    
    def analyze_eq(branch)
      operand_1_eval = dispatch branch[1]
      operand_2_eval = dispatch branch[2]

      Proc.new do
        operand_1_eval.call
        operand_1 = LispMachine.instance_variable_get('@last_evaluated')
        operand_2_eval.call
        operand_2 = LispMachine.instance_variable_get('@last_evaluated')

        set_last_evaluated (operand_1 == operand_2)
      end
    end
    
    def analyze_struct(branch)
      Proc.new do
        set_last_evaluated(LispMachine::LanguageHelpers.create_struct_from branch)
      end
    end

    def analyze_let(branch)
      to_let = dispatch branch[2]
      Proc.new do
        to_let.call
        to_set = LispMachine.instance_variable_get '@last_evaluated'
        LispMachine::SYMBOL_TABLE[-1][branch[1].to_sym] = to_set
      end
    end

    def analyze_void(branch)
      Proc.new { set_last_evaluated nil }
    end

    def analyze_get(branch)
      Proc.new do
        set_last_evaluated(LispMachine.lookup(LispMachine::SYMBOL_TABLE.length-1, branch[1]))
      end
    end

    def analyze_const(branch)
      Proc.new { set_last_evaluated branch[1] }
    end

    def analyze_if branch
      left = dispatch branch[2]
      right  = dispatch branch[3]
      cond  = dispatch branch[1]
      Proc.new do
        cond.call
        if LispMachine.instance_variable_get('@last_evaluated')
          left.call
        else
          right.call
        end
      end
    end

    def analyze_call branch
      #map the arguments to lambdas that will give us the argument
      analyzed_args = branch[2..-1].map do |a|
        dispatch a
      end

      Proc.new do

        arguments_to_pass = analyzed_args.map do |a|
          a.call
          LispMachine.instance_variable_get '@last_evaluated'
        end
        
        arguments_for_function_call = {
          func_name: branch[1],
          args: arguments_to_pass 
        }

        LispMachine::LanguageHelpers.map_params_for_function arguments_for_function_call
      end
    end

    private

    def match_struct_name n
      n.match(/[^\-]+$/)[0]
    end
  end

  SYMBOL_TABLE = [{ }]
  
  @last_evaluated

  @analyzer = Analyzer.new
  
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
    
    def self.close_over_variables(branch, target)
      closed_over = branch[POSITION_OF_CLOSED_OVER_VARIABLES]
      saved_as = {}
      if (closed_over)
        [closed_over].flatten.each do |var|
          saved_as[var.to_sym] = LispMachine.lookup LispMachine::SYMBOL_TABLE.length-1, var
        end
        target[:closed_over] = saved_as
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
        if branch[:contents].respond_to? :call
          branch[:contents].call
        else
          LispMachine.interpret(branch[:contents])
        end
        if LanguageHelpers.tail_call and LanguageHelpers.tail_call[1].to_s == branch[:name].to_s
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

    analyzed = @analyzer.dispatch branch

    analyzed.call if analyzed.respond_to? :call
   
    LispMachine.interpret(tree[1])
  end
end
