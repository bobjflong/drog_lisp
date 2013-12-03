
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

  def analyze_get(branch)
    Proc.new do
      set_last_evaluated(LispMachine.lookup(LispMachine::SYMBOL_TABLE.length-1, branch[1]))
    end
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
end
