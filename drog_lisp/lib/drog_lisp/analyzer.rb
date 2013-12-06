
require 'drog_lisp'
require 'pry'
require 'sxp'

class Analyzer

  def initialize
    @replace_ops_dictionary = {
      '<' => 'lt',
      '>' => 'gt',
      '=' => 'eq',
      '+' => 'add',
      '-' => 'sub',
      '*' => 'mul',
      '/' => 'div'
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
    directive = replace_ops branch[0]
    self.send("analyze_#{directive}".to_sym, branch)
  end

  def set_last_evaluated ans
    LispMachine.instance_variable_set '@last_evaluated', ans
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
        set_last_evaluated [left, right].flatten(1)
      end
    end
  end

  def analyze_show(branch)
    show_eval = dispatch branch[1]
    
    Proc.new do
      show_eval.call
      last_evaluated = LispMachine.instance_variable_get '@last_evaluated'

      if last_evaluated.kind_of? Array and last_evaluated.length > 1
        if last_evaluated[0] == 'const'
          print last_evaluated[1]
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
      sexp = [:Do, LispMachine.instance_variable_get('@last_evaluated')].to_sxp
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
      set_last_evaluated LispMachine.instance_variable_get('@last_evaluated').drop(1)
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
    value_to_set = branch[1].match(/[^\-]+$/)[0]
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
    value_to_get = branch[1].match(/[^\-]+$/)[0]
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
    
          
    LispMachine::SYMBOL_TABLE[-1][name.to_sym] = {
      type: 'definition',
      contents: dispatch(branch[-1]),
      arguments: LispMachine::LanguageHelpers::extract_args_from_definition(branch),
      name: name 
    }

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

      set_last_evaluated (operand_1 / operand_2)
    end
  end
  
  def analyze_eq(branch)
    operand_1_eval = dispatch branch[1]
    operand_2_eval = dispatch branch[2] == '12'

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
    Proc.new { nil }
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
      if cond.call
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
      
      branch[2..-1] = arguments_to_pass

      arguments_for_function_call = {
        func_name: branch[1],
        args: arguments_to_pass 
      }

      LispMachine::LanguageHelpers.map_params_for_function arguments_for_function_call

    end
  end
end
