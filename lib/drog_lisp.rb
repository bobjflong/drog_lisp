
require 'drog_lisp/grammar'
require 'drog_lisp/stdlib'
require 'drog_lisp/userlisp'
require 'drog_lisp/cons_pair'
require 'drog_lisp/message_receiver_pair'
require 'drog_lisp/sexprparser'
require 'ostruct'
require 'continuation'
require 'pry'

class LispMachine

  attr_accessor :SYMBOL_TABLE
  attr_accessor :analyzer
  attr_accessor :last_evaluated
  attr_accessor :tail_call
  attr_accessor :tail_call_arguments

  def initialize
    @analyzer = Analyzer.new self

    @SYMBOL_TABLE = [{ }]
  end


  class Analyzer

    attr_accessor :machine

    def initialize machine
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

      @replace_ops_dictionary.keys.each do |op|
        create_handler_for op
      end

      @machine = machine
    end

    def to_ruby_operator op
      op == '=' ? '==' : op
    end

    # Generate a analyzer-handler for a basic two-operatand operator
    # eg. create_handler '+'
    # => def analyze_add; Proc.new { } end
    def create_handler_for op
      self.class.send(:define_method, "analyze_#{@replace_ops_dictionary[op]}") do |branch|
        operand_1_eval = dispatch branch[1]
        operand_2_eval = dispatch branch[2]
        Proc.new do
          operand_1, operand_2 = call_and_retrieve_last_evaluated operand_1_eval, operand_2_eval
          set_last_evaluated(operand_1.send(to_ruby_operator(op).to_sym, operand_2))
        end
      end
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
      machine.last_evaluated = ans
    end

    def analyze_apply(branch)
      func_eval = dispatch branch[1]
      args_eval = dispatch branch[2]

      Proc.new do
        func, args = call_and_retrieve_last_evaluated func_eval, args_eval

        args = [args] unless args.kind_of? Array

        machine.map_params_for_function(
          create_args_for_function_call(function: func, arguments: args)
        )
      end
    end

    def is_cmpd branch
      (branch.kind_of? Array and branch.length > 1 and branch[0].kind_of? Array)
    end

    def is_not_cmpd branch
      not is_cmpd(branch)
    end

    def analyze_escape branch
      escaped = SXP.read(branch[1])
      -> { set_last_evaluated escaped }
    end

    def analyze_cons(branch)
      left_eval = dispatch branch[1]
      right_eval = dispatch branch[2]

      Proc.new do
        left, right = call_and_retrieve_last_evaluated left_eval, right_eval
        set_last_evaluated ConsPair.new(left, right).resolve
      end
    end

    def analyze_show(branch)
      show_eval = dispatch branch[1]

      Proc.new do
        last_evaluated = call_and_retrieve_last_evaluated show_eval
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

      analyzed_args = branch.drop(2).map do |a|
        dispatch a
      end

      analyzed_func = nil
      analyzed_func = dispatch(branch[1]) unless branch[1].kind_of?(String)

      Proc.new do

        arguments_to_pass = analyzed_args.map { |a| call_and_retrieve_last_evaluated a }

        if analyzed_func
          branch[1] = call_and_retrieve_last_evaluated analyzed_func
        end
        machine.tail_call = branch
        machine.tail_call_arguments = arguments_to_pass
      end
    end

    def analyze_send(branch)
      send_eval = dispatch branch[1]
      receiver_eval = dispatch branch[2]

      Proc.new do
        message, receiver = call_and_retrieve_last_evaluated send_eval, receiver_eval

        begin
          set_last_evaluated MessageReceiverPair.new(message, receiver).perform
        rescue Exception => e
          binding.pry
        end
      end
    end

    def analyze_evaluate(branch)
      eval_eval = dispatch branch[1]

      Proc.new do
        program = call_and_retrieve_last_evaluated eval_eval
        set_last_evaluated(LispMachine.run(UserLisp.new(program).program, { machine: @machine }))
      end
    end

    def analyze_callcc(branch)
      func_to_call = branch[1]
      Proc.new do
        callcc do |cont|
          args = [cont]

          # Give passed function the continuation as only parameter
          params = { func_name: func_to_call, args: args }

          machine.map_params_for_function params, true
        end
      end
    end

    def analyze_car(branch)
      list_eval = dispatch branch[1]
      Proc.new do
        begin
        set_last_evaluated call_and_retrieve_last_evaluated(list_eval)[0]
        rescue
          binding.pry
        end
      end
    end

    def analyze_cdr(branch)
      list_eval = dispatch branch[1]
      Proc.new do
        result = call_and_retrieve_last_evaluated(list_eval).drop 1
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
        begin
        analyzed.each do |a|
          a.call if a.respond_to? :call
        end
        rescue => e
          binding.pry
        end
      end
    end

    def analyze_set(branch)
      struct_eval = dispatch(branch[2])
      val_eval    = dispatch(branch[3])
      value_to_set = match_struct_name(branch[1])
      Proc.new do
        struct, val = call_and_retrieve_last_evaluated struct_eval, val_eval

        machine.check_for_struct struct, value_to_set
        struct.send "#{value_to_set}=", val
      end
    end

    def analyze_gets(branch)
      struct_eval = dispatch branch[2]
      value_to_get = match_struct_name(branch[1])
      Proc.new do
        struct = call_and_retrieve_last_evaluated struct_eval

        machine.check_for_struct struct, value_to_get
        set_last_evaluated(struct.send value_to_get)
      end
    end

    def analyze_def(branch)
      name = branch[1]

      result = {
        type: 'definition',
        contents: dispatch(branch[-1]),
        arguments: machine.extract_args_from_definition(branch),
        name: name
      }

      machine.SYMBOL_TABLE[-1][name.to_sym] = result
      machine.close_over_variables branch, result

      Proc.new do
        to_return = result.clone
        machine.SYMBOL_TABLE[-1][name.to_sym] = to_return
        machine.close_over_variables branch, to_return
        set_last_evaluated to_return
      end
    end

    def analyze_struct(branch)
      Proc.new do
        set_last_evaluated(machine.create_struct_from branch)
      end
    end

    def analyze_reset(branch)
      to_set_analyze = dispatch branch[2]
      Proc.new do
        to_set = call_and_retrieve_last_evaluated to_set_analyze
        key = branch[1].to_sym
        machine.SYMBOL_TABLE.reverse.each do |level|
          if level.has_key? key
            level[key] = to_set
            break
          end
        end
      end
    end

    def analyze_let(branch)
      to_let = dispatch branch[2]
      Proc.new do
        to_set = call_and_retrieve_last_evaluated to_let
        machine.SYMBOL_TABLE[-1][branch[1].to_sym] = to_set
      end
    end

    def analyze_void(branch)
      Proc.new { set_last_evaluated nil }
    end

    def analyze_get(branch)
      Proc.new do
        set_last_evaluated(machine.lookup(machine.SYMBOL_TABLE.length-1, branch[1]))
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
        if machine.last_evaluated
          left.call
        else
          right.call
        end
      end

    end

    def analyze_call branch

      analyzed_args = branch.drop(2).map do |a|
        dispatch a
      end

      # We don't need to analyze the function argument if its a simple string reference
      analyzed_func = nil
      analyzed_func = dispatch(branch[1]) unless branch[1].kind_of?(String)

      Proc.new do
        func = call_and_retrieve_last_evaluated analyzed_func

        arguments_to_pass = analyzed_args.map { |a| call_and_retrieve_last_evaluated a }

        func_name = branch[1].kind_of?(String) ? branch[1] : '_'

        machine.map_params_for_function(
          create_args_for_function_call(name: func_name, function:func, arguments:arguments_to_pass)
        )
      end
    end

    private

    def create_args_for_function_call name: '_', function: function, arguments: args_to_pass
      {
        func_name: name,
        func: function,
        args: arguments
      }
    end

    def call_and_retrieve_last_evaluated *to_eval

      return nil unless to_eval and to_eval.length > 0
      return nil if to_eval.all? { |x| x.nil? }

      evaled = to_eval.map do |x|
        x.call
        machine.last_evaluated
      end

      return evaled.first if evaled.length == 1
      evaled
    end

    def match_struct_name n
      n.match(/[^\-]+$/)[0]
    end
  end

  # Helper method to run embedded programs quickly
  def self.run(prog, attrs = nil)

    # Preprocess the user program with the standard macros
    LispPreprocessor.preprocess prog, MacroList.new([])
    # Then parse it
    parsed = Parser.new.parse prog

    machine = (attrs && attrs[:machine]) || LispMachine.new
    # Preload the machine with given values
    machine.preload attrs if attrs

    # Run the functions making up the standard library
    machine.interpret Parser.new.parse(StandardFunctions.listing)

    # Run the user program
    machine.interpret(parsed)

    # Grab and return the last evaluated value
    machine.last_evaluated
  end

  def preload(attrs)
    attrs.each do |k,v|
      @SYMBOL_TABLE[0][k] = v
    end
  end

  def lookup(scope, x)
    scope.downto(0).each do |level|
      result = @SYMBOL_TABLE[level][x.to_sym]
      return result if result
      return result if @SYMBOL_TABLE[level].has_key? x.to_sym
    end
    return nil
  end

  def push_scope
    @SYMBOL_TABLE << {}
  end

  def pop_scope
    @SYMBOL_TABLE.pop
  end

  def replace_scope
    pop_scope ; push_scope
  end

  POSITION_OF_ARG_SIMPLE_0 = 1
  POSITION_OF_ARG_SIMPLE_1 = 2

  POSITION_OF_ARGS_IN_DEFINITION = 2
  POSITION_OF_CLOSED_OVER_VARIABLES = 3

  # Start of args in function call
  POSITION_OF_COMPLEX_ARGS_START = 2

  def extract_args_from_definition(x)
    return [x[POSITION_OF_ARGS_IN_DEFINITION]]
  end

  def create_struct_from branch
    result = OpenStruct.new
    params = branch.flatten
    1.upto params.length - 1 do |i|
      result.send "#{params[i]}=", nil
    end
    result
  end

  def close_over_variables(branch, target)
    closed_over = branch[POSITION_OF_CLOSED_OVER_VARIABLES]
    saved_as = {}
    if (closed_over)
      [closed_over].flatten.each do |var|
        saved_as[var.to_sym] = lookup @SYMBOL_TABLE.length-1, var
      end
      target[:closed_over] = saved_as
    end
  end

  # Extract and set up a function call
  def extract_complex_args_func_call(branch)
    result = {
      func_name: branch[1]
    }
    if (branch.length > POSITION_OF_COMPLEX_ARGS_START) then
      args = []

      POSITION_OF_COMPLEX_ARGS_START.upto(branch.length - 1).each do |i|
        wrapper = [branch[i]]
        interpret wrapper

        args << last_evaluated
      end
      result[:args] = args
    end

    return result
  end

  def push_closed_variables_to_scope(closed)
    if closed
      closed.each do |k,v|
        @SYMBOL_TABLE[-1][k] = v
      end
    end
  end

  def save_closed_variables_from_scope(closed)
    result = Hash.new
    if closed
      closed.each do |k, v|
        result[k.to_sym] = @SYMBOL_TABLE[-1][k.to_sym]
      end
    end
    result
  end

  def find_function_from_arguments args
    return args[:func] if args[:func]
    lookup(@SYMBOL_TABLE.length - 1, args[:func_name])
  end

  def find_and_handle_continuation_function args, func_find, cc
    if func_find.kind_of? Continuation and cc
      @last_evaluated = args[:args].first
    end

    if func_find.kind_of? Continuation
      func_find.call
      return func_find
    end
    nil
  end

  # Set up a symbol table for a function call
  def map_params_for_function(args, cc = false)

    func_find = find_function_from_arguments args

    return if find_and_handle_continuation_function args, func_find, cc

    if not func_find or func_find[:type] != 'definition'
      binding.pry
      throw :no_such_function
    else

      # Begin the mapping by creating a new scope
      push_scope()

      func_find[:arguments].flatten.each_with_index do |a, i|
        @SYMBOL_TABLE[-1]["#{a}".to_sym] = args[:args][i]
      end
      push_closed_variables_to_scope(func_find[:closed_over])
      reclosed = pass_execution_to_function func_find

      if reclosed
        if args[:func]
          args[:func][:closed_over] = reclosed
        else
          lookup(@SYMBOL_TABLE.length - 1, args[:func_name])[:closed_over] = reclosed
        end
      end

    end
  end

  # remap variables without a new function call
  # (used for tail call optimization)
  def replace_args_for_function(branch, args = @tail_call_arguments)
    replace_scope
    branch[:arguments].flatten.each_with_index do |a, i|
      @SYMBOL_TABLE[-1]["#{a}".to_sym] = args[i]
    end
    @tail_call = nil
    branch
  end

  def pass_execution_to_function(branch)
    # trampoline the function call to support tail call optimization
    while true
      if branch[:contents].respond_to? :call
        branch[:contents].call
      else
        interpret(branch[:contents])
      end
      if @tail_call
        #TODO: REFACTOR + ERROR HANDLING
        @last_evaluated = branch = swap_current_function @tail_call
      else
        break
      end
    end

    # Gather new closed values
    reclosed = save_closed_variables_from_scope branch[:closed_over]

    pop_scope()

    return reclosed
  end

  def swap_current_function branch
    new_function = find_function_from_arguments produce_function_arguments_for_tail_call(branch)
    replace_args_for_function new_function
  end

  def check_for_struct struct, v
    if not struct.kind_of? OpenStruct
      throw :not_a_struct
    end

    has_entry = struct.marshal_dump.has_key? v.to_sym

    if not has_entry
      throw "no_such_value_#{v}".to_sym
    end

  end


  def interpret(tree)

    return unless tree

    branch = tree[0]

    return @last_evaluated = nil if branch_is_nil? branch

    return @last_evaluated = branch[0] if branch_is_single_item? branch

    analyze_and_call branch

    interpret(tree[1])
  end

  private

  def branch_is_nil? branch
    branch.nil?
  end

  def branch_is_single_item? branch
    branch.length == 1
  end

  def analyze_and_call branch
    analyzed = @analyzer.dispatch branch
    analyzed.call if analyzed.respond_to? :call
  end

  def produce_function_arguments_for_tail_call branch
    func = branch[1].kind_of?(String) ? nil : branch[1]
    func_name = func ? '_' : branch[1]
    { func: func, func_name: func_name }
  end
end
