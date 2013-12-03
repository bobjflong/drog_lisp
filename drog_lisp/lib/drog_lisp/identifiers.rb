module Identifier
  def self.is_a_definition(x)
    x.length > 2 and x[0] == 'def'
  end
  def self.is_quote(x)
    x.length > 1 and x[0] == 'quote'
  end
  def self.is_send(x)
    x.length > 2 and x[0] == 'send'
  end
  def self.is_evaluate(x)
    x.length > 1 and x[0] == 'evaluate'
  end
  def self.is_loopuntil(x)
    x.length > 2 and x[0] == 'loopuntil'
  end
  def self.is_gets(x)
    x.length > 1 and x[0] == 'gets'
  end
  def self.is_set(x)
    x.length > 3 and x[0] == 'set'
  end
  def self.is_struct(x)
    x.length > 1 and x[0] == 'struct'
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
  
  def self.is_reccall(x)
    x.length > 2 and x[0] == 'reccall'
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

  def self.is_callcc(x)
    x.length > 1 and x[0] == 'callcc'
  end

  
end
