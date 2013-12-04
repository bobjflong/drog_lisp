
require 'drog_lisp'
require 'pry'

class Analyzer

  def dispatch branch
    if branch[0] == '<'
      self.send :analyze_lt, branch
    else
      self.send("analyze_#{branch[0]}".to_sym, branch)
    end
  end

  def set_last_evaluated ans
    LispMachine.instance_variable_set '@last_evaluated', ans
  end

  def analyze_lt(branch)
    Proc.new do
      set_last_evaluated (dispatch(branch[1]).call < dispatch(branch[2]).call)
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
