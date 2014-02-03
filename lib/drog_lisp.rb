
require 'drog_lisp/grammar'
require 'ostruct'
require 'continuation'
require 'pry'

class LispMachine
  
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

          operand_1_eval.call
          operand_1 = machine.last_evaluated
          operand_2_eval.call
          operand_2 = machine.last_evaluated
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
        @analyzer = Analyzer.new self
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
        func_eval.call
        func = machine.last_evaluated

        args_eval.call
        args = machine.last_evaluated

        args = [args] unless args.kind_of? Array
        
        machine.map_params_for_function(
          create_args_for_function_call(function: func, arguments: args)
        )
      end
    end

    def analyze_loopuntil(branch)
      pred_eval = dispatch branch[1]
      body = dispatch branch[2]

      Proc.new do
        while true
          pred_eval.call
          if not machine.last_evaluated
            body.call
          else
            break
          end
        end
      end
    end

    def is_cmpd branch
      (branch.kind_of? Array and branch.length > 1 and branch[0].kind_of? Array)
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
        left = machine.last_evaluated

        right_eval.call

        right = machine.last_evaluated
        
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
        last_evaluated = machine.last_evaluated
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
        machine.tail_call = branch
      end
    end

    def analyze_send(branch)
      send_eval = dispatch branch[1]
      receiver_eval = dispatch branch[2]

      Proc.new do
        send_eval.call
        message = machine.last_evaluated

        receiver_eval.call
        receiver = machine.last_evaluated
        
        #Map symbol receivers to real equivalents
        # eg :Time => Time
        receiver = Kernel.const_get(receiver) if receiver.kind_of? Symbol
      
        begin 
        if not message.kind_of? Array
          set_last_evaluated receiver.send message
        else
          if message.length == 2 and message[1].kind_of? Array
            set_last_evaluated receiver.send(message[0], message.drop(1))
          else  
            set_last_evaluated receiver.send(message[0], *message.drop(1))
          end
        end
        rescue Exception => e
          binding.pry
        end
      end
    end
    
    def analyze_evaluate(branch)
      eval_eval = dispatch branch[1]
      
      Proc.new do
        eval_eval.call

        program = machine.last_evaluated
        sexp = nil

        if not program[0] == :Do
          sexp = [:Do, program].to_sxp
        else
          sexp = program.to_sxp
        end
        set_last_evaluated(LispMachine.run(sexp))
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
        list_eval.call
        set_last_evaluated machine.last_evaluated[0]
        rescue
          binding.pry
        end
      end
    end

    def analyze_cdr(branch)
      list_eval = dispatch branch[1]
      Proc.new do
        list_eval.call
        result = machine.last_evaluated.drop 1
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
        rescue Exception => e
          binding.pry
        end
      end
    end

    def analyze_set(branch)
      struct_eval = dispatch(branch[2])
      val_eval    = dispatch(branch[3])
      value_to_set = match_struct_name(branch[1])
      Proc.new do
        struct_eval.call
        struct = machine.last_evaluated

        val_eval.call
        val = machine.last_evaluated
        
        machine.check_for_struct struct, value_to_set

        struct.send "#{value_to_set}=", val
      end
    end

    def analyze_gets(branch)
      struct_eval = dispatch branch[2]
      value_to_get = match_struct_name(branch[1])
      Proc.new do
        struct_eval.call
        struct = machine.last_evaluated
        
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

    def analyze_let(branch)
      to_let = dispatch branch[2]
      Proc.new do
        to_let.call
        to_set = machine.last_evaluated
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
      #map the arguments to lambdas that will give us the argument
      analyzed_args = branch[2..-1].map do |a|
        dispatch a
      end

      #do we need to analyze the function?
      analyzed_func = nil
      analyzed_func = dispatch(branch[1]) unless branch[1].kind_of?(String)

      Proc.new do
        func = analyzed_func ? begin
          analyzed_func.call
          machine.last_evaluated
        end : nil

        arguments_to_pass = analyzed_args.map do |a|
          a.call
          machine.last_evaluated
        end

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

    def match_struct_name n
      n.match(/[^\-]+$/)[0]
    end
  end

  @SYMBOL_TABLE = [{ }]
  
  @last_evaluated

  @analyzer = Analyzer.new self
  
  # Information about tail call optimization
  @tail_call

  attr_accessor :SYMBOL_TABLE
  attr_accessor :analyzer
  attr_accessor :last_evaluated
  attr_accessor :tail_call

  def initialize
    @SYMBOL_TABLE = [ { } ]
    @analyzer = Analyzer.new self
  end
  
  # Helper method to run embedded programs quickly
  def self.run(prog, attrs = nil)
    parsed = Parser.new.parse prog
    machine = LispMachine.new
    machine.preload attrs if attrs
    machine.interpret(parsed)
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
  
  # Extract simple args for 2-operand operators like +, - etc.
  def extract_simple_args(branch)
    
    res = []
    interpret([branch[POSITION_OF_ARG_SIMPLE_0]])
    res << @last_evaluated

    interpret([branch[POSITION_OF_ARG_SIMPLE_1]])
    res << last_evaluated

    return res
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
    result = {}
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
      @last_evaluated = args[:args][0]
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
  def replace_args_for_function(branch, args = extract_complex_args_func_call(tail_call))
    branch[:arguments].flatten.each_with_index do |a, i|
      @SYMBOL_TABLE[-1]["#{a}".to_sym] = args[:args][i]
    end
    @tail_call = nil
  end

  def pass_execution_to_function(branch)
    # trampoline the function call to support tail call optimization
    while true
      if branch[:contents].respond_to? :call
        branch[:contents].call
      else
        interpret(branch[:contents])
      end
      if @tail_call and @tail_call[1].to_s == branch[:name].to_s
        replace_args_for_function branch
      else
        break
      end
    end
    
    # Gather new closed values
    reclosed = save_closed_variables_from_scope branch[:closed_over]
    
    pop_scope()

    return reclosed
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
    
    if branch.nil? 
      @last_evaluated = nil
      return @last_evaluated
    end
    
    if branch.length == 1
      @last_evaluated = branch[0]
      return @last_evaluated
    end
    
    analyzed = @analyzer.dispatch branch

    analyzed.call if analyzed.respond_to? :call
   
    interpret(tree[1])
  end
end
