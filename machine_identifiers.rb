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
  
  def self.is_sub(x)
    x.length > 2 and x[0] == '-'
  end
  
  def self.is_call(x)
    x.length > 2 and x[0] == 'call'
  end
  
  def self.is_a_getter(x)
    x.length > 1 and x[0] == 'get'
  end
  
  def self.is_gt(x)
    x.length > 2 and x[0] == '<'
  end
  
  def self.is_cond(x)
    x.length > 2 and x[0] == 'if'
  end
  
  def self.is_mul(x)
    x.length > 2 and x[0] == '*'
  end
  
  def self.is_cons(x)
    x.length > 2 and x[0] == 'cons'
  end
  
  def self.is_eq(x)
    x.length > 2 and x[0] == '='
  end
  
  def self.is_const(x)
    x.length > 1 and x[0] == 'const'
  end
  
  def self.is_car(x)
    x.length > 1 and x[0] == 'car'
  end

  def self.is_cdr(x)
    x.length > 1 and x[0] == 'cdr'
  end
  
  def self.is_let(x)
    x.length > 2 and x[0] == 'let'
  end

  
end
